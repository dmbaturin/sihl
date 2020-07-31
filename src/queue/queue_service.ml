open Base

let ( let* ) = Lwt.bind

module Job = Queue_core.Job
module WorkableJob = Queue_core.WorkableJob
module JobInstance = Queue_core.JobInstance

let registered_jobs : WorkableJob.t list ref = ref []

let stop_schedule : (unit -> unit) option ref = ref None

module MakePolling
    (Log : Log_sig.SERVICE)
    (ScheduleService : Schedule.Sig.SERVICE)
    (Repo : Queue_sig.REPO) : Queue_sig.SERVICE = struct
  let on_init ctx =
    let ( let* ) = Lwt_result.bind in
    let* () = Repo.register_migration ctx in
    Repo.register_cleaner ctx

  let on_stop _ =
    registered_jobs := [];
    match !stop_schedule with
    | Some stop_schedule ->
        stop_schedule ();
        Lwt_result.return ()
    | None ->
        Log.warn (fun m -> m "QUEUE: Can not stop schedule");
        Lwt_result.return ()

  let register_jobs _ ~jobs =
    registered_jobs := jobs |> List.map ~f:WorkableJob.of_job;
    Lwt.return ()

  let dispatch ctx ~job ?delay input =
    let name = Job.name job in
    Log.debug (fun m -> m "QUEUE: Dispatching job %s" name);
    let now = Ptime_clock.now () in
    let job_instance = JobInstance.create ~input ~delay ~now job in
    Repo.enqueue ctx ~job_instance
    |> Lwt_result.map_err (fun msg ->
           "QUEUE: Failure while enqueuing job instance: " ^ msg)
    |> Lwt.map Result.ok_or_failwith

  let run_job ctx input ~job ~job_instance =
    let job_instance_id = JobInstance.id job_instance in
    let* result =
      Lwt.catch
        (fun () -> WorkableJob.work job ctx ~input)
        (fun exn ->
          let exn_string = Exn.to_string exn in
          Lwt.return
          @@ Error
               ( "Exception caught while running job, this is a bug in your \
                  job handler, make sure to not throw exceptions " ^ exn_string
               ))
    in
    match result with
    | Error msg -> (
        Logs.err (fun m ->
            m "QUEUE: Failure while running job instance %a %s" JobInstance.pp
              job_instance msg);
        let* result =
          Lwt.catch
            (fun () -> WorkableJob.failed job ctx)
            (fun exn ->
              let exn_string = Exn.to_string exn in
              Lwt.return
              @@ Error
                   ( "Exception caught while cleaning up job, this is a bug in \
                      your job failure handler, make sure to not throw \
                      exceptions " ^ exn_string ))
        in
        match result with
        | Error msg ->
            Logs.err (fun m ->
                m
                  "QUEUE: Failure while run failure handler for job instance \
                   %a %s"
                  JobInstance.pp job_instance msg);
            Lwt.return None
        | Ok () ->
            Logs.err (fun m ->
                m "QUEUE: Failure while cleaning up job instance %a" Uuidm.pp
                  job_instance_id);
            Lwt.return None )
    | Ok () ->
        Logs.debug (fun m ->
            m "QUEUE: Successfully ran job instance %a" Uuidm.pp job_instance_id);
        Lwt.return @@ Some ()

  let update ctx ~job_instance = Repo.update ctx ~job_instance

  let work_job ctx ~job ~job_instance =
    let now = Ptime_clock.now () in
    if JobInstance.should_run ~job_instance ~now then
      let input_string = JobInstance.input job_instance in
      let* job_run_status = run_job ctx input_string ~job ~job_instance in
      let job_instance =
        job_instance |> JobInstance.incr_tries
        |> JobInstance.update_next_run_at job
      in
      let job_instance =
        match job_run_status with
        | None ->
            if JobInstance.tries job_instance >= WorkableJob.max_tries job then
              JobInstance.set_failed job_instance
            else job_instance
        | Some () -> JobInstance.set_succeeded job_instance
      in
      update ctx ~job_instance
      |> Lwt_result.map_err (fun msg ->
             "QUEUE: Failure while updating job instance: " ^ msg)
      |> Lwt.map Result.ok_or_failwith
    else (
      Log.debug (fun m ->
          m "QUEUE: Not going to run job instance %a" JobInstance.pp
            job_instance);
      Lwt.return () )

  let work_queue ctx ~jobs =
    let* pending_job_instances =
      Repo.find_workable ctx
      |> Lwt_result.map_err (fun msg ->
             "QUEUE: Failure while finding pending job instances " ^ msg)
      |> Lwt.map Result.ok_or_failwith
    in
    Log.debug (fun m ->
        m "QUEUE: Start working queue of length %d"
          (List.length pending_job_instances));

    let rec loop job_instances jobs =
      match job_instances with
      | [] -> Lwt.return ()
      | job_instance :: job_instances -> (
          let job =
            List.find jobs ~f:(fun job ->
                job |> WorkableJob.name
                |> String.equal (JobInstance.name job_instance))
          in
          match job with
          | None -> loop job_instances jobs
          | Some job -> work_job ctx ~job ~job_instance )
    in
    let* () = loop pending_job_instances jobs in
    Log.debug (fun m -> m "QUEUE: Finish working queue");
    Lwt.return ()

  let on_start ctx =
    let jobs = !registered_jobs in
    let n_jobs = List.length jobs in
    if n_jobs > 0 then (
      Logs.debug (fun m ->
          m "QUEUE: Start queue with %d jobs" (List.length jobs));
      (* Combine all context middleware functions of registered jobs to get the context the jobs run with*)
      let combined_context_fn =
        jobs
        |> List.map ~f:WorkableJob.with_context
        |> List.fold ~init:Fn.id ~f:Fn.compose
      in
      (* This function run every second, the request context gets created here with each tick *)
      let scheduled_function () =
        let ctx = combined_context_fn Core.Ctx.empty in
        work_queue ctx ~jobs
      in
      let schedule =
        Schedule.create Schedule.every_second ~f:scheduled_function
          ~label:"job_queue"
      in
      stop_schedule := Some (ScheduleService.schedule ctx schedule);
      Lwt_result.return () )
    else (
      Logs.debug (fun m ->
          m "QUEUE: No workable jobs found, don't start job queue");
      Lwt_result.return () )
end

module Repo = Queue_service_repo
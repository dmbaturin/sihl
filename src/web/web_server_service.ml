open Base

let run_forever () =
  let p, _ = Lwt.wait () in
  p

let registered_endpoints : Web_server_core.endpoint list ref = ref []

module Make (CmdService : Cmd.Sig.SERVICE) : Web_server_sig.SERVICE = struct
  let start_server _ =
    Logs.debug (fun m -> m "WEB: Starting HTTP server");
    let app = Opium.Std.App.(empty |> port 3000 |> cmd_name "Sihl App") in
    let builders =
      Web_server_core.endpoints_to_opium_builders !registered_endpoints
    in
    let app =
      List.fold ~f:(fun app builder -> builder app) ~init:app builders
    in
    (* We don't want to block here, the returned Lwt.t will never resolve *)
    let _ = Opium.Std.App.start app in
    run_forever ()

  let lifecycle =
    Core.Container.Lifecycle.make "webserver"
      ~dependencies:[ CmdService.lifecycle ]
      (fun ctx -> Lwt.return ctx)
      (fun _ -> Lwt.return ())

  let register_endpoints routes = registered_endpoints := routes
end
open Base

let ( let* ) = Lwt_result.bind

module User = User_core.User

module Make (UserRepo : User_sig.REPOSITORY) : User_sig.SERVICE = struct
  let on_bind ctx =
    let* () = Data.Migration.register ctx (UserRepo.migrate ()) in
    Data.Repo.register_cleaner ctx UserRepo.clean

  let on_start _ = Lwt.return @@ Ok ()

  let on_stop _ = Lwt.return @@ Ok ()

  let get ctx ~user_id = UserRepo.get ~id:user_id |> Data.Db.query ctx

  let get_by_email ctx ~email =
    UserRepo.get_by_email ~email |> Data.Db.query ctx

  let get_all ctx = UserRepo.get_all |> Data.Db.query ctx

  let update_password ctx ?(password_policy = User.default_password_policy)
      ~email ~old_password ~new_password ~new_password_confirmation () =
    let* user =
      get_by_email ctx ~email
      |> Lwt.map Result.ok_or_failwith
      |> Lwt.map (Result.of_option ~error:"User not found to update password")
    in
    let* () =
      User.validate_change_password user ~old_password ~new_password
        ~new_password_confirmation ~password_policy
      |> Lwt.return
    in
    let updated_user = User.set_user_password user new_password in
    let* () = UserRepo.update ~user:updated_user |> Data.Db.query ctx in
    Lwt.return @@ Ok updated_user

  let update_details ctx ~email ~username =
    let* user =
      get_by_email ctx ~email
      |> Lwt.map Result.ok_or_failwith
      |> Lwt.map (Result.of_option ~error:"User not found to update details")
    in
    let updated_user = User.set_user_details user ~email ~username in
    let* () = UserRepo.update ~user:updated_user |> Data.Db.query ctx in
    Lwt.return @@ Ok updated_user

  let set_password ctx ?(password_policy = User.default_password_policy)
      ~user_id ~password ~password_confirmation () =
    let* user =
      get ctx ~user_id
      |> Lwt.map Result.ok_or_failwith
      |> Lwt.map (Result.of_option ~error:"User not found to set password")
    in
    let* () =
      User.validate_new_password ~password ~password_confirmation
        ~password_policy
      |> Lwt.return
    in
    let updated_user = User.set_user_password user password in
    let* () = UserRepo.update ~user:updated_user |> Data.Db.query ctx in
    Lwt.return @@ Ok updated_user

  let create_user ctx ~email ~password ~username =
    let user =
      User.create ~email ~password ~username ~admin:false ~confirmed:false
    in
    let* () = UserRepo.insert ~user |> Data.Db.query ctx in
    Lwt.return @@ Ok user

  let create_admin ctx ~email ~password ~username =
    let* user = UserRepo.get_by_email ~email |> Data.Db.query ctx in
    let* () =
      match user with
      | Some _ -> Lwt.return @@ Error "Email already taken"
      | None -> Lwt.return @@ Ok ()
    in
    let user =
      User.create ~email ~password ~username ~admin:true ~confirmed:true
    in
    let* () = UserRepo.insert ~user |> Data.Db.query ctx in
    Lwt.return @@ Ok user
end

module UserMariaDb = Make (User_service_repo.MariaDb)

let mariadb =
  Core.Container.create_binding User_sig.key
    (module UserMariaDb)
    (module UserMariaDb)

module UserPostgreSql = Make (User_service_repo.PostgreSql)

let postgresql =
  Core.Container.create_binding User_sig.key
    (module UserPostgreSql)
    (module UserPostgreSql)

let get ctx =
  let (module UserService : User_sig.SERVICE) =
    Core.Container.fetch_service_exn User_sig.key
  in
  UserService.get ctx

let get_by_email ctx =
  let (module UserService : User_sig.SERVICE) =
    Core.Container.fetch_service_exn User_sig.key
  in
  UserService.get_by_email ctx

let get_all ctx =
  let (module UserService : User_sig.SERVICE) =
    Core.Container.fetch_service_exn User_sig.key
  in
  UserService.get_all ctx

let update_password ctx =
  let (module UserService : User_sig.SERVICE) =
    Core.Container.fetch_service_exn User_sig.key
  in
  UserService.update_password ctx

let set_password ctx =
  let (module UserService : User_sig.SERVICE) =
    Core.Container.fetch_service_exn User_sig.key
  in
  UserService.set_password ctx

let update_details ctx =
  let (module UserService : User_sig.SERVICE) =
    Core.Container.fetch_service_exn User_sig.key
  in
  UserService.update_details ctx

let create_user ctx =
  let (module UserService : User_sig.SERVICE) =
    Core.Container.fetch_service_exn User_sig.key
  in
  UserService.create_user ctx

let create_admin ctx =
  let (module UserService : User_sig.SERVICE) =
    Core.Container.fetch_service_exn User_sig.key
  in
  UserService.create_admin ctx

let register ctx ?(password_policy = User.default_password_policy) ?username
    ~email ~password ~password_confirmation () =
  match
    User.validate_new_password ~password ~password_confirmation ~password_policy
  with
  | Error msg -> Lwt_result.return @@ Error msg
  | Ok () -> (
      let* user = get_by_email ctx ~email in
      match user with
      | None ->
          create_user ctx ~username ~email ~password
          |> Lwt_result.map (fun user -> Ok user)
      | Some _ -> Lwt_result.return (Error "Invalid email address provided") )

let login ctx ~email ~password =
  let* user =
    get_by_email ctx ~email
    |> Lwt_result.map
         (Result.of_option ~error:"Invalid email or password provided")
  in
  match user with
  | Ok user ->
      if User.matches_password password user then Lwt_result.return @@ Ok user
      else Lwt_result.return @@ Error "Invalid email or password provided"
  | Error msg -> Lwt_result.return @@ Error msg
module type REPOSITORY = sig
  include Data.Repo.Sig.REPO

  val get_all :
    Data_db_core.connection -> (User_core.User.t list, string) Result.t Lwt.t

  val get :
    Data_db_core.connection ->
    id:string ->
    (User_core.User.t option, string) Result.t Lwt.t

  val get_by_email :
    Data_db_core.connection ->
    email:string ->
    (User_core.User.t option, string) Result.t Lwt.t

  val insert :
    Data_db_core.connection ->
    user:User_core.User.t ->
    (unit, string) Result.t Lwt.t

  val update :
    Data_db_core.connection ->
    user:User_core.User.t ->
    (unit, string) Result.t Lwt.t
end

module type SERVICE = sig
  include Core_container.SERVICE

  val get_all : Core.Ctx.t -> (User_core.User.t list, string) Result.t Lwt.t

  val get :
    Core.Ctx.t ->
    user_id:string ->
    (User_core.User.t option, string) Result.t Lwt.t

  val get_by_email :
    Core.Ctx.t ->
    email:string ->
    (User_core.User.t option, string) Result.t Lwt.t

  val update_password :
    Core.Ctx.t ->
    ?password_policy:(string -> (unit, string) Result.t) ->
    email:string ->
    old_password:string ->
    new_password:string ->
    new_password_confirmation:string ->
    unit ->
    (User_core.User.t, string) Result.t Lwt.t

  val update_details :
    Core.Ctx.t ->
    email:string ->
    username:string option ->
    (User_core.User.t, string) Result.t Lwt.t

  val set_password :
    Core.Ctx.t ->
    ?password_policy:(string -> (unit, string) Result.t) ->
    user_id:string ->
    password:string ->
    password_confirmation:string ->
    unit ->
    (User_core.User.t, string) Result.t Lwt.t

  val create_user :
    Core.Ctx.t ->
    email:string ->
    password:string ->
    username:string option ->
    (User_core.User.t, string) Result.t Lwt.t

  val create_admin :
    Core.Ctx.t ->
    email:string ->
    password:string ->
    username:string option ->
    (User_core.User.t, string) Result.t Lwt.t
end

let key : (module SERVICE) Core.Container.key =
  Core.Container.create_key "user.service"
type t

val pp : Format.formatter -> t -> unit

val show : t -> string

val equal : t -> t -> bool

type handler = Core.Ctx.t -> Web_res.t Lwt.t

val handler : t -> handler

val set_handler : handler -> t -> t

val get : string -> handler -> t

val post : string -> handler -> t

val put : string -> handler -> t

val delete : string -> handler -> t

val all : string -> handler -> t

val prefix : string -> t -> t

val to_opium_builder : t -> Opium.App.builder
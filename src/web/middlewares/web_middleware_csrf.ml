(* TODO
https://docs.djangoproject.com/en/3.0/ref/csrf/#how-it-works *)

let m () =
  let filter handler ctx = handler ctx in
  Web_middleware_core.create ~name:"csrf" filter
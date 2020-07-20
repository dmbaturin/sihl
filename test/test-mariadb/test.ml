open Base
open Alcotest_lwt

let ( let* ) = Lwt.bind

module TestSuite =
  Test_common.Test.Make (Sihl.Data.Db.Service) (Sihl.Data.Repo.Service)
    (Service.Session)
    (Service.User)
    (Service.Storage)
    (Service.EmailTemplate)

let test_suite =
  [ TestSuite.session; TestSuite.storage; TestSuite.user; TestSuite.email ]

let config =
  Sihl.Config.create ~development:[]
    ~test:[ ("DATABASE_URL", "mariadb://admin:password@127.0.0.1:3306/dev") ]
    ~production:[]

let services : (module Sihl.Core.Container.SERVICE) list =
  [
    (module Service.Session);
    (module Service.User);
    (module Service.Storage);
    (module Service.EmailTemplate);
  ]

let () =
  Lwt_main.run
    (let* () =
       let ctx = Sihl.Core.Ctx.empty in
       let* () = Service.Test.services ctx ~config ~services in
       Lwt.return ()
     in
     run "mariadb" @@ test_suite)

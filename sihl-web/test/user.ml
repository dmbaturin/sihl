open Alcotest_lwt
open Lwt.Syntax

let token_alco = Alcotest.testable Sihl_contract.Token.pp Sihl_contract.Token.equal

let apply_middlewares handler =
  let token = Sihl_web.Bearer_token.middleware in
  let user = Sihl_web.User.token_middleware in
  handler |> Rock.Middleware.apply token |> Rock.Middleware.apply user
;;

let login_with_bearer_token _ () =
  let* () = Sihl_core.Cleaner.clean_all () in
  let* user =
    Sihl_facade.User.create_user
      ~email:"foo@example.com"
      ~password:"123123"
      ~username:None
  in
  let* token =
    Sihl_facade.Token.create ~kind:"auth" ~data:(Sihl_contract.User.id user) ()
  in
  let token_header = Format.sprintf "Bearer %s" (Sihl_contract.Token.value token) in
  let req =
    Opium.Request.get "/some/path/login"
    |> Opium.Request.add_header ("authorization", token_header)
  in
  let handler req =
    let user = Sihl_web.User.find req in
    let email = Sihl_contract.User.email user in
    Alcotest.(check string "has same email" "foo@example.com" email);
    Lwt.return @@ Opium.Response.of_plain_text ""
  in
  let wrapped_handler = apply_middlewares handler in
  let* _ = wrapped_handler req in
  Lwt.return ()
;;

let suite =
  [ "user", [ test_case "login with bearer token" `Quick login_with_bearer_token ] ]
;;
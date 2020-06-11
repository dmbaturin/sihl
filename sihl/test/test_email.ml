let test_email_rendering_simple () =
  let data =
    Sihl.Email.TemplateData.empty
    |> Sihl.Email.TemplateData.add ~key:"foo" ~value:"bar"
  in
  let actual =
    Sihl.Email.Template.render data
      (Sihl.Email.Template.make ~text:"{foo}" "test")
  in
  let _ = Alcotest.(check string) "Renders template" "bar" actual in
  let data =
    Sihl.Email.TemplateData.empty
    |> Sihl.Email.TemplateData.add ~key:"foo" ~value:"hey"
    |> Sihl.Email.TemplateData.add ~key:"bar" ~value:"ho"
  in
  let actual =
    Sihl.Email.Template.render data
      (Sihl.Email.Template.make ~text:"{foo} {bar}" "test")
  in
  Alcotest.(check string) "Renders template" "hey ho" actual

let test_email_rendering_complex () =
  let data =
    Sihl.Email.TemplateData.empty
    |> Sihl.Email.TemplateData.add ~key:"foo" ~value:"hey"
    |> Sihl.Email.TemplateData.add ~key:"bar" ~value:"ho"
  in
  let actual =
    Sihl.Email.Template.render data
      (Sihl.Email.Template.make ~text:"{foo} {bar}{foo}" "test")
  in
  Alcotest.(check string) "Renders template" "hey hohey" actual
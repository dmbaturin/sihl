let name = "User Management App";
let namespace = "users";

let adminUiPages = [
  AdminUi.Page.make(~path="/admin/", ~label="Dashboard"),
  AdminUi.Page.make(~path="/admin/users/users/", ~label="Users"),
];

let routes = database => [
  Routes.Login.endpoint(namespace, database),
  Routes.Logout.endpoint(namespace, database),
  Routes.Register.endpoint(namespace, database),
  Routes.ConfirmEmail.endpoint(namespace, database),
  Routes.RequestPasswordReset.endpoint(namespace, database),
  Routes.ResetPassword.endpoint(namespace, database),
  Routes.UpdatePassword.endpoint(namespace, database),
  Routes.SetPassword.endpoint(namespace, database),
  Routes.UpdateUserDetails.endpoint(namespace, database),
  Routes.GetMe.endpoint(namespace, database),
  Routes.GetUser.endpoint(namespace, database),
  Routes.GetUsers.endpoint(namespace, database),
  Routes.AdminUi.Dashboard.endpoint(namespace, database),
  Routes.AdminUi.Login.endpoint(namespace, database),
  Routes.AdminUi.Logout.endpoint(namespace, database),
  Routes.AdminUi.Users.endpoint(namespace, database),
  Routes.AdminUi.User.endpoint(namespace, database),
];

let configurationSchema =
  Sihl.Core.Config.Schema.[
    string_(
      ~default="console",
      ~choices=["smtp", "console"],
      "EMAIL_BACKEND",
    ),
    string_("SMTP_HOST"),
    int_("SMTP_PORT"),
    string_("SMTP_AUTH_USERNAME"),
    string_("SMTP_AUTH_PASSWORD"),
    bool_("SMTP_SECURE", ~default=false),
    bool_("SMTP_POOL", ~default=false),
  ];

let app = externalAdminUiPages => {
  let adminUiPages = Belt.List.concat(adminUiPages, externalAdminUiPages);
  AdminUi.State.pages := adminUiPages;
  Sihl.App.Main.App.make(
    ~name,
    ~namespace,
    ~routes,
    ~migration=Migrations.MariaDb.make(~namespace),
    ~commands=[Cli.createAdmin],
    ~configurationSchema,
  );
};

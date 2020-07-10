module Service = Web_server_service

type routes = Web_server_core.routes

type middleware_stack = Web_server_core.middleware_stack

type stacked_routes = Web_server_core.stacked_routes

let register_routes = Web_server_service.Service.register_routes
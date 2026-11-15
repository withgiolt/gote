//// Two entry points, one router.
////
//// - `handle` is what `giolt build` / `giolt dev` compile with afterglow.
//// - `main` runs on the BEAM with `gleam run`: mist, the server component's
////   WebSocket, and the static files giolt would otherwise serve.

import gleam/erlang/process
import gleam/http/request
import gleam/io
import gleam/string
import mist
import server/live
import server/router
import server/runtime
import wisp
import wisp/wisp_mist

pub fn handle(req: wisp.Request) -> wisp.Response {
  router.route(req, runtime.Worker)
}

pub fn main() -> Nil {
  check_build()
  wisp.configure_logger()
  let assert Ok(priv) = wisp.priv_directory("server")
  let static_dir = priv <> "/static"
  let secret = wisp.random_string(64)
  let wisp_handler =
    wisp_mist.handler(
      fn(req) {
        use <- wisp.log_request(req)
        use <- wisp.serve_static(req, under: "/", from: static_dir)
        router.route(req, runtime.Beam)
      },
      secret,
    )
  let port = 8000
  let assert Ok(_) =
    fn(req) {
      case request.path_segments(req) {
        ["live", "ws"] -> live.serve(req)
        _ -> wisp_handler(req)
      }
    }
    |> mist.new
    |> mist.bind("127.0.0.1")
    |> mist.port(port)
    |> mist.start
  process.sleep_forever()
}

/// Refuse to start with a client bundle or prerendered page older than the
/// sources: the browser would hydrate fresh server HTML with stale code.
fn check_build() -> Nil {
  let output = shell("node ../scripts/build.mjs check 2>&1; echo \"exit=$?\"")
  case string.contains(output, "exit=0") {
    True -> Nil
    False -> {
      io.println_error(output)
      io.println_error(
        "Run `node ../scripts/build.mjs` (or ../scripts/dev.sh) first.",
      )
      halt(1)
    }
  }
}

@external(erlang, "server_ffi", "shell")
fn shell(command: String) -> String

@external(erlang, "erlang", "halt")
fn halt(status: Int) -> Nil

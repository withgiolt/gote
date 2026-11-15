//// Two ways to run the same router:
////
//// - `handle` is the entry giolt compiles to WebAssembly for afterglow.
//// - `main` starts mist on the BEAM (`just serve`). It also serves the static
////   files and the server component's WebSocket.

import gleam/erlang/process
import gleam/http/request
import mist
import server/component/clock
import server/router
import server/runtime
import wisp
import wisp/wisp_mist

pub fn handle(req: wisp.Request) -> wisp.Response {
  router.route(req, runtime.Worker)
}

pub fn main() -> Nil {
  wisp.configure_logger()
  let assert Ok(priv) = wisp.priv_directory("server")
  let static_dir = priv <> "/static"
  // Lustre ships the server component's browser runtime in its priv/static.
  let assert Ok(lustre_priv) = wisp.priv_directory("lustre")
  let secret = wisp.random_string(64)
  let wisp_handler =
    wisp_mist.handler(
      fn(req) {
        use <- wisp.log_request(req)
        use <- wisp.serve_static(req, under: "/", from: static_dir)
        use <- wisp.serve_static(
          req,
          under: "/lustre",
          from: lustre_priv <> "/static",
        )
        router.route(req, runtime.Beam)
      },
      secret,
    )
  let port = 8000
  let assert Ok(_) =
    fn(req) {
      case request.path_segments(req) {
        ["live", "ws"] -> clock.serve(req)
        _ -> wisp_handler(req)
      }
    }
    |> mist.new
    |> mist.bind("127.0.0.1")
    |> mist.port(port)
    |> mist.start
  process.sleep_forever()
}

//// Every route. Both entry points in server.gleam call `route`: the giolt
//// `handle` (afterglow) with `Worker`, and `main` (mist on the BEAM) with
//// `Beam`. Static files (the client bundle, CSS, prerendered.html) never get
//// here: giolt serves dist/static, and `main` serves priv/static.

import gleam/http
import gleam/json
import server/pages
import server/runtime.{type Runtime}
import server/stats as server_stats
import shared/stats
import wisp

pub fn route(req: wisp.Request, runtime: Runtime) -> wisp.Response {
  case req.method, wisp.path_segments(req) {
    http.Get, [] -> html(pages.home(runtime))
    http.Get, ["ssr"] -> html(pages.ssr(runtime))
    http.Get, ["app"] -> html(pages.app())
    http.Get, ["islands"] -> html(pages.islands(runtime))
    http.Get, ["live"] -> html(pages.live(runtime))
    http.Get, ["data"] -> html(pages.data(runtime))
    // Browsers ask for /favicon.ico on pages without an icon link, like JSON.
    http.Get, ["favicon.ico"] -> wisp.redirect(to: "/assets/favicon.svg")
    http.Get, ["api", "stats.json"] ->
      server_stats.current()
      |> stats.to_json
      |> json.to_string
      |> wisp.json_response(200)
    // On the BEAM, mist takes /live/ws before wisp sees it.
    _, ["live", "ws"] ->
      wisp.response(501)
      |> wisp.string_body(
        "Server components need a WebSocket, which afterglow Workers don't support.\n",
      )
    http.Get, _ -> wisp.html_response(pages.not_found(), 404)
    _, _ -> wisp.method_not_allowed([http.Get])
  }
}

fn html(body: String) -> wisp.Response {
  wisp.html_response(body, 200)
}

//// Every route. Static files (client.js, CSS, prerendered.html) never get
//// here: `server.main` serves priv/static on the BEAM, and giolt serves it
//// on afterglow.

import gleam/http
import gleam/json
import server/page/app
import server/page/data
import server/page/home
import server/page/islands
import server/page/live
import server/page/not_found
import server/page/ssr
import server/runtime.{type Runtime}
import server/stats as server_stats
import shared/stats
import wisp

pub fn route(req: wisp.Request, runtime: Runtime) -> wisp.Response {
  case req.method, wisp.path_segments(req) {
    http.Get, [] -> html(home.render(runtime))
    http.Get, ["ssr"] -> html(ssr.render(runtime))
    http.Get, ["app"] -> html(app.render())
    http.Get, ["islands"] -> html(islands.render(runtime))
    http.Get, ["live"] -> html(live.render(runtime))
    http.Get, ["data"] -> html(data.render(runtime))

    http.Get, ["api", "stats.json"] ->
      server_stats.current()
      |> stats.to_json
      |> json.to_string
      |> wisp.json_response(200)

    // On the BEAM, server.main answers this before the router sees it.
    _, ["live", "ws"] ->
      wisp.response(501)
      |> wisp.string_body("Server components need the BEAM.\n")

    http.Get, ["favicon.ico"] -> wisp.redirect(to: "/assets/favicon.svg")
    http.Get, _ -> wisp.html_response(not_found.render(), 404)
    _, _ -> wisp.method_not_allowed([http.Get])
  }
}

fn html(body: String) -> wisp.Response {
  wisp.html_response(body, 200)
}

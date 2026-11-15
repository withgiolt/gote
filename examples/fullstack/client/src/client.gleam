//// Browser entry. It hydrates whatever the server put on the page:
////
//// - `<div id="app">` with `<script id="app-state">`: the full-page app.
//// - every `[data-island]` element: one island each, with its props in
////   `data-props`.
////
//// The server stamps the id of the build that produced it on <html>. If this
//// bundle came from another build, its view code may differ from the server's,
//// and hydrating would silently swap fresh server HTML for stale output, so
//// it refuses and says so in the console instead.

import client/dom
import gleam/dynamic/decode
import gleam/json
import gleam/list
import lustre
import rsvp
import shared/converter
import shared/counter
import shared/stats
import shared/todos

pub fn main() -> Nil {
  case dom.page_build_id() == dom.bundle_build_id() {
    False ->
      dom.console_error(
        "gote: not hydrating. The page was rendered by build "
        <> dom.page_build_id()
        <> " but this bundle is build "
        <> dom.bundle_build_id()
        <> ". Rebuild with `node scripts/build.mjs`.",
      )
    True -> {
      hydrate_app()
      list.each(dom.islands(), hydrate_island)
    }
  }
}

fn hydrate_app() -> Nil {
  case dom.text_of("app-state") {
    Error(Nil) -> Nil
    Ok(text) ->
      case json.parse(text, todos.state_decoder()) {
        Ok(state) -> started(lustre.start(todos.app(), "#app", state), "app")
        Error(_) -> dom.console_error("gote: #app-state did not decode")
      }
  }
}

fn hydrate_island(island: dom.Island) -> Nil {
  let selector = "#" <> island.id
  case island.name {
    "counter" ->
      with_props(island, counter.props_decoder(), fn(props) {
        started(lustre.start(counter.app(), selector, props), island.id)
      })
    "converter" ->
      with_props(island, converter.props_decoder(), fn(props) {
        started(lustre.start(converter.app(), selector, props), island.id)
      })
    "stats" ->
      with_props(island, stats.decoder(), fn(props) {
        started(
          lustre.start(stats.app(fetch_stats), selector, props),
          island.id,
        )
      })
    other -> dom.console_error("gote: unknown island " <> other)
  }
}

fn with_props(
  island: dom.Island,
  decoder: decode.Decoder(props),
  start: fn(props) -> Nil,
) -> Nil {
  case json.parse(island.props, decoder) {
    Ok(props) -> start(props)
    Error(_) -> dom.console_error("gote: bad props for #" <> island.id)
  }
}

fn started(result: Result(a, lustre.Error), what: String) -> Nil {
  case result {
    Ok(_) -> Nil
    Error(_) -> dom.console_error("gote: could not start " <> what)
  }
}

fn fetch_stats() {
  rsvp.get("/api/stats.json", rsvp.expect_json(stats.decoder(), to_fetched))
}

fn to_fetched(result: Result(stats.Stats, rsvp.Error(e))) -> stats.Msg {
  case result {
    Ok(value) -> stats.Fetched(Ok(value))
    Error(_) -> stats.Fetched(Error("Could not load /api/stats.json"))
  }
}

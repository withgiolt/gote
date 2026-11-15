//// The browser bundle. Each page loads the same file, and only the parts the
//// server put on that page start.

import client/dom
import client/island
import gleam/json
import lustre
import rsvp
import shared/converter
import shared/counter
import shared/stats
import shared/todos

pub fn main() -> Nil {
  start_todos()
  island.hydrate(counter.island(), counter.app())
  island.hydrate(converter.island(), converter.app())
  island.hydrate(stats.island(), stats.app(fetch_stats))
}

/// /app: the whole page is a Lustre app, with its state in `#app-state`.
fn start_todos() -> Nil {
  case dom.text_of(todos.state_id) {
    Error(Nil) -> Nil
    Ok(text) ->
      case json.parse(text, todos.state_decoder()) {
        Error(_) -> dom.console_error("Could not read the todos state")
        Ok(state) ->
          case lustre.start(todos.app(), "#" <> todos.root_id, state) {
            Ok(_) -> Nil
            Error(_) -> dom.console_error("Could not start the todo app")
          }
      }
  }
}

fn fetch_stats() {
  rsvp.get("/api/stats.json", rsvp.expect_json(stats.decoder(), stats_fetched))
}

fn stats_fetched(result: Result(stats.Stats, rsvp.Error(e))) -> stats.Msg {
  case result {
    Ok(value) -> stats.Fetched(Ok(value))
    Error(_) -> stats.Fetched(Error("Could not load /api/stats.json"))
  }
}

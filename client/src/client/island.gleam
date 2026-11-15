//// Starts an island on every element the server rendered it into with
//// `shared/island.render`.

import client/dom
import gleam/json
import gleam/list
import lustre
import shared/island.{type Island}

pub fn hydrate(
  island: Island(props, msg),
  app: lustre.App(props, model, msg),
) -> Nil {
  use #(id, props) <- list.each(dom.islands_named(island.name))
  case json.parse(props, island.decoder) {
    Error(_) -> dom.console_error("Bad props for island #" <> id)
    Ok(props) ->
      case lustre.start(app, "#" <> id, props) {
        Ok(_) -> Nil
        Error(_) -> dom.console_error("Could not start island #" <> id)
      }
  }
}

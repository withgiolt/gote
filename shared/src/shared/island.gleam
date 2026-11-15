//// An island is a small Lustre app inside a server-rendered page.
////
//// Each island module (counter, converter, stats) exposes one `Island` value.
//// The server passes it to `render` to put the island's first view and its
//// props into the page, and the client passes the same value to
//// `client/island.hydrate` to find those elements and start the app on them.

import gleam/dynamic/decode.{type Decoder}
import gleam/json.{type Json}
import lustre/attribute
import lustre/element.{type Element}

pub type Island(props, msg) {
  Island(
    /// Written to `data-island` by the server and looked up by the client.
    name: String,
    encode: fn(props) -> Json,
    decoder: Decoder(props),
    /// The view before hydration. Must match the app's first render.
    view: fn(props) -> Element(msg),
  )
}

/// Renders the island's first view inside `<div id={id} data-island data-props>`.
///
/// The view is rendered to a string and inserted as-is. Mapping it into the
/// page's message type with `element.map` would add a `<!-- lustre:map -->`
/// comment that the client's render doesn't have.
pub fn render(
  island: Island(props, island_msg),
  id id: String,
  props props: props,
) -> Element(msg) {
  element.unsafe_raw_html(
    "",
    "div",
    [
      attribute.id(id),
      attribute.data("island", island.name),
      attribute.data("props", json.to_string(island.encode(props))),
    ],
    element.to_string(island.view(props)),
  )
}

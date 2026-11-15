//// Island: a counter. The server renders `view(init(start))` into the page,
//// and the client starts the same app on that element, so Lustre adopts the
//// existing DOM instead of re-rendering it.

import gleam/dynamic/decode
import gleam/int
import gleam/json
import lustre
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import shared/site

pub type Model {
  Model(count: Int, hydrated: Bool)
}

pub type Msg {
  Hydrated
  Increment
  Decrement
}

pub type Props {
  Props(start: Int)
}

pub fn props_to_json(props: Props) -> json.Json {
  json.object([#("start", json.int(props.start))])
}

pub fn props_decoder() -> decode.Decoder(Props) {
  use start <- decode.field("start", decode.int)
  decode.success(Props(start:))
}

/// What the server renders. `hydrated` is always False here.
pub fn initial(props: Props) -> Model {
  Model(count: props.start, hydrated: False)
}

pub fn app() -> lustre.App(Props, Model, Msg) {
  lustre.application(init, update, view)
}

fn init(props: Props) -> #(Model, Effect(Msg)) {
  #(initial(props), effect.from(fn(dispatch) { dispatch(Hydrated) }))
}

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    Hydrated -> #(Model(..model, hydrated: True), effect.none())
    Increment -> #(Model(..model, count: model.count + 1), effect.none())
    Decrement -> #(Model(..model, count: model.count - 1), effect.none())
  }
}

pub fn view(model: Model) -> Element(Msg) {
  html.div([attribute.class("island counter")], [
    html.button(
      [
        attribute.class("dec"),
        attribute.disabled(!model.hydrated),
        event.on_click(Decrement),
      ],
      [html.text("−")],
    ),
    html.output([attribute.class("count")], [
      html.text(int.to_string(model.count)),
    ]),
    html.button(
      [
        attribute.class("inc"),
        attribute.disabled(!model.hydrated),
        event.on_click(Increment),
      ],
      [html.text("+")],
    ),
    site.hydration_badge(model.hydrated),
  ])
}

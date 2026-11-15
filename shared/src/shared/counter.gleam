//// The counter island on /islands.

import gleam/dynamic/decode
import gleam/int
import gleam/json
import lustre
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import shared/island.{type Island, Island}
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

pub fn island() -> Island(Props, Msg) {
  Island(
    name: "counter",
    encode: fn(props: Props) {
      json.object([#("start", json.int(props.start))])
    },
    decoder: {
      use start <- decode.field("start", decode.int)
      decode.success(Props(start:))
    },
    view: fn(props) { view(initial(props)) },
  )
}

fn initial(props: Props) -> Model {
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

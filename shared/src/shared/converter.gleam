//// Island: a temperature converter. It works on floats, and its output has to
//// be the same string on Erlang (server render) and JavaScript (client), or
//// hydration would see different text. `format` avoids `float.to_string`,
//// whose output depends on the target, and rounds to one decimal itself.

import gleam/dynamic/decode
import gleam/float
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
  Model(celsius: Float, raw: String, hydrated: Bool)
}

pub type Msg {
  Hydrated
  /// Idempotent on purpose: Lustre replays input events for non-empty inputs
  /// when it hydrates, so this sets the value instead of changing it.
  SetCelsius(String)
}

pub type Props {
  Props(celsius: Float)
}

pub fn props_to_json(props: Props) -> json.Json {
  json.object([#("celsius", json.float(props.celsius))])
}

pub fn props_decoder() -> decode.Decoder(Props) {
  // A whole number like 20.0 arrives in the browser as the JS number 20, so
  // accept ints as well as floats.
  use celsius <- decode.field(
    "celsius",
    decode.one_of(decode.float, [decode.int |> decode.map(int.to_float)]),
  )
  decode.success(Props(celsius:))
}

pub fn initial(props: Props) -> Model {
  Model(celsius: props.celsius, raw: format(props.celsius), hydrated: False)
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
    SetCelsius(raw) ->
      case parse(raw) {
        Ok(celsius) -> #(Model(..model, celsius:, raw:), effect.none())
        Error(Nil) -> #(Model(..model, raw:), effect.none())
      }
  }
}

fn parse(raw: String) -> Result(Float, Nil) {
  case float.parse(raw) {
    Ok(value) -> Ok(value)
    Error(Nil) -> int.parse(raw) |> result_to_float
  }
}

fn result_to_float(result: Result(Int, Nil)) -> Result(Float, Nil) {
  case result {
    Ok(value) -> Ok(int.to_float(value))
    Error(Nil) -> Error(Nil)
  }
}

pub fn to_fahrenheit(celsius: Float) -> Float {
  celsius *. 9.0 /. 5.0 +. 32.0
}

/// One decimal, the same on both targets: 70.7, -3.5, 20.0.
pub fn format(value: Float) -> String {
  let tenths = float.round(value *. 10.0)
  let sign = case tenths < 0 {
    True -> "-"
    False -> ""
  }
  let tenths = int.absolute_value(tenths)
  sign <> int.to_string(tenths / 10) <> "." <> int.to_string(tenths % 10)
}

pub fn view(model: Model) -> Element(Msg) {
  html.div([attribute.class("island converter")], [
    html.label([], [
      html.text("°C "),
      html.input([
        attribute.type_("text"),
        attribute.attribute("inputmode", "decimal"),
        attribute.value(model.raw),
        attribute.disabled(!model.hydrated),
        event.on_input(SetCelsius),
      ]),
    ]),
    html.text(" = "),
    html.output([attribute.class("fahrenheit")], [
      html.text(format(to_fahrenheit(model.celsius)) <> " °F"),
    ]),
    site.hydration_badge(model.hydrated),
  ])
}

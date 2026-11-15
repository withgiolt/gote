//// Island for the data page: runtime numbers from the Erlang server. The
//// server renders the numbers it just computed and passes the same numbers as
//// props, and "Refresh" fetches /api/stats.json from the browser.
////
//// Fetching is a browser effect, so the client passes it in (`fetch`), and
//// this module stays target-neutral.

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

pub type Stats {
  Stats(
    otp_release: String,
    schedulers: Int,
    process_count: Int,
    atom_count: Int,
    pid: String,
    worker_sum: Int,
  )
}

pub fn to_json(stats: Stats) -> json.Json {
  json.object([
    #("otp_release", json.string(stats.otp_release)),
    #("schedulers", json.int(stats.schedulers)),
    #("process_count", json.int(stats.process_count)),
    #("atom_count", json.int(stats.atom_count)),
    #("pid", json.string(stats.pid)),
    #("worker_sum", json.int(stats.worker_sum)),
  ])
}

pub fn decoder() -> decode.Decoder(Stats) {
  use otp_release <- decode.field("otp_release", decode.string)
  use schedulers <- decode.field("schedulers", decode.int)
  use process_count <- decode.field("process_count", decode.int)
  use atom_count <- decode.field("atom_count", decode.int)
  use pid <- decode.field("pid", decode.string)
  use worker_sum <- decode.field("worker_sum", decode.int)
  decode.success(Stats(
    otp_release:,
    schedulers:,
    process_count:,
    atom_count:,
    pid:,
    worker_sum:,
  ))
}

pub type Model {
  Model(
    stats: Stats,
    fetches: Int,
    loading: Bool,
    error: String,
    hydrated: Bool,
  )
}

pub type Msg {
  Hydrated
  Refresh
  Fetched(Result(Stats, String))
}

pub fn initial(stats: Stats) -> Model {
  Model(stats:, fetches: 0, loading: False, error: "", hydrated: False)
}

pub fn app(fetch: fn() -> Effect(Msg)) -> lustre.App(Stats, Model, Msg) {
  let init = fn(stats) {
    #(initial(stats), effect.from(fn(dispatch) { dispatch(Hydrated) }))
  }
  lustre.application(init, fn(model, msg) { update(model, msg, fetch) }, view)
}

fn update(
  model: Model,
  msg: Msg,
  fetch: fn() -> Effect(Msg),
) -> #(Model, Effect(Msg)) {
  case msg {
    Hydrated -> #(Model(..model, hydrated: True), effect.none())
    Refresh -> #(Model(..model, loading: True), fetch())
    Fetched(Ok(stats)) -> #(
      Model(
        ..model,
        stats:,
        fetches: model.fetches + 1,
        loading: False,
        error: "",
      ),
      effect.none(),
    )
    Fetched(Error(error)) -> #(
      Model(..model, loading: False, error:),
      effect.none(),
    )
  }
}

pub fn view(model: Model) -> Element(Msg) {
  let stats = model.stats
  html.div([attribute.class("island stats")], [
    html.table([], [
      html.tbody([], [
        row("OTP release", stats.otp_release),
        row("schedulers online", int.to_string(stats.schedulers)),
        row("process count", int.to_string(stats.process_count)),
        row("atom count", int.to_string(stats.atom_count)),
        row("handling process", stats.pid),
        row("sum from a spawned process", int.to_string(stats.worker_sum)),
      ]),
    ]),
    html.p([], [
      html.button(
        [
          attribute.class("refresh"),
          attribute.disabled(!model.hydrated || model.loading),
          event.on_click(Refresh),
        ],
        [html.text("Refresh from /api/stats.json")],
      ),
      html.text(" "),
      html.span([attribute.class("fetches")], [
        html.text("fetched " <> int.to_string(model.fetches) <> " times"),
      ]),
      html.text(" "),
      site.hydration_badge(model.hydrated),
    ]),
    case model.error {
      "" -> element.none()
      error -> html.p([attribute.class("error")], [html.text(error)])
    },
  ])
}

fn row(label: String, value: String) -> Element(msg) {
  html.tr([], [html.td([], [html.text(label)]), html.td([], [html.text(value)])])
}

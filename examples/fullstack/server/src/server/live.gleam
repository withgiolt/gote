//// The server component on /live, and the mist WebSocket that carries it.
//// BEAM only: afterglow has no WebSockets, and its processes end with the
//// request, so `server.handle` never reaches this module.

import gleam/erlang/process.{type Subject}
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/int
import gleam/json
import gleam/option.{Some}
import lustre
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import lustre/server_component
import mist.{type Connection, type ResponseData}
import server/stats

// COMPONENT -------------------------------------------------------------------

pub type Model {
  Model(clock: String, clicks: Int, ticks: Int, pid: String)
}

pub type Msg {
  Tick
  Click(Int)
}

pub fn component() -> lustre.App(Nil, Model, Msg) {
  lustre.application(init, update, view)
}

fn init(_: Nil) -> #(Model, Effect(Msg)) {
  let model =
    Model(
      clock: clock(),
      clicks: 0,
      ticks: 0,
      pid: stats.pid_string(process.self()),
    )
  #(model, start_ticking())
}

/// A helper process sends Tick every second for as long as the component's
/// process is alive. Effects run inside that process, so `self()` is it.
fn start_ticking() -> Effect(Msg) {
  use dispatch <- effect.from
  let component = process.self()
  let _ = process.spawn_unlinked(fn() { tick_loop(component, dispatch) })
  Nil
}

fn tick_loop(component: process.Pid, dispatch: fn(Msg) -> Nil) -> Nil {
  process.sleep(1000)
  case process.is_alive(component) {
    True -> {
      dispatch(Tick)
      tick_loop(component, dispatch)
    }
    False -> Nil
  }
}

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    Tick -> #(
      Model(..model, clock: clock(), ticks: model.ticks + 1),
      effect.none(),
    )
    Click(by) -> #(Model(..model, clicks: model.clicks + by), effect.none())
  }
}

fn view(model: Model) -> Element(Msg) {
  html.div([attribute.class("live-widget")], [
    html.p([], [
      html.text("Server clock: "),
      html.strong([attribute.class("clock")], [html.text(model.clock)]),
      html.text(" (tick " <> int.to_string(model.ticks) <> ")"),
    ]),
    html.p([], [
      html.button([attribute.class("dec"), event.on_click(Click(-1))], [
        html.text("−"),
      ]),
      html.output([attribute.class("clicks")], [
        html.text(int.to_string(model.clicks)),
      ]),
      html.button([attribute.class("inc"), event.on_click(Click(1))], [
        html.text("+"),
      ]),
      html.text(" this number is kept on the server"),
    ]),
    html.p([], [
      html.text("Component process: "),
      html.code([attribute.class("pid")], [html.text(model.pid)]),
    ]),
  ])
}

@external(erlang, "server_ffi", "clock")
fn clock() -> String

// WEBSOCKET -------------------------------------------------------------------

pub fn serve(req: Request(Connection)) -> Response(ResponseData) {
  mist.websocket(
    request: req,
    on_init: init_socket,
    handler: loop_socket,
    on_close: close_socket,
  )
}

type Socket {
  Socket(
    component: lustre.Runtime(Msg),
    self: Subject(server_component.ClientMessage(Msg)),
  )
}

fn init_socket(_connection) {
  let assert Ok(component) = lustre.start_server_component(component(), Nil)
  let self = process.new_subject()
  let selector = process.new_selector() |> process.select(self)
  server_component.register_subject(self) |> lustre.send(to: component)
  #(Socket(component:, self:), Some(selector))
}

fn loop_socket(
  state: Socket,
  message: mist.WebsocketMessage(server_component.ClientMessage(Msg)),
  connection: mist.WebsocketConnection,
) {
  case message {
    mist.Text(text) -> {
      case json.parse(text, server_component.runtime_message_decoder()) {
        Ok(runtime_message) -> lustre.send(state.component, runtime_message)
        Error(_) -> Nil
      }
      mist.continue(state)
    }
    mist.Custom(client_message) -> {
      let frame =
        server_component.client_message_to_json(client_message)
        |> json.to_string
      let _ = mist.send_text_frame(connection, frame)
      mist.continue(state)
    }
    mist.Binary(_) -> mist.continue(state)
    mist.Closed | mist.Shutdown -> mist.stop()
  }
}

fn close_socket(state: Socket) -> Nil {
  lustre.shutdown() |> lustre.send(to: state.component)
}

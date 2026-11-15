//// The todo list on /app: a whole page, nav included, that the server renders
//// and the client takes over. `render` is the server's half and the client
//// starts `app()` on `#app` with the state it reads from `#app-state`.

import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/list
import gleam/string
import lustre
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import shared/site

/// The element the app runs in.
pub const root_id = "app"

/// The `<script type="application/json">` holding the initial state.
pub const state_id = "app-state"

pub type Todo {
  Todo(id: Int, title: String, done: Bool)
}

/// What travels from server to client. `hydrated` is not part of it.
pub type State {
  State(todos: List(Todo), next_id: Int)
}

pub type Model {
  Model(todos: List(Todo), next_id: Int, draft: String, hydrated: Bool)
}

pub type Msg {
  Hydrated
  SetDraft(String)
  Add
  /// Sets, never toggles: hydration may replay the event of a checked box.
  SetDone(id: Int, done: Bool)
  Remove(id: Int)
}

pub fn state_to_json(state: State) -> json.Json {
  json.object([
    #(
      "todos",
      json.array(state.todos, fn(item) {
        json.object([
          #("id", json.int(item.id)),
          #("title", json.string(item.title)),
          #("done", json.bool(item.done)),
        ])
      }),
    ),
    #("next_id", json.int(state.next_id)),
  ])
}

pub fn state_decoder() -> decode.Decoder(State) {
  let todo_decoder = {
    use id <- decode.field("id", decode.int)
    use title <- decode.field("title", decode.string)
    use done <- decode.field("done", decode.bool)
    decode.success(Todo(id:, title:, done:))
  }
  use todos <- decode.field("todos", decode.list(todo_decoder))
  use next_id <- decode.field("next_id", decode.int)
  decode.success(State(todos:, next_id:))
}

/// The server's half: the state as JSON and the app's first view.
pub fn render(state: State) -> List(Element(msg)) {
  [
    html.script(
      [attribute.id(state_id), attribute.type_("application/json")],
      script_json(state_to_json(state)),
    ),
    // Inserted as a string so the HTML matches the client's first render
    // exactly; element.map would add a `<!-- lustre:map -->` comment.
    element.unsafe_raw_html(
      "",
      "div",
      [attribute.id(root_id)],
      element.to_string(view(initial(state))),
    ),
  ]
}

/// JSON that can't end the `<script>` it sits in: `<` becomes `\u003c`, so
/// `</script>` and `<!--` never appear. U+2028/2029 are escaped as well.
fn script_json(value: json.Json) -> String {
  json.to_string(value)
  |> string.replace("<", "\\u003c")
  |> string.replace("\u{2028}", "\\u2028")
  |> string.replace("\u{2029}", "\\u2029")
}

fn initial(state: State) -> Model {
  Model(todos: state.todos, next_id: state.next_id, draft: "", hydrated: False)
}

pub fn app() -> lustre.App(State, Model, Msg) {
  lustre.application(init, update, view)
}

fn init(state: State) -> #(Model, Effect(Msg)) {
  #(initial(state), effect.from(fn(dispatch) { dispatch(Hydrated) }))
}

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    Hydrated -> #(Model(..model, hydrated: True), effect.none())
    SetDraft(draft) -> #(Model(..model, draft:), effect.none())
    Add ->
      case string.trim(model.draft) {
        "" -> #(model, effect.none())
        title -> #(
          Model(
            ..model,
            todos: list.append(model.todos, [Todo(model.next_id, title, False)]),
            next_id: model.next_id + 1,
            draft: "",
          ),
          effect.none(),
        )
      }
    SetDone(id, done) -> #(
      Model(
        ..model,
        todos: list.map(model.todos, fn(item) {
          case item.id == id {
            True -> Todo(..item, done:)
            False -> item
          }
        }),
      ),
      effect.none(),
    )
    Remove(id) -> #(
      Model(
        ..model,
        todos: list.filter(model.todos, fn(item) { item.id != id }),
      ),
      effect.none(),
    )
  }
}

pub fn view(model: Model) -> Element(Msg) {
  let left = list.count(model.todos, fn(item) { !item.done })
  html.div([attribute.class("page")], [
    site.nav("/app"),
    html.h1([], [html.text("Hydrated app")]),
    html.p([], [
      html.text(
        "The server rendered this page and put the todos in a JSON script tag. "
        <> "In the browser, Lustre reads them back and takes over the HTML that "
        <> "is already here, nav included.",
      ),
    ]),
    html.p([], [
      html.text(
        "Changes stay in the browser. The third todo contains </script>, "
        <> "which would break the page if the JSON weren't escaped.",
      ),
    ]),
    site.hydration_badge(model.hydrated),
    html.form([attribute.class("add"), event.on_submit(fn(_) { Add })], [
      html.input([
        attribute.name("title"),
        attribute.placeholder("Something to do"),
        attribute.value(model.draft),
        attribute.disabled(!model.hydrated),
        event.on_input(SetDraft),
      ]),
      html.button([attribute.disabled(!model.hydrated)], [html.text("Add")]),
    ]),
    html.ul([attribute.class("todos")], {
      use item <- list.map(model.todos)
      let id = "todo-" <> int.to_string(item.id)
      html.li([attribute.classes([#("done", item.done)])], [
        html.input([
          attribute.type_("checkbox"),
          attribute.id(id),
          attribute.checked(item.done),
          attribute.disabled(!model.hydrated),
          event.on_check(SetDone(item.id, _)),
        ]),
        html.label([attribute.for(id)], [html.text(item.title)]),
        html.button(
          [
            attribute.class("remove"),
            attribute.disabled(!model.hydrated),
            event.on_click(Remove(item.id)),
          ],
          [html.text("remove")],
        ),
      ])
    }),
    html.p([attribute.class("left")], [
      html.text(int.to_string(left) <> " left"),
    ]),
    site.sources([
      "shared/src/shared/todos.gleam",
      "server/src/server/page/app.gleam",
      "client/src/client.gleam",
    ]),
  ])
}

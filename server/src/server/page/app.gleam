import server/layout.{ClientBundle}
import shared/todos.{Todo}

pub fn render() -> String {
  let state =
    todos.State(
      todos: [
        Todo(1, "Render the page on the server", True),
        Todo(2, "Hydrate it in the browser", False),
        Todo(3, "Escape </script><b>this</b> in the embedded state", False),
      ],
      next_id: 4,
    )

  layout.document(
    title: "Hydrated app",
    script: ClientBundle,
    body: todos.render(state),
  )
}

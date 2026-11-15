import lustre/element/html
import server/layout.{ClientBundle}
import server/runtime.{type Runtime}
import shared/converter
import shared/counter
import shared/island

pub fn render(runtime: Runtime) -> String {
  layout.document(
    title: "Islands",
    script: ClientBundle,
    body: layout.page(
      path: "/islands",
      title: "Islands",
      intro: [
        "Most of this page is plain HTML. The two boxes are islands: small "
        <> "Lustre apps the server renders first and the browser starts "
        <> "afterwards. The rest of the page is never touched.",
      ],
      content: [
        layout.served_by(runtime),
        html.h2([], [html.text("Counter")]),
        island.render(
          counter.island(),
          id: "counter-1",
          props: counter.Props(start: 3),
        ),
        html.p([], [html.text("This paragraph sits between two islands.")]),
        html.h2([], [html.text("Converter")]),
        island.render(
          converter.island(),
          id: "converter-1",
          props: converter.Props(celsius: 20.0),
        ),
      ],
      sources: [
        "server/src/server/page/islands.gleam",
        "shared/src/shared/counter.gleam",
        "shared/src/shared/converter.gleam",
        "shared/src/shared/island.gleam",
        "client/src/client/island.gleam",
      ],
    ),
  )
}

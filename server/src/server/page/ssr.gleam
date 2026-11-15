import gleam/int
import gleam/list
import lustre/attribute
import lustre/element/html
import server/layout.{NoScript}
import server/runtime.{type Runtime}
import server/stats

pub fn render(runtime: Runtime) -> String {
  let squares = stats.squares([1, 2, 3, 4, 5, 6, 7, 8])

  layout.document(
    title: "Server-rendered",
    script: NoScript,
    body: layout.page(
      path: "/ssr",
      title: "Server-rendered",
      intro: [
        "This page is rendered for every request and loads no JavaScript. "
        <> "Each square below was computed by its own Erlang process, so "
        <> "the pids change when you reload.",
      ],
      content: [
        layout.served_by(runtime),
        html.table([attribute.class("squares")], [
          html.thead([], [
            html.tr([], [
              html.th([], [html.text("n")]),
              html.th([], [html.text("n²")]),
              html.th([], [html.text("process")]),
            ]),
          ]),
          html.tbody([], {
            use #(n, square, pid) <- list.map(squares)
            html.tr([], [
              html.td([], [html.text(int.to_string(n))]),
              html.td([], [html.text(int.to_string(square))]),
              html.td([], [html.code([], [html.text(pid)])]),
            ])
          }),
        ]),
      ],
      sources: [
        "server/src/server/page/ssr.gleam",
        "server/src/server/stats.gleam",
      ],
    ),
  )
}

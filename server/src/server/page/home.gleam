import lustre/attribute
import lustre/element/html
import server/layout.{NoScript}
import server/runtime.{type Runtime}

pub fn render(runtime: Runtime) -> String {
  let link = fn(path, label, text) {
    html.li([], [
      html.a([attribute.href(path)], [html.text(label)]),
      html.text(" · " <> text),
    ])
  }

  layout.document(
    title: "Home",
    script: NoScript,
    body: layout.page(
      path: "/",
      title: "gote",
      intro: [
        "A small Lustre site with an Erlang backend. The server code runs on "
          <> "the BEAM and, compiled to WebAssembly by afterglow, on Giolt.",
        "Each page shows one way of getting HTML to the browser and links to "
          <> "the code behind it.",
      ],
      content: [
        layout.served_by(runtime),
        html.ul([attribute.class("cards")], [
          link("/ssr", "Server-rendered", "rendered on every request"),
          link(
            "/prerendered.html",
            "Prerendered",
            "rendered once at build time",
          ),
          link("/app", "Hydrated app", "a whole page Lustre takes over"),
          link("/islands", "Islands", "small apps inside a server page"),
          link("/live", "Server component", "state on the server, BEAM only"),
          link("/data", "Data", "runtime numbers as HTML and JSON"),
        ]),
      ],
      sources: [
        "server/src/server/page/home.gleam",
        "server/src/server/router.gleam",
      ],
    ),
  )
}

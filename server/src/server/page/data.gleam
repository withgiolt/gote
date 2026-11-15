import lustre/attribute
import lustre/element/html
import server/layout.{ClientBundle}
import server/runtime.{type Runtime}
import server/stats as server_stats
import shared/island
import shared/stats

pub fn render(runtime: Runtime) -> String {
  layout.document(
    title: "Data",
    script: ClientBundle,
    body: layout.page(
      path: "/data",
      title: "Data",
      intro: [
        "Numbers the server read from its runtime for this request. Refresh "
        <> "fetches them again from /api/stats.json, which runs the same code.",
      ],
      content: [
        layout.served_by(runtime),
        island.render(
          stats.island(),
          id: "stats-1",
          props: server_stats.current(),
        ),
        html.p([], [
          html.a([attribute.href("/api/stats.json")], [
            html.text("Open /api/stats.json"),
          ]),
        ]),
      ],
      sources: [
        "server/src/server/page/data.gleam",
        "server/src/server/stats.gleam",
        "shared/src/shared/stats.gleam",
      ],
    ),
  )
}

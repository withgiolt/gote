//// Bits every page uses: the nav, the source links and the hydration badge.
//// They live in shared because the todo app renders the nav in the browser too.

import gleam/list
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html

pub const source_base = "https://github.com/withgiolt/gote/blob/main/"

pub type Page {
  Page(path: String, label: String)
}

pub const pages = [
  Page("/", "Home"),
  Page("/ssr", "Server-rendered"),
  Page("/prerendered.html", "Prerendered"),
  Page("/app", "Hydrated app"),
  Page("/islands", "Islands"),
  Page("/live", "Server component"),
  Page("/data", "Data"),
]

pub fn nav(current: String) -> Element(msg) {
  html.nav([attribute.class("site-nav")], {
    use page <- list.map(pages)
    html.a(
      [
        attribute.href(page.path),
        attribute.classes([#("current", page.path == current)]),
      ],
      [html.text(page.label)],
    )
  })
}

/// A short "Source:" list. Each path is relative to the repo root.
pub fn sources(paths: List(String)) -> Element(msg) {
  html.p([attribute.class("sources")], [
    html.text("Source: "),
    ..list.intersperse(
      list.map(paths, fn(path) {
        html.a([attribute.href(source_base <> path)], [
          html.code([], [html.text(path)]),
        ])
      }),
      html.text(", "),
    )
  ])
}

pub fn hydration_badge(hydrated: Bool) -> Element(msg) {
  html.span(
    [
      attribute.class("badge"),
      attribute.data("hydrated", case hydrated {
        True -> "yes"
        False -> "no"
      }),
    ],
    [
      html.text(case hydrated {
        True -> "hydrated"
        False -> "server HTML, not hydrated yet"
      }),
    ],
  )
}

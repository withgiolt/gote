//// The HTML around every page: the document head, the nav and the page frame.

import gleam/list
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import server/runtime.{type Runtime}
import shared/site

/// Which script a page loads.
pub type Script {
  NoScript
  /// The browser bundle built from client/ (see `[tools.lustre.build]` in
  /// client/gleam.toml for where it is written).
  ClientBundle
  /// Lustre's runtime for server components, served from Lustre's own priv/.
  ServerComponentRuntime
}

pub fn document(
  title title: String,
  script script: Script,
  body body: List(Element(msg)),
) -> String {
  let scripts = case script {
    NoScript -> []
    ClientBundle -> [module_script("/assets/client.js")]
    ServerComponentRuntime -> [
      module_script("/lustre/lustre-server-component.min.mjs"),
    ]
  }

  html.html([attribute.lang("en")], [
    html.head([], [
      html.meta([attribute.charset("utf-8")]),
      html.meta([
        attribute.name("viewport"),
        attribute.content("width=device-width, initial-scale=1"),
      ]),
      html.title([], title <> " · gote"),
      html.link([attribute.rel("icon"), attribute.href("/assets/favicon.svg")]),
      html.link([
        attribute.rel("stylesheet"),
        attribute.href("/assets/style.css"),
      ]),
      ..scripts
    ]),
    html.body([], body),
  ])
  |> element.to_document_string
}

fn module_script(src: String) -> Element(msg) {
  html.script([attribute.type_("module"), attribute.src(src)], "")
}

/// A page with the nav, a heading, an intro and a list of its source files.
pub fn page(
  path path: String,
  title title: String,
  intro intro: List(String),
  content content: List(Element(msg)),
  sources sources: List(String),
) -> List(Element(msg)) {
  [
    html.div([attribute.class("page")], [
      site.nav(path),
      html.h1([], [html.text(title)]),
      ..list.flatten([
        list.map(intro, fn(text) { html.p([], [html.text(text)]) }),
        content,
        [site.sources(sources)],
      ])
    ]),
  ]
}

pub fn served_by(runtime: Runtime) -> Element(msg) {
  html.p([attribute.class("served-by")], [
    html.text("Served by " <> runtime.describe(runtime) <> "."),
  ])
}

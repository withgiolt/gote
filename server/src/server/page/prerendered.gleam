//// Written to priv/static/prerendered.html by `server/prerender` during the
//// build, then served as a plain file.

import lustre/attribute
import lustre/element/html
import server/layout.{NoScript}

pub fn render(
  built_at built_at: String,
  otp_release otp_release: String,
) -> String {
  layout.document(
    title: "Prerendered",
    script: NoScript,
    body: layout.page(
      path: "/prerendered.html",
      title: "Prerendered",
      intro: [
        "This page was rendered once, during the build, and is served as a "
        <> "static file. No Erlang code runs when you load it, so the time "
        <> "below doesn't change until the next build.",
      ],
      content: [
        html.table([], [
          html.tbody([], [
            html.tr([], [
              html.td([], [html.text("built at")]),
              html.td([attribute.class("built-at")], [html.text(built_at)]),
            ]),
            html.tr([], [
              html.td([], [html.text("built with OTP")]),
              html.td([], [html.text(otp_release)]),
            ]),
          ]),
        ]),
      ],
      sources: [
        "server/src/server/page/prerendered.gleam",
        "server/src/server/prerender.gleam",
      ],
    ),
  )
}

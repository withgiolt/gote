//// Every HTML page. Pages without islands get no JavaScript at all.

import gleam/int
import gleam/json
import gleam/list
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import lustre/server_component
import server/build_info
import server/runtime.{type Runtime}
import server/stats as server_stats
import shared/converter
import shared/counter
import shared/embed
import shared/site
import shared/stats
import shared/todos

pub type Script {
  NoScript
  ClientBundle
  ServerComponentRuntime
}

pub fn document(
  title title: String,
  script script: Script,
  body body: List(Element(msg)),
) -> String {
  let scripts = case script {
    NoScript -> []
    ClientBundle -> [
      html.script(
        [attribute.type_("module"), attribute.src(build_info.client_bundle)],
        "",
      ),
    ]
    ServerComponentRuntime -> [
      html.script(
        [
          attribute.type_("module"),
          attribute.src("/assets/lustre-server-component.min.mjs"),
        ],
        "",
      ),
    ]
  }

  html.html([attribute.lang("en"), attribute.data("build", build_info.id)], [
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

/// A server-only page: nav, heading, explanation, content, sources.
fn page(
  current: String,
  heading: String,
  explanation: List(String),
  content: List(Element(msg)),
  sources: List(String),
) -> List(Element(msg)) {
  [
    html.div([attribute.class("page")], [
      site.nav(current),
      html.h1([], [html.text(heading)]),
      ..list.flatten([
        list.map(explanation, fn(text) { html.p([], [html.text(text)]) }),
        content,
        [site.sources(sources)],
      ])
    ]),
  ]
}

fn served_by(runtime: Runtime) -> Element(msg) {
  html.p([attribute.class("served-by")], [
    html.text("This response came from " <> runtime.describe(runtime) <> "."),
  ])
}

// HOME ------------------------------------------------------------------------

pub fn home(runtime: Runtime) -> String {
  let card = fn(path, label, text) {
    html.li([], [
      html.a([attribute.href(path)], [html.text(label)]),
      html.text(" · " <> text),
    ])
  }
  document(
    title: "Home",
    script: NoScript,
    body: page(
      "/",
      "gote",
      [
        "A Lustre app with an Erlang backend, split into three Gleam packages: "
          <> "shared (no target, compiled for both), server (target = \"erlang\") "
          <> "and client (target = \"javascript\"). The client never depends on "
          <> "the server, and nothing here uses @target.",
        "The same server code runs on the BEAM with `gleam run` and as "
          <> "WebAssembly on afterglow with `giolt dev` or `giolt build`. Each "
          <> "page below says what it shows and links to the code that does it.",
      ],
      [
        served_by(runtime),
        html.ul([attribute.class("cards")], [
          card(
            "/ssr",
            "Server-rendered",
            "HTML rendered by Erlang on every request, no JavaScript.",
          ),
          card(
            "/prerendered.html",
            "Prerendered",
            "HTML rendered once at build time and served as a static file.",
          ),
          card(
            "/app",
            "Hydrated app",
            "A whole page rendered on the server, then taken over by Lustre in the browser.",
          ),
          card(
            "/islands",
            "Islands",
            "A server-rendered page where only a few components hydrate.",
          ),
          card(
            "/live",
            "Server component",
            "A Lustre component that runs on the server and patches the page over a WebSocket. BEAM only.",
          ),
          card(
            "/data",
            "Data",
            "Numbers from the Erlang runtime, as HTML and as /api/stats.json.",
          ),
        ]),
      ],
      [
        "server/src/server/router.gleam",
        "server/src/server/pages.gleam",
        "shared/src/shared/site.gleam",
      ],
    ),
  )
}

// SERVER-RENDERED -------------------------------------------------------------

pub fn ssr(runtime: Runtime) -> String {
  let squares = server_stats.squares([1, 2, 3, 4, 5, 6, 7, 8])
  document(
    title: "Server-rendered",
    script: NoScript,
    body: page(
      "/ssr",
      "Server-rendered",
      [
        "Erlang rendered this page for this request. It loads no JavaScript. "
          <> "To fill the list below, the request handler spawned one process "
          <> "per number, each sent back its square, and the handler rendered "
          <> "the replies with lustre/element.to_document_string.",
        "Reload the page and the pids change. On afterglow they are processes "
          <> "inside the WebAssembly instance, and they end with the request.",
      ],
      [
        served_by(runtime),
        html.table([attribute.class("squares")], [
          html.thead([], [
            html.tr([], [
              html.th([], [html.text("n")]),
              html.th([], [html.text("n²")]),
              html.th([], [html.text("computed by")]),
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
      ["server/src/server/pages.gleam", "server/src/server/stats.gleam"],
    ),
  )
}

// PRERENDERED -----------------------------------------------------------------

/// Rendered by `gleam run -m server/prerender` at build time.
pub fn prerendered(built_at: String, otp_release: String) -> String {
  document(
    title: "Prerendered",
    script: NoScript,
    body: page(
      "/prerendered.html",
      "Prerendered",
      [
        "This page was rendered once, when the example was built, by "
          <> "server/prerender.gleam on the BEAM. The build wrote it to "
          <> "server/priv/static/prerendered.html, and `giolt build` copies that "
          <> "directory to dist/static, so it is served as a static file and the "
          <> "Erlang code doesn't run for it.",
        "The time below is when it was built, not when you loaded it.",
      ],
      [
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
            html.tr([], [
              html.td([], [html.text("build id")]),
              html.td([], [html.code([], [html.text(build_info.id)])]),
            ]),
          ]),
        ]),
      ],
      [
        "server/src/server/prerender.gleam",
        "server/src/server/pages.gleam",
        "scripts/build.mjs",
      ],
    ),
  )
}

// HYDRATED APP ----------------------------------------------------------------

pub fn app() -> String {
  let state =
    todos.State(
      todos: [
        todos.Todo(1, "Render the page on the server", True),
        todos.Todo(2, "Hydrate it in the browser", False),
        todos.Todo(
          3,
          "Escape </script><b>this</b> in the embedded state",
          False,
        ),
      ],
      next_id: 4,
    )
  document(title: "Hydrated app", script: ClientBundle, body: [
    html.script(
      [attribute.id("app-state"), attribute.type_("application/json")],
      embed.to_script_json(todos.state_to_json(state)),
    ),
    // Rendered to a string and inserted as-is, so the HTML inside #app is
    // exactly what the client's first render produces.
    element.unsafe_raw_html(
      "",
      "div",
      [attribute.id("app")],
      element.to_string(todos.view(todos.initial(state))),
    ),
  ])
}

// ISLANDS ---------------------------------------------------------------------

pub fn islands(runtime: Runtime) -> String {
  let counter_props = counter.Props(start: 3)
  let converter_props = converter.Props(celsius: 20.0)
  document(
    title: "Islands",
    script: ClientBundle,
    body: page(
      "/islands",
      "Islands",
      [
        "Most of this page is plain server HTML. The two boxes are islands: "
          <> "the server renders each one with the component's own view and "
          <> "puts its props in a data-props attribute, and the browser starts "
          <> "a separate Lustre app on each box. Nothing outside them is "
          <> "touched.",
        "Until the bundle has loaded, the buttons and the input are disabled, "
          <> "so a click can't get lost. The converter works on floats and "
          <> "formats them itself, because Erlang and JavaScript print floats "
          <> "differently and the server's text has to match the browser's.",
      ],
      [
        served_by(runtime),
        html.h2([], [html.text("Counter island")]),
        island(
          "counter-1",
          "counter",
          counter.props_to_json(counter_props),
          counter.view(counter.initial(counter_props)),
        ),
        html.p([], [
          html.text("This paragraph is between two islands. It never hydrates."),
        ]),
        html.h2([], [html.text("Converter island")]),
        island(
          "converter-1",
          "converter",
          converter.props_to_json(converter_props),
          converter.view(converter.initial(converter_props)),
        ),
      ],
      [
        "shared/src/shared/counter.gleam",
        "shared/src/shared/converter.gleam",
        "server/src/server/pages.gleam",
        "client/src/client.gleam",
      ],
    ),
  )
}

/// The island's view is rendered to a string and inserted as-is. Mapping it
/// into the page's message type with element.map would add a
/// `<!-- lustre:map -->` comment that the client's render doesn't have.
fn island(
  id: String,
  name: String,
  props: json.Json,
  view: Element(island_msg),
) -> Element(msg) {
  element.unsafe_raw_html(
    "",
    "div",
    [
      attribute.id(id),
      attribute.data("island", name),
      // Attribute values are HTML-escaped by Lustre, so JSON is safe here.
      attribute.data("props", json.to_string(props)),
    ],
    element.to_string(view),
  )
}

// SERVER COMPONENT ------------------------------------------------------------

pub fn live(runtime: Runtime) -> String {
  let explanation = [
    "This widget is a Lustre server component. Its model, update and view run "
    <> "in an Erlang process on the server, one per open tab. The browser only "
    <> "loads Lustre's small server-component runtime, which opens a WebSocket "
    <> "to /live/ws, sends your clicks up and applies the DOM patches that "
    <> "come back. The clock ticks because a server process sends the "
    <> "component a message every second.",
  ]
  let #(script, content) = case runtime {
    runtime.Beam -> #(ServerComponentRuntime, [
      served_by(runtime),
      server_component.element(
        [server_component.route("/live/ws"), attribute.id("live")],
        [],
      ),
    ])
    runtime.Worker -> #(NoScript, [
      served_by(runtime),
      html.div([attribute.class("unsupported")], [
        html.p([], [
          html.strong([], [html.text("Not available on afterglow. ")]),
          html.text(
            "A server component needs a process that outlives the request and "
            <> "a WebSocket (or a streamed SSE response) held open by the "
            <> "server. An afterglow Worker ends every process when the "
            <> "response is sent, and it can only return a complete response, "
            <> "so there's nothing for the browser to connect to. Run "
            <> "`gleam run` in server/ to see it on the BEAM.",
          ),
        ]),
      ]),
    ])
  }
  document(
    title: "Server component",
    script:,
    body: page("/live", "Server component", explanation, content, [
      "server/src/server/live.gleam",
      "server/src/server.gleam",
      "server/src/server/pages.gleam",
    ]),
  )
}

// DATA ------------------------------------------------------------------------

pub fn data(runtime: Runtime) -> String {
  let current = server_stats.current()
  document(
    title: "Data",
    script: ClientBundle,
    body: page(
      "/data",
      "Data",
      [
        "The Erlang server computed these numbers for this request, rendered "
          <> "them into the table and passed the same values to the island as "
          <> "props. Refresh calls /api/stats.json from the browser, which "
          <> "runs the same Erlang code and returns JSON that the island "
          <> "decodes with the decoder in shared/stats.gleam.",
        "On afterglow the scheduler and process counts come from its runtime, "
          <> "not from a BEAM node.",
      ],
      [
        served_by(runtime),
        island(
          "stats-1",
          "stats",
          stats.to_json(current),
          stats.view(stats.initial(current)),
        ),
        html.p([], [
          html.a([attribute.href("/api/stats.json")], [
            html.text("Open /api/stats.json"),
          ]),
        ]),
      ],
      [
        "shared/src/shared/stats.gleam",
        "server/src/server/stats.gleam",
        "server/src/server/router.gleam",
        "client/src/client.gleam",
      ],
    ),
  )
}

// NOT FOUND -------------------------------------------------------------------

pub fn not_found() -> String {
  document(
    title: "Not found",
    script: NoScript,
    body: page("", "Not found", ["There's no page here."], [], [
      "server/src/server/router.gleam",
    ]),
  )
}

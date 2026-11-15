import lustre/attribute
import lustre/element/html
import lustre/server_component
import server/layout.{NoScript, ServerComponentRuntime}
import server/runtime.{type Runtime}

pub fn render(runtime: Runtime) -> String {
  let #(script, widget) = case runtime {
    runtime.Beam -> #(
      ServerComponentRuntime,
      server_component.element(
        [server_component.route("/live/ws"), attribute.id("live")],
        [],
      ),
    )
    runtime.Worker -> #(
      NoScript,
      html.div([attribute.class("unsupported")], [
        html.p([], [
          html.strong([], [html.text("Not available on afterglow. ")]),
          html.text(
            "A server component needs a process that outlives the request "
            <> "and a WebSocket to it. Workers have neither. Run the server "
            <> "on the BEAM with `just serve` to see it.",
          ),
        ]),
      ]),
    )
  }

  layout.document(
    title: "Server component",
    script:,
    body: layout.page(
      path: "/live",
      title: "Server component",
      intro: [
        "The widget below runs on the server, in one Erlang process per open "
        <> "tab. The browser only sends clicks over a WebSocket and applies "
        <> "the changes that come back. The clock ticks because the server "
        <> "sends the component a message every second.",
      ],
      content: [layout.served_by(runtime), widget],
      sources: [
        "server/src/server/page/live.gleam",
        "server/src/server/component/clock.gleam",
      ],
    ),
  )
}

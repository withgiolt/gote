import gleam/erlang/atom
import gleam/erlang/charlist.{type Charlist}
import gleam/erlang/process
import gleam/int
import gleam/json
import gleam/list
import lustre/attribute
import lustre/element
import lustre/element/html
import wisp

pub fn handle(req: wisp.Request) -> wisp.Response {
  case wisp.path_segments(req) {
    [] -> page(home_page())
    ["status.json"] -> status_json()
    _ -> wisp.not_found()
  }
}

fn page(document: element.Element(a)) -> wisp.Response {
  element.to_document_string(document)
  |> wisp.html_response(200)
}

fn home_page() -> element.Element(a) {
  let stats = runtime_stats()

  layout("gote", [
    html.h1([], [html.text("gote")]),
    html.p([attribute.class("subtitle")], [html.text("Gleam on the Edge")]),
    html.p([], [
      html.text(
        "A tiny wisp + lustre app, prerendered on the BEAM and shipped as "
        <> "a WebAssembly module by afterglow.",
      ),
    ]),
    html.p([], [
      html.text("This page has no client-side JavaScript — "),
      html.text("lustre is only used here to build the HTML tree."),
    ]),
    html.h2([], [html.text("live from the erlang runtime")]),
    html.p([], [
      html.text(
        "Everything in this table was computed on the BEAM at request time.",
      ),
    ]),
    html.table([], [
      status_row(
        "scheduler count",
        int.to_string(stats.schedulers) <> " (erlang:system_info/1)",
      ),
      status_row(
        "process count",
        int.to_string(stats.process_count) <> " (erlang:system_info/1)",
      ),
      status_row(
        "atom count",
        int.to_string(stats.atom_count) <> " (erlang:system_info/1)",
      ),
      status_row("handling process", stats.pid <> " (erlang:pid_to_list/1)"),
      status_row(
        "worker sum",
        int.to_string(stats.worker_sum) <> " (computed in a spawned process)",
      ),
    ]),
    html.nav([], [
      html.a([attribute.class("button"), attribute.href("/")], [
        html.text("↻ refresh"),
      ]),
      html.a([attribute.href("/status.json")], [
        html.text("same data as JSON →"),
      ]),
    ]),
    html.br([]),
    html.a(
      [
        attribute.href("https://giolt.com"),
        attribute.target("_blank"),
      ],
      [html.text("Demo by Giolt")],
    ),
  ])
}

fn status_json() -> wisp.Response {
  let stats = runtime_stats()

  json.object([
    #("schedulers", json.int(stats.schedulers)),
    #("process_count", json.int(stats.process_count)),
    #("atom_count", json.int(stats.atom_count)),
    #("pid", json.string(stats.pid)),
    #("worker_sum", json.int(stats.worker_sum)),
  ])
  |> json.to_string
  |> wisp.json_response(200)
}

fn status_row(label: String, value: String) -> element.Element(a) {
  html.tr([], [
    html.td([], [html.text(label)]),
    html.td([], [html.text(value)]),
  ])
}

fn layout(title: String, body: List(element.Element(a))) -> element.Element(a) {
  html.html([], [
    html.head([], [
      html.meta([attribute.attribute("charset", "utf-8")]),
      html.title([], title),
      html.style(
        [],
        "body { font-family: sans-serif; max-width: 40rem; margin: 3rem auto; padding: 0 1rem; color: #222; }"
          <> "h1 { margin-bottom: 0.25rem; }"
          <> ".subtitle { margin-top: 0; color: #777; font-size: 0.95rem; letter-spacing: 0.03em; text-transform: uppercase; }"
          <> "nav { margin-top: 2rem; display: flex; align-items: center; gap: 1rem; }"
          <> "table { border-collapse: collapse; margin-top: 1rem; }"
          <> "td { padding: 0.25rem 0.75rem 0.25rem 0; border-bottom: 1px solid #ddd; }"
          <> ".button { display: inline-block; padding: 0.4rem 0.9rem; border: 1px solid #222; border-radius: 0.3rem; text-decoration: none; color: #222; }"
          <> ".button:hover { background: #222; color: #fff; }",
      ),
    ]),
    html.body([], body),
  ])
}

type RuntimeStats {
  RuntimeStats(
    schedulers: Int,
    process_count: Int,
    atom_count: Int,
    pid: String,
    worker_sum: Int,
  )
}

fn runtime_stats() -> RuntimeStats {
  RuntimeStats(
    schedulers: erlang_system_info(atom.create("schedulers_online")),
    process_count: erlang_system_info(atom.create("process_count")),
    atom_count: erlang_system_info(atom.create("atom_count")),
    pid: pid_to_string(process.self()),
    worker_sum: sum_in_worker_process([4, 8, 15, 16, 23, 42]),
  )
}

@external(erlang, "erlang", "system_info")
fn erlang_system_info(item: atom.Atom) -> Int

@external(erlang, "erlang", "pid_to_list")
fn pid_to_list(pid: process.Pid) -> Charlist

fn pid_to_string(pid: process.Pid) -> String {
  pid_to_list(pid) |> charlist.to_string
}

fn sum_in_worker_process(numbers: List(Int)) -> Int {
  let reply_to = process.new_subject()

  process.spawn(fn() {
    let total = list.fold(numbers, 0, fn(acc, n) { acc + n })
    process.send(reply_to, total)
  })

  let assert Ok(total) = process.receive(reply_to, within: 1000)
  total
}

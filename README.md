# gote

A small Lustre site with an Erlang backend, deployed to
[Giolt](https://giolt.com). Each page shows a different way of getting HTML
to the browser: rendered per request, prerendered, hydrated, islands, and a
server component.

The same server code runs on the BEAM with mist, and as WebAssembly on
[afterglow](https://github.com/withgiolt/afterglow), which is what Giolt runs.

## Running it

You need Gleam 1.19, Erlang/OTP 28 or 29, rebar3, Node 20 or newer (giolt
runs on Node) and [just](https://github.com/casey/just).

```sh
just dev      # afterglow at http://localhost:3000, rebuilds on changes
just serve    # the BEAM at http://127.0.0.1:8000
just build    # server/dist, ready to deploy
just deploy   # build and upload to Giolt
just check    # format check and build every package
```

## Project layout

Three Gleam packages. `client` and `server` both depend on `shared`, and never
on each other.

```
shared/src/shared/
  site.gleam          nav, source links, hydration badge
  island.gleam        the Island type and how the server renders one
  counter.gleam       island on /islands
  converter.gleam     island on /islands
  stats.gleam         the Stats type, its JSON, and the island on /data
  todos.gleam         the todo app on /app

server/src/
  server.gleam        entry points: `main` (BEAM) and `handle` (afterglow)
  server/router.gleam every route
  server/layout.gleam the HTML document and page frame
  server/page/*.gleam one module per page
  server/component/clock.gleam  the server component on /live
  server/stats.gleam  numbers read from the Erlang runtime
  server/prerender.gleam        writes prerendered.html during the build

client/src/
  client.gleam        the browser entry: starts the todo app and the islands
  client/island.gleam starts an island on the elements the server rendered
  client/dom.gleam    the few DOM lookups that need JavaScript
client/assets/        CSS and favicon
```

## Pages

| Path | Shows | Code |
| --- | --- | --- |
| `/` | An overview | `server/page/home.gleam` |
| `/ssr` | HTML rendered on every request, no JavaScript | `server/page/ssr.gleam` |
| `/prerendered.html` | HTML rendered once at build time | `server/page/prerendered.gleam` |
| `/app` | A whole page that Lustre takes over in the browser | `server/page/app.gleam`, `shared/todos.gleam` |
| `/islands` | Two small apps inside a server page | `server/page/islands.gleam`, `shared/counter.gleam`, `shared/converter.gleam` |
| `/live` | A server component over a WebSocket, BEAM only | `server/page/live.gleam`, `server/component/clock.gleam` |
| `/data` | Runtime numbers, refreshed from `/api/stats.json` | `server/page/data.gleam`, `shared/stats.gleam` |

## How the client reaches the browser

1. `prebuild` in `server/gleam.toml` runs `gleam run -m lustre/dev build` in
   `client/`. Lustre's build tool bundles the client into
   `server/priv/static/assets/client.js` (set by `[tools.lustre.build]` in
   `client/gleam.toml`) and copies `client/assets` next to it. Then
   `server/prerender` writes `prerendered.html` into the same directory.
2. Pages that need JavaScript use `script: ClientBundle` in
   `server/layout.gleam`, which adds `<script src="/assets/client.js">`.
3. On the BEAM, `server.main` serves `priv/static`. On afterglow, giolt copies
   it to `dist/static` and serves it.
4. In the browser, `client.main` starts what the server put on the page.

The server and client find each other through shared code, not strings:

- An island module such as `shared/counter.gleam` exposes `island()`, which
  holds its name, its props codec and its first view. The server renders it
  with `island.render(counter.island(), id: "counter-1", props: ...)`, and the
  client starts it with `island.hydrate(counter.island(), counter.app())`.
- The todo app's element ids are `todos.root_id` and `todos.state_id`. The
  server renders with `todos.render(state)` and the client reads them back by
  the same names.

`server/priv/` is generated and not committed.

## Deploying

Every push to `main` runs `.github/workflows/deploy.yml`, which runs
`gleam run -m giolt deploy` in `server/`. That builds like `just build` and
uploads `server/dist` to the project set by `project` under `[tools.giolt]` in
`server/gleam.toml`, using the `GIOLT_TOKEN` secret.

## Tests

With `just serve` or `just dev` running:

```sh
just test             # against the BEAM
just test afterglow   # against giolt dev
```

`test/browser.mjs` opens every page in headless Chrome (set `CHROME` if it
isn't at `/usr/bin/google-chrome`). On hydrated pages it checks that Lustre
kept every server-rendered node, then clicks through the islands, the todo
app, the data refresh and the server component. Any console error or failed
request fails the test.

## Things to know

- **Server components don't run on afterglow.** A Worker ends every process
  when the response is sent and can't hold a WebSocket open, so `/live` says
  so instead and `/live/ws` returns 501.
- **Static files come from giolt on afterglow.** afterglow answers a
  `wisp.File` body with 501, so only `server.main` uses `wisp.serve_static`.
- **Floats print differently on Erlang and JavaScript.** The converter formats
  them itself so the server's HTML matches the browser's.
- **Inputs are disabled until hydration**, so early clicks aren't lost, and
  messages set values instead of toggling them, because Lustre replays input
  events when it hydrates.
- **Runtime numbers differ on afterglow.** `/data` shows 1 scheduler and pid
  `<0.0.0>` there.

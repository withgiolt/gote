# gote

Gleam on the Edge: a small multi-page site that shows a full-stack Lustre app
with an Erlang backend. It has server rendering, prerendering, a hydrated
full-page app, client islands, a Lustre server component and a JSON API. Every
page says what it shows and links to the code behind it.

The server code runs in two places:

- on the BEAM with `gleam run`, using mist
- as WebAssembly on [afterglow](https://github.com/withgiolt/afterglow), with
  `giolt dev` or `giolt build`, which is what gets deployed to
  [Giolt](https://giolt.com)

The server component only works on the BEAM. See
[What doesn't work on afterglow](#what-doesnt-work-on-afterglow).

## Layout

```
shared/   no target: views, models and JSON codecs used on both sides
server/   target = "erlang": routes, pages, server component, prerender
client/   target = "javascript": the browser entry that hydrates the page
scripts/  build.mjs (the whole build), client-entry.mjs, dev.sh
test/     browser.mjs (headless Chrome), guards.sh (build guards)
```

`client` and `server` both depend on `shared` by path, and never on each other.
Nothing uses `@target`.

## Pages

| Path | What it shows | Main code |
| --- | --- | --- |
| `/` | Nav and an overview | `server/src/server/pages.gleam` |
| `/ssr` | HTML rendered per request. The handler spawns 8 processes and renders their replies. No JS | `server/src/server/pages.gleam`, `server/src/server/stats.gleam` |
| `/prerendered.html` | HTML rendered once at build time, served as a static file | `server/src/server/prerender.gleam` |
| `/app` | A full page rendered on the server, then hydrated by Lustre, nav included. State travels in an escaped `<script type="application/json">` | `shared/src/shared/todos.gleam` |
| `/islands` | A server page with two islands: a counter and a float converter | `shared/src/shared/counter.gleam`, `shared/src/shared/converter.gleam` |
| `/live` | A Lustre server component over a WebSocket (BEAM only) | `server/src/server/live.gleam` |
| `/data` | Erlang runtime numbers as HTML, plus an island that fetches `/api/stats.json` | `shared/src/shared/stats.gleam` |

The source links on the pages point at `main`.

## Running it

You need Gleam 1.19, Erlang/OTP 28 or 29, rebar3 and Node 22 or newer.

```sh
npm install                 # esbuild, plus puppeteer-core for the browser test
```

On the BEAM, at http://127.0.0.1:8000:

```sh
scripts/dev.sh              # node scripts/build.mjs, then gleam run in server/
```

On afterglow, at http://localhost:3000:

```sh
cd server
gleam run -m giolt dev      # rebuilds on changes in shared, client and server
gleam run -m giolt build    # dist/: app.wasm, index.mjs, host.mjs, static/
```

`giolt` runs `node ../scripts/build.mjs` as its `prebuild`, so the client
bundle, the static files and `prerendered.html` are always rebuilt first.

## Deploying

Every push to `main` runs `.github/workflows/deploy.yml`. It installs OTP,
Gleam, rebar3 and Node, runs `npm ci`, and then runs `gleam run -m giolt deploy`
in `server/`. That builds exactly like `giolt build` (prebuild included) and
uploads `server/dist` to the project set by `project` under `[tools.giolt]` in
`server/gleam.toml`, using the `GIOLT_TOKEN` secret.

## The build

`scripts/build.mjs` does everything in order and stops loudly when something is
off:

1. Deletes the compiled copies of `shared` and `client`, so a module deleted
   from `src/` can't linger and still get bundled.
2. Builds `shared` for Erlang and for JavaScript on its own.
3. Builds `client` and refuses it if it depends on `../server`, any other path
   package, a server-only package (mist, wisp, glisten, …), an Erlang-only
   package, or an `@external` path outside `client/src`.
4. Bundles with esbuild and checks every input comes from `client`, `shared` or
   their Hex dependencies. Only then does it replace the old bundle.
5. Copies `server/assets` and Lustre's server-component runtime to
   `server/priv/static/assets`.
6. Writes `server/src/server/build_info.gleam` and prerenders
   `prerendered.html`.

Every build gets an id, a hash of all its inputs. The server stamps it on
`<html data-build>` and the bundle carries it. If they differ, the client logs
why and doesn't hydrate, instead of quietly swapping fresh server HTML for
stale output. `gleam run` in `server/` runs `node ../scripts/build.mjs check`
first and won't start when the output is older than the sources.

`server/priv/static/` and `build_info.gleam` are generated and not committed,
so build once before running `gleam build` in `server/` by hand.

Other things handled on purpose:

- The embedded state escapes `<`, U+2028 and U+2029, so `</script>` in a todo
  stays text. `/app` has one to prove it.
- Erlang and JavaScript print floats differently, so the converter formats them
  itself, and the server's text matches the browser's.
- Islands are rendered with `element.to_string` and inserted as raw HTML.
  Mapping them with `element.map` adds a `<!-- lustre:map -->` comment the
  client's render doesn't have.
- Buttons and inputs are disabled until hydration, so early clicks aren't lost.
- Input messages set values instead of toggling them, because Lustre replays
  input events on hydration.

## Tests

```sh
BASE=http://127.0.0.1:8000 RUNTIME=beam node test/browser.mjs
BASE=http://localhost:3000 RUNTIME=afterglow node test/browser.mjs
test/guards.sh
```

`test/browser.mjs` opens every page in headless Chrome (set `CHROME` if it isn't
at `/usr/bin/google-chrome`). For each hydrated page it holds the bundle back,
tags every server-rendered node, lets the bundle load and then checks that no
node was replaced, added or removed. It also clicks through the islands, the
todo app, the nav after hydration, the data refresh and the server component,
and it fails on any console error or failed request.

`test/guards.sh` makes the build go wrong on purpose (stale output, a client
FFI path into the server, server packages in the client, a deleted shared
module) and checks each one fails loudly. It undoes its edits on exit.

## What doesn't work on afterglow

- **Server components.** They need a process that lives as long as the browser
  tab, and a WebSocket or a streamed SSE response. An afterglow Worker ends
  every process when the response is sent and can only return a complete
  response. On afterglow, `/live` explains this instead of rendering the
  component, and `/live/ws` returns 501. Lustre's polling transport doesn't
  help either, because the component's state would be gone between polls.
  afterglow's Durable Object mode keeps processes and supports WebSockets, but
  the Hex package and giolt can't build it yet.
- **Static files from Erlang.** afterglow answers a `wisp.File` body with 501,
  so on afterglow giolt serves `dist/static`, and only `main` (BEAM) uses
  `wisp.serve_static`.
- **`.html` URLs on Workers static assets.** Served from `dist/` with
  `wrangler dev` and an `assets` directory, `/prerendered.html` gets a 307 to
  `/prerendered`, which then works. `giolt dev` and the BEAM serve it directly.
- **Runtime numbers differ.** On afterglow `/data` shows 1 scheduler, pid
  `<0.0.0>` and OTP release 29 (from afterglow's runtime, not from the OTP
  that built it).

# gote

A tiny [wisp](https://github.com/gleam-wisp/wisp) + [lustre](https://github.com/lustre-labs/lustre)
app, packed by [afterglow](https://github.com/withgiolt/afterglow) into a WebAssembly module.

## Development

```sh
gleam deps download
gleam build         # compiles for the erlang target
gleam run -m giolt dev
```

## Building the deployable bundle

```sh
gleam run -m giolt build
```

## Examples

- [`examples/fullstack`](examples/fullstack): a multi-page Lustre site with an
  Erlang backend, hydration, client islands and a server component, split into
  shared, server and client packages. It runs on the BEAM and on afterglow.

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

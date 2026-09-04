# gote

A tiny [wisp](https://github.com/gleam-wisp/wisp) + [lustre](https://github.com/lustre-labs/lustre)
app, packed by [glowvm](https://github.com/withgiolt/glowvm) into a WebAssembly
module so it can run on the BEAM (via AtomVM) inside a WASI host.

## Development

```sh
gleam deps download
gleam build         # compiles for the erlang target
```

## Building the deployable bundle

```sh
gleam run -m build
```

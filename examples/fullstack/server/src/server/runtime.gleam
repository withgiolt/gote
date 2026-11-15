//// Which runtime is serving the request. The same router runs on both, but a
//// Worker on afterglow can't hold a WebSocket open or keep a process alive
//// after the response, so the server component page needs to know.

pub type Runtime {
  /// `gleam run` in server/: mist on the BEAM.
  Beam
  /// `giolt build` / `giolt dev`: afterglow, the app compiled to WebAssembly.
  Worker
}

pub fn describe(runtime: Runtime) -> String {
  case runtime {
    Beam -> "the BEAM (mist, `gleam run`)"
    Worker -> "afterglow (WebAssembly, `giolt build` / `giolt dev`)"
  }
}

//// Where the request is being handled. /live needs to know, because a Worker
//// on afterglow can't keep the server component's process or WebSocket open.

pub type Runtime {
  /// mist on the BEAM, started by `server.main`.
  Beam
  /// afterglow, the app compiled to WebAssembly, through `server.handle`.
  Worker
}

pub fn describe(runtime: Runtime) -> String {
  case runtime {
    Beam -> "the BEAM (mist)"
    Worker -> "afterglow (WebAssembly)"
  }
}

//// Build step: renders /prerendered.html into priv/static. scripts/build.mjs
//// runs it with `gleam run -m server/prerender` on the BEAM.

import gleam/io
import server/pages
import simplifile

pub fn main() -> Nil {
  let html = pages.prerendered(built_at(), otp_release())
  let assert Ok(Nil) = simplifile.write("priv/static/prerendered.html", html)
  io.println("wrote priv/static/prerendered.html")
}

@external(erlang, "server_ffi", "timestamp")
fn built_at() -> String

@external(erlang, "server_ffi", "otp_release")
fn otp_release() -> String

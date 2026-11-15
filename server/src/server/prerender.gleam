//// Run during the build (the `prebuild` in gleam.toml) to write
//// priv/static/prerendered.html.

import gleam/io
import server/page/prerendered
import simplifile

pub fn main() -> Nil {
  let html =
    prerendered.render(built_at: built_at(), otp_release: otp_release())
  let assert Ok(Nil) = simplifile.write("priv/static/prerendered.html", html)
  io.println("wrote priv/static/prerendered.html")
}

@external(erlang, "server_ffi", "timestamp")
fn built_at() -> String

@external(erlang, "server_ffi", "otp_release")
fn otp_release() -> String

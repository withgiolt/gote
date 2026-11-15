//// The few DOM reads the entry needs.

pub type Island {
  Island(id: String, name: String, props: String)
}

@external(javascript, "./dom_ffi.mjs", "islands")
pub fn islands() -> List(Island)

@external(javascript, "./dom_ffi.mjs", "text_of")
pub fn text_of(id: String) -> Result(String, Nil)

@external(javascript, "./dom_ffi.mjs", "page_build_id")
pub fn page_build_id() -> String

@external(javascript, "./dom_ffi.mjs", "bundle_build_id")
pub fn bundle_build_id() -> String

@external(javascript, "./dom_ffi.mjs", "console_error")
pub fn console_error(message: String) -> Nil

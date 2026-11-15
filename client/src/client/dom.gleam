//// The few DOM lookups the client needs.

/// `#(id, props)` of every element with `data-island={name}`.
@external(javascript, "./dom_ffi.mjs", "islands_named")
pub fn islands_named(name: String) -> List(#(String, String))

/// The text inside the element with this id.
@external(javascript, "./dom_ffi.mjs", "text_of")
pub fn text_of(id: String) -> Result(String, Nil)

@external(javascript, "./dom_ffi.mjs", "console_error")
pub fn console_error(message: String) -> Nil

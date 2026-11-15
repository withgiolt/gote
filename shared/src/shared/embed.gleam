//// JSON that is safe inside `<script type="application/json">`.
////
//// `<` becomes `\u003c`, so `</script>` and `<!--` can't appear in the
//// output, and U+2028/2029 are escaped too. JSON.parse reads it back as-is.

import gleam/json
import gleam/string

pub fn to_script_json(value: json.Json) -> String {
  json.to_string(value)
  |> string.replace("<", "\\u003c")
  |> string.replace("\u{2028}", "\\u2028")
  |> string.replace("\u{2029}", "\\u2029")
}

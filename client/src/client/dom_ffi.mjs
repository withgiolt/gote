import { Ok, Error, toList } from "../gleam.mjs";

export function islands_named(name) {
  const elements = document.querySelectorAll(`[data-island="${CSS.escape(name)}"]`);
  return toList([...elements].map((el) => [el.id, el.dataset.props ?? "null"]));
}

export function text_of(id) {
  const el = document.getElementById(id);
  return el ? new Ok(el.textContent) : new Error(undefined);
}

export function console_error(message) {
  console.error(message);
}

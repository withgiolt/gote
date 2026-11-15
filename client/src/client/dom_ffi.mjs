import { Ok, Error, toList } from "../gleam.mjs";
import { Island } from "./dom.mjs";

export function islands() {
  const found = [...document.querySelectorAll("[data-island]")].map(
    (el) => new Island(el.id, el.dataset.island, el.dataset.props ?? "null"),
  );
  return toList(found);
}

export function text_of(id) {
  const el = document.getElementById(id);
  return el ? new Ok(el.textContent) : new Error(undefined);
}

export function page_build_id() {
  return document.documentElement.dataset.build ?? "(none)";
}

// scripts/build.mjs replaces __GOTE_BUILD_ID__ with esbuild's --define.
export function bundle_build_id() {
  return typeof __GOTE_BUILD_ID__ === "string" ? __GOTE_BUILD_ID__ : "(unset)";
}

export function console_error(message) {
  console.error(message);
}

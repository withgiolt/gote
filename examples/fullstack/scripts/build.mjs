// The whole build, in order. `giolt build` and `giolt dev` run it as their
// `prebuild`, and `scripts/dev.sh` runs it before `gleam run`.
//
//   node scripts/build.mjs          build everything into server/priv/static
//   node scripts/build.mjs check    exit 1 if that output is older than the sources
//
// 1. Delete compiled copies of shared and client, so a module deleted from
//    src/ can't linger as an orphaned .mjs or .beam and still get bundled.
// 2. Build shared for Erlang and for JavaScript on its own. A consumer only
//    fails where it uses a target-specific function, far from the cause.
// 3. Build client, then refuse it if it depends on anything server-side.
// 4. Bundle with esbuild, then check every bundle input comes from an allowed
//    package. Only then write server/priv/static/assets/client.<id>.js.
// 5. Copy server/assets and Lustre's server-component runtime.
// 6. Write server/src/server/build_info.gleam (bundle path and build id) and
//    prerender prerendered.html.
//
// The build id is a hash of every input. The server stamps it on <html> and
// the bundle carries it, and the client refuses to hydrate when they differ.
import { execFileSync } from "node:child_process";
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const at = (...parts) => path.join(ROOT, ...parts);
const rel = (p) => path.relative(ROOT, p) || ".";
const STATIC = at("server", "priv", "static");
const BUILD_INFO = at("server", "src", "server", "build_info.gleam");
const BUILD_JSON = path.join(STATIC, "build.json");

const say = (msg) => console.log(`[gote] ${msg}`);
const die = (msg) => {
  console.error(`[gote] ERROR: ${msg}`);
  process.exit(1);
};

function run(cmd, args, cwd) {
  try {
    execFileSync(cmd, args, { cwd, stdio: ["ignore", "pipe", "pipe"] });
  } catch (error) {
    process.stderr.write(error.stdout?.toString() ?? "");
    process.stderr.write(error.stderr?.toString() ?? "");
    die(`${cmd} ${args.join(" ")} failed in ${rel(cwd)}`);
  }
}

function walk(dir) {
  if (!fs.existsSync(dir)) return [];
  return fs.readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
    const full = path.join(dir, entry.name);
    return entry.isDirectory() ? walk(full) : [full];
  });
}

// Everything the client bundle, the server's HTML or prerendered.html depend on.
function inputFiles() {
  const files = [
    ...walk(at("shared", "src")),
    ...walk(at("client", "src")),
    ...walk(at("server", "src")).filter((f) => f !== BUILD_INFO),
    ...walk(at("server", "assets")),
    ...["shared/gleam.toml", "client/gleam.toml", "client/manifest.toml", "server/gleam.toml", "server/manifest.toml"]
      .map((f) => at(f))
      .filter((f) => fs.existsSync(f)),
    at("scripts", "build.mjs"),
    at("scripts", "client-entry.mjs"),
  ];
  return files.sort();
}

function inputsId() {
  const hash = crypto.createHash("sha256");
  for (const file of inputFiles()) {
    hash.update(rel(file)).update("\0").update(fs.readFileSync(file)).update("\0");
  }
  return hash.digest("hex").slice(0, 12);
}

function check() {
  const want = inputsId();
  if (!fs.existsSync(BUILD_JSON)) die("no build yet (server/priv/static/build.json is missing); run node scripts/build.mjs");
  const built = JSON.parse(fs.readFileSync(BUILD_JSON, "utf8"));
  if (built.id !== want) die(`STALE: built from inputs ${built.id}, inputs are now ${want}; run node scripts/build.mjs`);
  const info = fs.existsSync(BUILD_INFO) ? fs.readFileSync(BUILD_INFO, "utf8") : "";
  if (!info.includes(`"${want}"`)) die("server/src/server/build_info.gleam is from another build; run node scripts/build.mjs");
  for (const file of [built.bundle, "prerendered.html", "assets/lustre-server-component.min.mjs"]) {
    if (!fs.existsSync(path.join(STATIC, file))) die(`server/priv/static/${file} is missing; run node scripts/build.mjs`);
  }
  say(`fresh (build ${want})`);
}

// Server-only packages, plus this example's own server package. (gleam_erlang
// and gleam_otp are not here: lustre depends on them on every target.)
const SERVER_ONLY = new Set(["server", "mist", "wisp", "glisten", "gramps", "ewe", "elli", "cowboy", "gleam_cowboy", "glen", "sqlight", "pog", "gleam_pgo"]);

function guardDeps() {
  const problems = [];
  const manifest = fs.readFileSync(at("client", "manifest.toml"), "utf8");
  for (const line of manifest.split("\n")) {
    const m = line.match(/^\s*\{\s*name\s*=\s*"([^"]+)".*\bsource\s*=\s*"([^"]+)"(?:.*\bpath\s*=\s*"([^"]+)")?/);
    if (!m) continue;
    const [, name, source, depPath] = m;
    let gleamToml = at("client", "build", "packages", name, "gleam.toml");
    if (source === "local") {
      const dir = path.resolve(at("client"), depPath ?? "");
      gleamToml = path.join(dir, "gleam.toml");
      if (dir !== at("shared")) problems.push(`client depends on path package "${name}" at ${rel(dir)}; only ../shared may be a path dependency`);
    } else if (source !== "hex") {
      problems.push(`client depends on ${source} package "${name}"; only Hex packages and ../shared are allowed`);
    }
    if (SERVER_ONLY.has(name)) problems.push(`client depends on server-only package "${name}"`);
    if (fs.existsSync(gleamToml) && /^target\s*=\s*"erlang"/m.test(fs.readFileSync(gleamToml, "utf8"))) {
      problems.push(`client depends on "${name}", whose gleam.toml says target = "erlang"`);
    }
  }
  // JavaScript FFI paths in client/ and shared/ must stay inside their package.
  for (const pkg of ["client", "shared"]) {
    for (const file of walk(at(pkg, "src")).filter((f) => f.endsWith(".gleam"))) {
      const text = fs.readFileSync(file, "utf8");
      for (const m of text.matchAll(/@external\(\s*javascript\s*,\s*"([^"]+)"/g)) {
        const spec = m[1];
        if (path.isAbsolute(spec)) problems.push(`${rel(file)}: @external path "${spec}" is absolute`);
        else if (spec.startsWith(".") && !path.resolve(path.dirname(file), spec).startsWith(at(pkg, "src") + path.sep)) {
          problems.push(`${rel(file)}: @external path "${spec}" points outside ${pkg}/src`);
        }
      }
    }
  }
  return problems;
}

function guardBundleInputs(meta, allowed) {
  const compiled = at("client", "build", "dev", "javascript");
  return Object.keys(meta.inputs)
    .map((input) => path.resolve(ROOT, input))
    .filter((input) => {
      if (input === at("scripts", "client-entry.mjs")) return false;
      if (input.startsWith(at("node_modules") + path.sep)) return false;
      const pkg = path.relative(compiled, input).split(path.sep)[0];
      return input.startsWith(compiled + path.sep) && allowed.has(pkg) ? false : true;
    })
    .map((input) => `bundle input ${rel(input)} is not from client, shared or their Hex dependencies`);
}

async function build() {
  const started = Date.now();
  // Settle both manifests first: they are inputs to the build id.
  run("gleam", ["deps", "download"], at("client"));
  run("gleam", ["deps", "download"], at("server"));
  const id = inputsId();

  say("1/6 delete compiled shared and client copies");
  for (const dir of [
    "client/build/dev/javascript/client",
    "client/build/dev/javascript/shared",
    "server/build/dev/erlang/shared",
    "server/build/dev/erlang/server",
    "server/build/.giolt/afterglow/build/dev/erlang/shared",
    "server/build/.giolt/afterglow/build/dev/erlang/server",
    "shared/build/dev",
  ]) fs.rmSync(at(dir), { recursive: true, force: true });

  say("2/6 build shared for erlang and javascript");
  run("gleam", ["build", "--target", "erlang"], at("shared"));
  run("gleam", ["build", "--target", "javascript"], at("shared"));

  say("3/6 build client, check its dependencies");
  run("gleam", ["build"], at("client"));
  const problems = guardDeps();
  if (problems.length) {
    for (const p of problems) console.error(`REFUSED: ${p}`);
    die("the client must not depend on server code; the old bundle was kept");
  }

  say("4/6 bundle with esbuild, check every input");
  const esbuild = await import("esbuild");
  const result = await esbuild.build({
    absWorkingDir: ROOT,
    entryPoints: ["scripts/client-entry.mjs"],
    bundle: true,
    minify: true,
    format: "esm",
    target: "es2022",
    write: false,
    metafile: true,
    outfile: "out.js",
    define: { __GOTE_BUILD_ID__: JSON.stringify(id) },
    logLevel: "silent",
  });
  // Gleam's prelude sits at the root of the compiled tree.
  const allowed = new Set(["client", "shared", "gleam.mjs", "prelude.mjs"]);
  for (const line of fs.readFileSync(at("client", "manifest.toml"), "utf8").matchAll(/name\s*=\s*"([^"]+)"/g)) {
    if (!SERVER_ONLY.has(line[1])) allowed.add(line[1]);
  }
  const bad = guardBundleInputs(result.metafile, allowed);
  if (bad.length) {
    for (const p of bad) console.error(`REFUSED: ${p}`);
    die("the bundle pulled in code from outside the client; the old bundle was kept");
  }

  fs.rmSync(STATIC, { recursive: true, force: true });
  fs.mkdirSync(path.join(STATIC, "assets"), { recursive: true });
  const bundle = `assets/client.${id}.js`;
  fs.writeFileSync(path.join(STATIC, bundle), result.outputFiles[0].contents);
  say(`   ${bundle} ${result.outputFiles[0].contents.length} B`);

  say("5/6 copy server/assets and the server component runtime");
  for (const file of walk(at("server", "assets"))) {
    const dest = path.join(STATIC, "assets", path.relative(at("server", "assets"), file));
    fs.mkdirSync(path.dirname(dest), { recursive: true });
    fs.copyFileSync(file, dest);
  }
  fs.copyFileSync(
    at("server", "build", "packages", "lustre", "priv", "static", "lustre-server-component.min.mjs"),
    path.join(STATIC, "assets", "lustre-server-component.min.mjs"),
  );

  say("6/6 write build_info.gleam, prerender prerendered.html");
  const info =
    `//// Generated by scripts/build.mjs. Do not edit; it is not committed.\n\n` +
    `pub const id = "${id}"\n\n` +
    `pub const client_bundle = "/${bundle}"\n`;
  // Only write when it changed: it is in server/src, which `giolt dev`
  // watches, and rewriting it would start the next rebuild in a loop.
  if (!fs.existsSync(BUILD_INFO) || fs.readFileSync(BUILD_INFO, "utf8") !== info) fs.writeFileSync(BUILD_INFO, info);
  run("gleam", ["run", "-m", "server/prerender"], at("server"));
  fs.writeFileSync(BUILD_JSON, JSON.stringify({ id, bundle }, null, 2) + "\n");
  say(`done in ${((Date.now() - started) / 1000).toFixed(1)} s (build ${id})`);
}

if (process.argv[2] === "check") check();
else await build();

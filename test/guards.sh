#!/usr/bin/env bash
# Checks that the build fails loudly in the cases that bit the earlier
# experiments. Every edit is undone on exit, then the build runs once more.
#   test/guards.sh
set -uo pipefail
cd "$(dirname "$0")/.."
backup=$(mktemp -d)
for f in shared/src/shared/site.gleam client/gleam.toml client/manifest.toml; do
  mkdir -p "$backup/$(dirname "$f")" && cp "$f" "$backup/$f"
done
restore() {
  cp -r "$backup"/. .
  rm -f shared/src/shared/orphan.gleam client/src/client/escape.gleam
  node scripts/build.mjs >/dev/null 2>&1 || echo "WARNING: final rebuild failed"
}
trap restore EXIT
pass=0 fail=0
ok() { echo "PASS $1"; pass=$((pass + 1)); }
bad() { echo "FAIL $1"; fail=$((fail + 1)); }

node scripts/build.mjs >/dev/null 2>&1 || { echo "initial build failed"; exit 1; }
bundle=$(ls server/priv/static/assets/client.*.js)

# 1. Stale output: edit shared without rebuilding.
echo '// edited' >> shared/src/shared/site.gleam
out=$(node scripts/build.mjs check 2>&1); rc=$?
[[ $rc -ne 0 && $out == *STALE* ]] && ok "check: STALE after editing shared ($out)" || bad "check after editing shared: rc=$rc $out"
out=$(cd server && timeout 120 gleam run 2>&1); rc=$?
[[ $rc -ne 0 && $out == *STALE* ]] && ok "gleam run refuses to start with a stale bundle (rc=$rc)" || bad "gleam run with stale bundle: rc=$rc"
cp "$backup/shared/src/shared/site.gleam" shared/src/shared/site.gleam

# 2. Client FFI path that reaches into the server.
cat > client/src/client/escape.gleam <<'GLEAM'
@external(javascript, "../../../server/src/server_ffi.mjs", "secret")
pub fn secret() -> String
GLEAM
out=$(node scripts/build.mjs 2>&1); rc=$?
[[ $rc -ne 0 && $out == *REFUSED* ]] && ok "build refuses a client @external path into server/ ($(grep REFUSED <<<"$out" | head -1))" || bad "external path: rc=$rc"
[[ -f $bundle ]] && ok "old bundle kept after the refusal" || bad "old bundle gone after the refusal"
rm client/src/client/escape.gleam

# 3. Client depending on a server-only Hex package.
sed -i 's/^rsvp = .*/&\nwisp = ">= 2.2.2 and < 3.0.0"/' client/gleam.toml
out=$(node scripts/build.mjs 2>&1); rc=$?
[[ $rc -ne 0 ]] && ok "build fails when client depends on wisp ($(grep -m1 -E 'REFUSED|ERROR' <<<"$out"))" || bad "wisp dep: rc=$rc"
cp "$backup/client/gleam.toml" client/gleam.toml; cp "$backup/client/manifest.toml" client/manifest.toml

# 4. Client depending on the server package.
sed -i 's|^shared = .*|&\nserver = { path = "../server" }|' client/gleam.toml
out=$(node scripts/build.mjs 2>&1); rc=$?
[[ $rc -ne 0 ]] && ok "build fails when client depends on ../server ($(grep -m1 -E 'REFUSED|ERROR' <<<"$out"))" || bad "server dep: rc=$rc"
cp "$backup/client/gleam.toml" client/gleam.toml; cp "$backup/client/manifest.toml" client/manifest.toml

# 5. A module deleted from shared must not linger in any compiled copy.
printf 'pub fn orphan() -> String {\n  "orphan"\n}\n' > shared/src/shared/orphan.gleam
node scripts/build.mjs >/dev/null 2>&1
rm shared/src/shared/orphan.gleam
node scripts/build.mjs >/dev/null 2>&1
left=$(find client/build server/build shared/build -path '*shared/orphan*' 2>/dev/null | grep -v '/packages/' | head -3)
[[ -z $left ]] && ok "no orphaned shared/orphan module after deleting it" || bad "orphans left: $left"

echo "$pass passed, $fail failed"
[[ $fail -eq 0 ]]

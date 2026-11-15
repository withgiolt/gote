#!/usr/bin/env bash
# Build, then run the server on the BEAM at http://127.0.0.1:8000.
set -euo pipefail
cd "$(dirname "$0")/.."
node scripts/build.mjs
cd server && exec gleam run

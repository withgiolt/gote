# List the recipes.
default:
    @just --list

# Run on afterglow at http://localhost:3000, rebuilding on changes.
dev:
    cd server && gleam run -m giolt dev

# Build server/dist (the deployable Worker) with afterglow.
build:
    cd server && gleam run -m giolt build

# Build client.js and prerendered.html into server/priv/static (the prebuild in server/gleam.toml).
static:
    cd client && gleam run -m lustre/dev build
    cd server && gleam run -m server/prerender

# Run on the BEAM at http://127.0.0.1:8000.
serve: static
    cd server && gleam run

# Build and upload to Giolt. Needs `giolt login` or GIOLT_TOKEN.
deploy:
    cd server && gleam run -m giolt deploy

# Check formatting and compile all three packages.
check:
    cd shared && gleam format --check src && gleam build
    cd client && gleam format --check src && gleam build
    cd server && gleam format --check src && gleam build

# Headless Chrome test against a running `just serve` (beam) or `just dev` (afterglow).
test runtime="beam":
    cd test && npm install --silent
    BASE={{ if runtime == "beam" { "http://127.0.0.1:8000" } else { "http://localhost:3000" } }} RUNTIME={{ runtime }} node test/browser.mjs

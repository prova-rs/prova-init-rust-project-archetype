local context = Context.new()

-- ── Prompts ─────────────────────────────────────────────────────────────
-- The one fact nothing can derive: the crate name (it lands in Cargo.toml, the binary path the
-- proofs drive, and the README title). Everything else about the shape is fixed — one complete
-- quality surface, no menu of halves.
context:prompt_text("Project name (the crate name — e.g. 'my-app'):", "project_name")
context:prompt_text("One-line description:", "description", { default = "A Rust project, proven by prova" })

-- A Rust-safe identifier for `use <ident>::…` in main.rs: cargo derives the lib target's name by
-- underscoring the package name, so the template needs the same derivation ("my-app" -> "my_app").
local name = tostring(context:get("project_name"))
local ident = name:gsub("%W", "_")
if ident:match("^%d") then
	ident = "_" .. ident
end
context:set("ident", ident)

-- ── Render ──────────────────────────────────────────────────────────────
directory.render("contents", context)

output.print("")
output.print("Rust project created, quality surface driven through prova:")
output.print("  src/                  starter crate — replace with your project")
output.print("  proofs/               black-box proofs + the quality/ut/coverage legs")
output.print("  .prova/               manifest (the profile surface), config, shared lib package")
output.print("  .github/workflows/    CI running the SAME profiles via prova-rs/run-action")
output.print("")
output.print("The bar:")
output.print("  prova                 the black-box suite + fast gates — the inner loop")
output.print("  prova run quality     clippy -D warnings, unwrap/expect census, duplication")
output.print("  prova run ut          unit tests deputed via cargo nextest")
output.print("  prova run coverage    line coverage, ratcheted")
output.print("  prova run all         the pre-push sweep")
output.print("")
output.print("First-run ritual — the ratchets refuse to pass without committed floors, so run")
output.print("these once and commit .prova/baselines/quality.json with the code:")
output.print("  prova run quality --update-baseline")
output.print("  prova run coverage --update-baseline")
output.print("(the establishing pass reports red while it writes the floors; the next run is green)")

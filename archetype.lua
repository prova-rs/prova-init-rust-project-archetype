local context = Context.new()

-- ── Promptless by design ────────────────────────────────────────────────
-- This archetype RETROFITS an existing Rust project — a legacy app you just ran `prova init
-- rust-project` inside, or a tree a parent archetype (rust-grpc-service, …) generated a moment
-- ago and now composes this over. Both callers already own the project's name, README, and
-- description; asking again would be friction in the first case and a blocked headless render in
-- the second. The overlay carries no preconceived notion of the layout either: the proofs read
-- the project's structure at RUNTIME from `cargo metadata`, so a single crate and a many-member
-- workspace get the same gates.

-- ── Detection ───────────────────────────────────────────────────────────
-- Rendering never clobbers: `Existing.Preserve` (the default policy) means the project's own
-- files always win. Detection's job is to notice where that leaves a seam and say so, loudly and
-- actionably, instead of leaving a silently half-wired gate.
local dest = { within = Location.Destination }
local notes = {}

if not file.exists("Cargo.toml", dest) then
	notes[#notes + 1] = "no Cargo.toml here — this archetype retrofits an existing Rust project; "
		.. "the cargo-backed legs will have nothing to hold until one exists"
end

-- (No seam for nextest config, by construction: the ut leg's junit-emitting profile ships in the
-- .prova/ nook and reaches nextest via `--tool-config-file`, composing under — never colliding
-- with — any .config/nextest.toml the project already has.)

-- The .gitignore seam: prova regenerates /.luarc.json with machine-local paths, so it must
-- be ignored — our .gitignore says so, but only lands when the project has none.
if file.exists(".gitignore", dest)
	and not file.read(".gitignore", dest):find(".luarc.json", 1, true) then
	notes[#notes + 1] = ".gitignore already exists (kept) — add a `/.luarc.json` line to it: prova "
		.. "regenerates that file with machine-local paths"
end

-- ── Render ──────────────────────────────────────────────────────────────
directory.render("contents", context)

-- ── Announce ────────────────────────────────────────────────────────────
-- A parent archetype composing this as a library owns its own announcement; stay quiet there
-- beyond the seams that genuinely need a human.
if archetype.is_library() then
	for _, note in ipairs(notes) do
		log.warn("prova init rust-project: " .. note)
	end
	return
end

output.print("")
output.print("Quality surface retrofitted, driven through prova:")
output.print("  proofs/               starter proofs + the quality/ut/coverage legs")
output.print("  .prova/               manifest (the profile surface), config, shared lib package")
output.print("  .github/workflows/    CI running the SAME profiles via prova-rs/run-action")
output.print("")
output.print("The bar:")
output.print("  prova                 build smoke + your black-box proofs — the inner loop")
output.print("  prova run quality     clippy -D warnings, unwrap/expect census, duplication, file sizes")
output.print("  prova run ut          unit tests deputed via cargo nextest")
output.print("  prova run coverage    line coverage, ratcheted")
output.print("  prova run all         the pre-push sweep")
output.print("")
output.print("First-run ritual — the ratchets refuse to pass without committed floors, so run")
output.print("these once and commit .prova/baselines/quality.json with the code:")
output.print("  prova run quality --update-baseline")
output.print("  prova run coverage --update-baseline")
output.print("(the establishing pass reports red while it writes the floors; the next run is green.")
output.print(" On a legacy codebase the floors land wherever the project stands — existing debt")
output.print(" becomes ratcheted standing debt, not a wall of red.)")

if #notes > 0 then
	output.print("")
	output.print("Seams detection found (rendering preserved your files):")
	for _, note in ipairs(notes) do
		output.print("  * " .. note)
	end
end

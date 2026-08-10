-- Quality gate: no Rust source file grows without bound. A big file is where bugs hide and where
-- an agent loses the thread, so oversized files are a red condition that forces a refactor.
--
-- Posture (Mix): a HARD limit for new files; a legacy giant can be GRANDFATHERED — recorded here as
-- known debt so the suite stays green today, but each one carries a graduation check (drops to <=
-- LIMIT -> FAILS demanding delisting) AND a per-file line-count ratchet: growth past the committed
-- baseline is red, every shrink is banked by --update-baseline. Grandfather sparingly, with a
-- paydown note.
--
-- This gate carries NO switch, deliberately: a file scan is cheap, so it runs on every plain
-- `prova` — the fast half of the quality surface rides the inner loop.

local LIMIT = 1500

-- Source trees this gate scans. One crate to start; add each crate's src root as the workspace
-- grows (never target/ or tests).
local SRC_ROOTS = {
	"src",
}

-- Known giants, repo-relative — e.g. ["src/parser.rs"] = true. Empty on a fresh scaffold, and the
-- pressure of this gate is what keeps it that way.
local GRANDFATHERED = {}

-- wc -l semantics: count newlines, so the numbers match a plain `wc -l` and each other.
local function line_count(path)
	local _, n = fs.read(path):gsub("\n", "")
	return n
end

-- fs.glob's base is a concrete dir; "*.rs" catches files directly under it and "**/*.rs" the nested
-- ones. Globbing both and de-duping is robust regardless of whether "**" also matches depth zero.
local function source_files()
	local prefix = prova.root .. "/"
	local seen, out = {}, {}
	for _, root in ipairs(SRC_ROOTS) do
		for _, pat in ipairs({ "*.rs", "**/*.rs" }) do
			for _, path in ipairs(fs.glob(prefix .. root, pat)) do
				if not seen[path] then
					seen[path] = true
					local rel = path:sub(1, #prefix) == prefix and path:sub(#prefix + 1) or path
					out[#out + 1] = { path = path, rel = rel }
				end
			end
		end
	end
	return out
end

prova.test("no source file exceeds " .. LIMIT .. " lines (giants grandfathered, tracked for paydown)", function(t)
	local files = source_files()
	-- Vacuity guard: a broken glob/root would make every assertion below trivially pass.
	t:expect(#files, "no source files scanned — SRC_ROOTS or glob is wrong"):gt(0)

	for _, f in ipairs(files) do
		local n = line_count(f.path)
		if GRANDFATHERED[f.rel] then
			-- Still legitimately a giant. When it finally drops to <= LIMIT this fails, demanding you
			-- remove it from GRANDFATHERED — the graduation / paydown signal.
			t:expect(n, f.rel .. " is now <= " .. LIMIT .. " lines — remove it from GRANDFATHERED (paid down!)"):gt(LIMIT)
		else
			t:expect(n, f.rel .. " is " .. n .. " lines (> " .. LIMIT .. ") — split it, or grandfather it with a paydown note"):never():gt(LIMIT)
		end
	end
end)

prova.test("the grandfathered giants do not grow — each file's line count is ratcheted", { switch = "quality" }, function(t)
	-- The debt, numerically: growth past a giant's committed baseline is red; a shrink is banked
	-- with --update-baseline.
	for rel in pairs(GRANDFATHERED) do
		local metric = "rust.file_lines." .. rel:match("([^/]+)%.rs$")
		measure.ratchet(t, metric, line_count(prova.root .. "/" .. rel), { set = "quality" })
	end
end)

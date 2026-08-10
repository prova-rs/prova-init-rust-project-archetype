-- The proof that `prova init rust-project` produces a *working* Rust project with its quality
-- surface live — not just files on disk: the rendered crate builds and its starter suite runs
-- green, the ratchet ritual establishes floors exactly as documented (red while it writes, green
-- after), the ut leg conducts nextest and adopts the account, and the coverage leg ratchets.
-- Black-box throughout: render into a tempdir, then drive the rendered project's own `prova` and
-- read its report. No white-box peeking at the archetype internals.
--
-- The nested runs use `$PROVA_BIN` if set (so a dev can pin the binary under test), else `prova`
-- on PATH — the version a real user would have installed. The cargo-shaped legs `requires` their
-- tools, so a box without nextest/llvm-cov skips those checks visibly rather than failing.

local ARCHETYPE = prova.root -- this repo *is* the archetype under test
local PROVA = os.getenv("PROVA_BIN") or "prova"

-- One render, shared by every check below. Two prompts (name + description) are the whole
-- interface; a headless render with those answers is what `prova init rust-project` performs.
local rendered = prova.fixture("rendered", Scope.File, function(ctx)
	return archetect.render({
		source = ARCHETYPE,
		answers = { project_name = "acme-app", description = "A test app" },
		destination = ctx:tempdir(),
	})
end)

-- Layout + no un-rendered `{{ }}` markers, via the declarative harness on the existing render.
archetect.verify(rendered, {
	name = "prova-init-rust-project",
	expected_files = {
		"Cargo.toml",
		"clippy.toml",
		".config/nextest.toml",
		"src/main.rs",
		"src/lib.rs",
		"README.md",
		".gitignore",
		".prova/prova.toml",
		".prova/config.lua",
		".prova/packages/lib/init.lua",
		".prova/packages/lib/prova.toml",
		"proofs/cli.prova.lua",
		"proofs/quality/clippy.prova.lua",
		"proofs/quality/unwrap.prova.lua",
		"proofs/quality/file_size.prova.lua",
		"proofs/quality/duplication.prova.lua",
		"proofs/ut/suite.lua",
		"proofs/ut/nextest.prova.lua",
		"proofs/coverage/suite.lua",
		"proofs/coverage/coverage.prova.lua",
		".github/workflows/proofs.yaml",
		".github/workflows/coverage.yaml",
	},
})

-- The CI half of "works out of the box": valid YAML, and every leg wired to run-action with the
-- profile it claims — a `{% raw %}` slip or a renamed action would leave plausible-looking files
-- and the CI silently doing nothing.
prova.test("the generated CI workflows are valid and run the profile legs via run-action", function(t)
	local tree = t:use(rendered)

	local proofs_doc = yaml.decode(fs.read(tree.path .. "/.github/workflows/proofs.yaml"))
	t:expect(proofs_doc.name):equals("Proofs")
	t:expect(proofs_doc.on.pull_request ~= nil, "must run on pull requests"):equals(true)
	t:expect(proofs_doc.on.push.branches):equals({ "main" })

	local profiles = {}
	for _, job in pairs(proofs_doc.jobs) do
		for _, step in ipairs(job.steps) do
			if step.uses and step.uses:find("prova%-rs/run%-action") then
				profiles[step["with"].profile] = true
			end
		end
	end
	for _, want in ipairs({ "ci", "quality", "ut" }) do
		t:expect(profiles[want] ~= nil, "a job runs run-action with profile " .. want):equals(true)
	end

	local cov_doc = yaml.decode(fs.read(tree.path .. "/.github/workflows/coverage.yaml"))
	t:expect(cov_doc.on.schedule ~= nil, "coverage runs on a schedule"):equals(true)

	-- No un-rendered template markers survived the `{% raw %}` wrappers.
	t:expect(fs.read(tree.path .. "/.github/workflows/proofs.yaml")):never():contains("{%")
	t:expect(fs.read(tree.path .. "/.github/workflows/coverage.yaml")):never():contains("{%")
end)

--- Run the rendered project's prova with `argv_tail` appended, in JSON mode, and return the raw
--- result plus the `run_finished` summary event (or nil).
local function run_suite(dir, argv_tail)
	local cmd = PROVA .. " " .. (argv_tail and (argv_tail .. " ") or "") .. "--format json"
	local r = shell.run(cmd, { cwd = dir, timeout = "1800s" })
	local summary
	for line in (r.stdout or ""):gmatch("[^\n]+") do
		local ok, ev = pcall(json.decode, line)
		if ok and type(ev) == "table" and ev.type == "run_finished" then
			summary = ev
		end
	end
	return r, summary
end

--- The committed-floors file of the rendered project, decoded (nil when absent).
local function baselines(tree)
	local path = tree.path .. "/.prova/baselines/quality.json"
	if not fs.exists(path) then
		return nil
	end
	return json.decode(fs.read(path))
end

prova.describe("the rendered project", function()
	-- The load-bearing proof: the scaffolded inner loop passes on its own — the crate builds, the
	-- black-box starter proofs drive the real binary, the fast file-size gate rides along, and the
	-- switched heavy legs hold back rather than fire.
	prova.test("plain `prova` runs green: starter proofs + fast gates, heavy legs held back", {
		requires = { "cargo" },
	}, function(t)
		local tree = t:use(rendered)
		local r, summary = run_suite(tree.path, nil)
		t:expect(r.code, "prova exited non-zero:\n" .. (r.stderr or "")):equals(0)
		t:expect(summary ~= nil, "no run_finished event in prova output"):equals(true)
		t:expect(summary.failed, "the scaffolded suite had failures"):equals(0)
		t:expect(summary.passed >= 3, "expected the two cli proofs plus the file-size gate to pass"):equals(true)
	end)

	-- The documented ritual, held to the letter: the establishing pass is RED while it writes the
	-- floors (a metric with no floor passes nothing — the refusal to green-wash), and the very next
	-- run is the green ratchet. The floors it writes are the scaffold's promise: zero unwraps, zero
	-- expects, zero oversized functions.
	prova.test("the quality ritual establishes zero-debt floors, then the gate holds green", {
		requires = { "cargo" },
	}, function(t)
		local tree = t:use(rendered)

		local establish = run_suite(tree.path, "run quality --update-baseline")
		t:expect(establish.code ~= 0, "the establishing pass must report red while it writes the floors"):equals(true)

		local base = baselines(tree)
		t:expect(base ~= nil, "the ritual wrote .prova/baselines/quality.json"):equals(true)
		for _, metric in ipairs({ "rust.unwrap.production", "rust.expect.production", "rust.functions.too_long" }) do
			local m = base.metrics[metric]
			t:expect(m ~= nil, metric .. " was established"):equals(true)
			t:expect(m.value, metric .. " starts at zero — the scaffold ships no debt"):equals(0)
		end

		local r, summary = run_suite(tree.path, "run quality")
		t:expect(r.code, "prova run quality exited non-zero after the ritual:\n" .. (r.stderr or "")):equals(0)
		t:expect(summary.failed, "the quality gate had failures after the ritual"):equals(0)
	end)

	-- The deputed leg: one nextest conduct, every case adopted, the starter reader bound to
	-- `tests::greets_by_name` — and the junit artifact where the manifest says it lands.
	prova.test("`prova run ut` conducts nextest and adopts the account", {
		requires = { "cargo", "cargo-nextest" },
	}, function(t)
		local tree = t:use(rendered)
		local r, summary = run_suite(tree.path, "run ut")
		t:expect(r.code, "prova run ut exited non-zero:\n" .. (r.stderr or "")):equals(0)
		t:expect(summary.failed, "the ut leg had failures"):equals(0)
		t:expect(fs.exists(tree.path .. "/target/nextest/prova/junit.xml"),
			"the junit artifact landed where .config/nextest.toml declares"):equals(true)
	end)

	-- The coverage ratchet, same ritual shape: establish (red, writes the floor), then hold.
	prova.test("`prova run coverage` establishes its floor, then ratchets green", {
		requires = { "cargo", "cargo-llvm-cov", "cargo-nextest" },
	}, function(t)
		local tree = t:use(rendered)

		local establish = run_suite(tree.path, "run coverage --update-baseline")
		t:expect(establish.code ~= 0, "the establishing pass must report red while it writes the floor"):equals(true)

		local base = baselines(tree)
		local m = base and base.metrics["rust.coverage.lines"]
		t:expect(m ~= nil, "rust.coverage.lines was established"):equals(true)
		t:expect(m.direction):equals("higher_is_better")
		t:expect(m.value > 0, "the starter crate has measurable coverage (its unit test runs)"):equals(true)

		local r, summary = run_suite(tree.path, "run coverage")
		t:expect(r.code, "prova run coverage exited non-zero after the ritual:\n" .. (r.stderr or "")):equals(0)
		t:expect(summary.failed, "the coverage leg had failures after the ritual"):equals(0)
	end)
end)

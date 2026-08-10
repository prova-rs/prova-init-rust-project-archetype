-- The proof that `prova init rust-project` RETROFITS a working quality surface onto an existing
-- Rust project — promptless, layout-agnostic, and safe over the project's own files. Black-box
-- throughout: build a host project in a tempdir, render the archetype over it exactly as
-- `prova init` would (headless, no answers — promptlessness is itself under proof), then drive
-- the retrofitted project's own `prova` and read its report.
--
-- Two hosts, two claims:
--   * a LEGACY single-crate app with real debt (a production .unwrap(), an oversized file, its
--     own README and .gitignore) — the retrofit preserves what the project owns, and the ritual
--     turns the existing debt into ratcheted floors instead of a wall of red;
--   * a WORKSPACE with two members and its own .config/nextest.toml — the gates discover every
--     member's source at runtime, and the ut leg's junit profile composes as nextest TOOL config
--     without touching the project's.
--
-- The nested runs use `$PROVA_BIN` if set (so a dev can pin the binary under test), else `prova`
-- on PATH — the version a real user would have installed.

local ARCHETYPE = prova.root -- this repo *is* the archetype under test
local PROVA = os.getenv("PROVA_BIN") or "prova"

-- ── The legacy-app host ─────────────────────────────────────────────────

local HOST_README = "# legacy-app\n\nThe project's own README — a retrofit must never touch it.\n"
local HOST_GITIGNORE = "/target\n"

--- Distinct filler lines, so the oversized file doesn't also read as one giant jscpd clone.
local function filler(lines)
	local out = {}
	for i = 1, lines do
		out[i] = "// filler line " .. i
	end
	return table.concat(out, "\n") .. "\n"
end

local app = prova.fixture("legacy-app", Scope.File, function(ctx)
	local dir = ctx:tempdir()
	fs.mkdir(dir .. "/src")
	fs.write(dir .. "/README.md", HOST_README)
	fs.write(dir .. "/.gitignore", HOST_GITIGNORE)
	fs.write(dir .. "/Cargo.toml", table.concat({
		"[package]",
		'name = "legacy-app"',
		'version = "0.1.0"',
		'edition = "2021"',
		"",
		"[dependencies]",
		"",
	}, "\n"))
	fs.write(dir .. "/src/lib.rs", table.concat({
		"pub fn greeting(name: &str) -> String {",
		'    format!("hello, {name}")',
		"}",
		"",
		"#[cfg(test)]",
		"mod tests {",
		"    #[test]",
		"    fn greets() {",
		'        assert_eq!(super::greeting("prova"), "hello, prova");',
		"    }",
		"}",
		"",
	}, "\n"))
	-- The debt the ritual must absorb: one production .unwrap() (the census floor lands at 1,
	-- not 0), and one file past the 1500-line limit (the oversized floor lands at 1).
	fs.write(dir .. "/src/main.rs", table.concat({
		"fn main() {",
		"    let name = std::env::args().nth(1).unwrap();",
		"    println!(\"{}\", legacy_app::greeting(&name));",
		"}",
		"",
	}, "\n"))
	fs.write(dir .. "/src/big.rs", filler(1600))

	return archetect.render({
		source = ARCHETYPE,
		destination = dir, -- rendered OVER the host, exactly as `prova init` runs in a project
	})
end)

-- Layout + no un-rendered `{{ }}` markers, via the declarative harness on the existing render.
archetect.verify(app, {
	name = "rust-project-retrofit",
	expected_files = {
		"clippy.toml",
		".prova/prova.toml",
		".prova/config.lua",
		".prova/nextest.toml",
		".prova/README.md",
		".prova/packages/lib/init.lua",
		".prova/packages/lib/prova.toml",
		"proofs/blackbox.prova.lua",
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

prova.test("the project's own files survive the render untouched", function(t)
	local tree = t:use(app)
	t:expect(fs.read(tree.path .. "/README.md"), "README.md is the project's, never ours"):equals(HOST_README)
	t:expect(fs.read(tree.path .. "/.gitignore"), ".gitignore is preserved, not merged"):equals(HOST_GITIGNORE)
end)

-- The CI half of "works out of the box": valid YAML, and every leg wired to run-action with the
-- profile it claims — a `{% raw %}` slip or a renamed action would leave plausible-looking files
-- and the CI silently doing nothing.
prova.test("the generated CI workflows are valid and run the profile legs via run-action", function(t)
	local tree = t:use(app)

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

--- Run the retrofitted project's prova with `argv_tail` appended, in JSON mode, and return the
--- raw result plus the `run_finished` summary event (or nil).
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

--- The committed-floors file of a retrofitted project, decoded (nil when absent).
local function baselines(tree)
	local path = tree.path .. "/.prova/baselines/quality.json"
	if not fs.exists(path) then
		return nil
	end
	return json.decode(fs.read(path))
end

prova.describe("the retrofitted legacy app", function()
	-- Zero friction, immediately: plain `prova` is green on a project the retrofit knows nothing
	-- about — the build smoke passes, and the placeholder reports as PROMISED (green by design,
	-- visible in `prova owed`), never as a failure.
	prova.test("plain `prova` runs green: build smoke passes, the black-box placeholder is PROMISED", {
		requires = { "cargo" },
	}, function(t)
		local tree = t:use(app)
		local r, summary = run_suite(tree.path, nil)
		t:expect(r.code, "prova exited non-zero:\n" .. (r.stderr or "")):equals(0)
		t:expect(summary ~= nil, "no run_finished event in prova output"):equals(true)
		t:expect(summary.failed, "the retrofitted suite had failures"):equals(0)
		t:expect(summary.passed >= 1, "the build smoke passes"):equals(true)
		t:expect(summary.promised, "the placeholder reports as PROMISED, not red"):equals(1)
	end)

	-- The retrofit-on-legacy claim, held to the letter: the establishing pass is RED while it
	-- writes the floors, and the floors land where the project STANDS — the pre-existing
	-- .unwrap() and the 1600-line file become ratcheted standing debt (1 and 1), not a wall of
	-- red. The very next run is the green ratchet.
	prova.test("the quality ritual absorbs existing debt into floors, then the gate holds green", {
		requires = { "cargo" },
	}, function(t)
		local tree = t:use(app)

		local establish = run_suite(tree.path, "run quality --update-baseline")
		t:expect(establish.code ~= 0, "the establishing pass must report red while it writes the floors"):equals(true)

		local base = baselines(tree)
		t:expect(base ~= nil, "the ritual wrote .prova/baselines/quality.json"):equals(true)
		local floors = {
			["rust.unwrap.production"] = 1, -- the legacy .unwrap() in main.rs, counted honestly
			["rust.expect.production"] = 0,
			["rust.functions.too_long"] = 0,
			["rust.files.oversized"] = 1, -- src/big.rs, absorbed as standing debt
		}
		for metric, want in pairs(floors) do
			local m = base.metrics[metric]
			t:expect(m ~= nil, metric .. " was established"):equals(true)
			t:expect(m.value, metric .. " floor lands where the project stands"):equals(want)
		end

		local r, summary = run_suite(tree.path, "run quality")
		t:expect(r.code, "prova run quality exited non-zero after the ritual:\n" .. (r.stderr or "")):equals(0)
		t:expect(summary.failed, "the quality gate had failures after the ritual"):equals(0)
	end)

	-- The deputed leg: one nextest conduct, every case adopted — and the junit artifact where the
	-- nook's tool config says it lands.
	prova.test("`prova run ut` conducts nextest and adopts the account", {
		requires = { "cargo", "cargo-nextest" },
	}, function(t)
		local tree = t:use(app)
		local r, summary = run_suite(tree.path, "run ut")
		t:expect(r.code, "prova run ut exited non-zero:\n" .. (r.stderr or "")):equals(0)
		t:expect(summary.failed, "the ut leg had failures"):equals(0)
		t:expect(fs.exists(tree.path .. "/target/nextest/prova/junit.xml"),
			"the junit artifact landed where .prova/nextest.toml declares"):equals(true)
	end)

	-- The coverage ratchet, same ritual shape: establish (red, writes the floor), then hold.
	prova.test("`prova run coverage` establishes its floor, then ratchets green", {
		requires = { "cargo", "cargo-llvm-cov", "cargo-nextest" },
	}, function(t)
		local tree = t:use(app)

		local establish = run_suite(tree.path, "run coverage --update-baseline")
		t:expect(establish.code ~= 0, "the establishing pass must report red while it writes the floor"):equals(true)

		local base = baselines(tree)
		local m = base and base.metrics["rust.coverage.lines"]
		t:expect(m ~= nil, "rust.coverage.lines was established"):equals(true)
		t:expect(m.direction):equals("higher_is_better")
		t:expect(m.value > 0, "the host's unit test produces measurable coverage"):equals(true)

		local r, summary = run_suite(tree.path, "run coverage")
		t:expect(r.code, "prova run coverage exited non-zero after the ritual:\n" .. (r.stderr or "")):equals(0)
		t:expect(summary.failed, "the coverage leg had failures after the ritual"):equals(0)
	end)
end)

-- ── The workspace host ──────────────────────────────────────────────────

local HOST_NEXTEST = "# the project's own nextest config — the retrofit must not touch it\n"
	.. "[profile.default]\nretries = 0\n"

local workspace = prova.fixture("workspace-host", Scope.File, function(ctx)
	local dir = ctx:tempdir()
	fs.write(dir .. "/Cargo.toml", '[workspace]\nresolver = "2"\nmembers = ["alpha", "beta"]\n')
	fs.mkdir(dir .. "/.config")
	fs.write(dir .. "/.config/nextest.toml", HOST_NEXTEST)

	fs.mkdir(dir .. "/alpha/src")
	fs.write(dir .. "/alpha/Cargo.toml",
		'[package]\nname = "alpha"\nversion = "0.1.0"\nedition = "2021"\n\n[dependencies]\n')
	fs.write(dir .. "/alpha/src/lib.rs", table.concat({
		"pub fn add(a: i64, b: i64) -> i64 {",
		"    a + b",
		"}",
		"",
		"#[cfg(test)]",
		"mod tests {",
		"    #[test]",
		"    fn adds() {",
		"        assert_eq!(super::add(2, 2), 4);",
		"    }",
		"}",
		"",
	}, "\n"))

	fs.mkdir(dir .. "/beta/src")
	fs.write(dir .. "/beta/Cargo.toml",
		'[package]\nname = "beta"\nversion = "0.1.0"\nedition = "2021"\n\n[dependencies]\n')
	fs.write(dir .. "/beta/src/lib.rs", "pub fn noop() {}\n")
	-- Oversized debt in the SECOND member: the file-size floor landing at 1 proves discovery
	-- reached beta/src through cargo metadata, not through an assumed src/ at the root.
	fs.write(dir .. "/beta/src/big.rs", filler(1600))

	return archetect.render({
		source = ARCHETYPE,
		destination = dir,
	})
end)

prova.describe("the retrofitted workspace", function()
	prova.test("the project's own nextest config is preserved, byte for byte", function(t)
		local tree = t:use(workspace)
		t:expect(fs.read(tree.path .. "/.config/nextest.toml")):equals(HOST_NEXTEST)
	end)

	-- Layout-agnosticism, proven: the gates found BOTH members' src roots via cargo metadata —
	-- the oversized file hiding in beta/ lands in the floor.
	prova.test("the quality gates discover every workspace member's source", {
		requires = { "cargo" },
	}, function(t)
		local tree = t:use(workspace)
		local establish = run_suite(tree.path, "run quality --update-baseline")
		t:expect(establish.code ~= 0, "the establishing pass must report red while it writes the floors"):equals(true)

		local base = baselines(tree)
		t:expect(base ~= nil, "the ritual wrote .prova/baselines/quality.json"):equals(true)
		t:expect(base.metrics["rust.files.oversized"].value,
			"beta/src/big.rs was found through metadata discovery"):equals(1)
		t:expect(base.metrics["rust.unwrap.production"].value):equals(0)
	end)

	-- The composition claim from the nextest seam: the ut leg works WITHOUT touching the
	-- project's own .config/nextest.toml, because the junit profile rides in as tool config.
	prova.test("`prova run ut` adopts the account despite the project's own nextest config", {
		requires = { "cargo", "cargo-nextest" },
	}, function(t)
		local tree = t:use(workspace)
		local r, summary = run_suite(tree.path, "run ut")
		t:expect(r.code, "prova run ut exited non-zero:\n" .. (r.stderr or "")):equals(0)
		t:expect(summary.failed, "the ut leg had failures"):equals(0)
		t:expect(fs.exists(tree.path .. "/target/nextest/prova/junit.xml"),
			"the junit artifact landed at the tool-config profile's path"):equals(true)
	end)
end)

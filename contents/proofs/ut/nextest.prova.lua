--- The deputed unit-test leg: `prova run ut` conducts cargo nextest ONCE for the whole workspace —
--- compilation and execution both live in a file-scoped fixture that emits one junit artifact —
--- then one proof adopts every case into the account, and sibling readers bind claims to named
--- cases at zero additional compilations (conduct once, read many).
---
--- The `ut` switch (suite.lua) is intent; `cargo-nextest` stays a `requires` world fact: two facts
--- with two remedies. The profile `must_run`s the deputy, so `prova run ut` fails rather than
--- skips when nextest is missing — a profile is a contract, not a courtesy.

-- Conduct the deputy once. The stale artifact is removed FIRST, so a deputy that dies before
-- emitting (a compile error) leaves nothing behind and the adoption fails loudly on "matched
-- nothing" — never a previous run's verdicts wearing this run's face. The deputy's exit code is
-- deliberately not asserted here: the adopting proof reports red with the deputed cases' own
-- names, which a fixture death would hide.
local deputy = prova.fixture("nextest-junit", Scope.File, function()
	local artifact = prova.root .. "/target/nextest/prova/junit.xml"
	fs.remove_all(artifact)
	shell.run(
		{ "cargo", "nextest", "run", "--workspace", "--profile", "prova" },
		{ cwd = prova.root, merge_stderr = true, timeout = "900s" }
	)
	return artifact
end)

prova.test("the workspace's unit-test account holds — every nextest case adopted", {
	requires = { "cargo-nextest" },
}, function(t)
	junit.verify(t, { results = t:use(deputy) })
end)

-- Readers: one claim, one named unit test — a prose claim discharged by a specific case in the
-- deputy's own account, without a second run. This starter reader binds the scaffold's own unit
-- test; as your suite grows, add a reader per claim that a specific unit test carries.
local function case(report, name)
	for _, c in ipairs(report.cases) do
		if c.name == name then
			return c
		end
	end
end

prova.test("the greeting contract is spoken for by its unit test", {
	requires = { "cargo-nextest" },
}, function(t)
	local report = junit.load(t:use(deputy))
	local c = case(report, "tests::greets_by_name")
	t:expect(c ~= nil, "tests::greets_by_name exists in the deputed account"):is_true()
	t:expect(c.outcome, "tests::greets_by_name"):equals("passed")
end)

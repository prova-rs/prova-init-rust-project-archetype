-- Quality gate: clippy is clean at -D warnings across the whole workspace — findings as a red
-- condition, one runner, one wall.
--
-- HEAVY: clippy recompiles the workspace, so this must never fire because a person typed `prova`.
-- It sits behind the `quality` switch — off unless thrown. `prova run quality` throws it;
-- `prova -s quality` is the ad-hoc door. Plain local runs hold it back, reported on the
-- switched-off summary line.

prova.test("clippy is clean (-D warnings, whole workspace)", { switch = "quality" }, function(t)
	local r = shell.run(
		{ "cargo", "clippy", "--workspace", "--all-targets", "--all-features", "--", "-D", "warnings" },
		{ cwd = prova.root, merge_stderr = true }
	)
	t:expect(r.code, "clippy reported warnings or errors:\n" .. (r.stdout or "")):equals(0)
end)

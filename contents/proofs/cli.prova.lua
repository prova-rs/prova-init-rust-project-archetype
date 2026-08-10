-- Starter black-box proofs: build the real binary (once, via the shared `lib.app` fixture), run it
-- exactly as a user would, and assert on what it does. This is the suite `prova` runs on every
-- inner-loop pass — replace these with proofs of your project's actual behavior and keep the shape:
-- black-box, through the artifact, never through the internals.

local lib = require("lib") -- the project's shared library package (.prova/packages/lib)

prova.test("the binary greets the world by default", { requires = { "cargo" } }, function(t)
	local r = shell.run({ t:use(lib.app) })
	t:expect(r.code, "the binary exited non-zero:\n" .. (r.stderr or "")):equals(0)
	t:expect(r.stdout):contains("hello, world")
end)

prova.test("the binary greets a named caller", { requires = { "cargo" } }, function(t)
	local r = shell.run({ t:use(lib.app), "prova" })
	t:expect(r.stdout):contains("hello, prova")
end)

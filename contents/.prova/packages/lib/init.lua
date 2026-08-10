-- The project's shared library package. Anything reused across proof suites — helpers, shared
-- fixtures, topologies — lives here, and `require("lib")` reaches it from any proof.

local lib = {}

--- The built binary, as a shared fixture: one `cargo build` per proof file that asks, and every
--- black-box proof drives the SAME artifact a user would run. Grow this into your project's real
--- boot surface (build + start a server, hand back its address, defer the shutdown).
lib.app = prova.fixture("app.binary", Scope.File, function()
	local r = shell.run({ "cargo", "build" }, { cwd = prova.root, merge_stderr = true, timeout = "600s" })
	if r.code ~= 0 then
		error("cargo build failed:\n" .. (r.stdout or ""))
	end
	return prova.root .. "/target/debug/{{ project_name }}"
end)

return lib

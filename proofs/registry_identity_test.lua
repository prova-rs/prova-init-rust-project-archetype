--- The archetype's REGISTRY IDENTITY, held locally.
---
--- Registration into a prova package-registry is automated and credential-free: a reconcile loop
--- converges the registry onto the org's repos, and each repo dispatches on `release: published` for
--- latency. Both paths derive this archetype's `archetypes/<init_key>.toml` entry from the fields
--- declared in `archetype.yaml` — and both paths SKIP a repo that declares no `prova.init_key`, the
--- same way they skip a repo with no `[package]` manifest.
---
--- A skip is silent by design (most org repos are not archetypes), which is exactly the hazard: drop
--- or typo the declaration and this archetype quietly stops being registrable, with nothing red
--- anywhere. This proof is the local tripwire — the failure lands here, in the repo that owns the
--- declaration, instead of as an absence nobody notices in a registry.
---
--- It deliberately asserts only what the ENTRY is projected from. Whether `prova init rust-project`
--- then resolves that key is prova's business, proven in its own suite
--- (`proofs/spec/registry/archetypes_test.lua`).

local manifest = yaml.decode(fs.read(prova.root .. "/archetype.yaml"))

prova.test("archetype.yaml declares the registry identity a registration derives from", function(t)
  local prova_block = manifest.prova
  t:expect(prova_block ~= nil, "archetype.yaml must carry a `prova:` block"):is_true()

  -- The key is the one field nothing can derive: prova resolves `prova init <key>` through the
  -- registry rather than inferring a repo name from it, so the archetype has to state it.
  t:expect(prova_block.init_key, "prova.init_key names the `prova init <key>` key"):equals("rust-project")

  -- Publisher policy: this archetype CREATES a package, so rendering it over an existing manifest is
  -- an error. `allow` here would silently let `prova init rust-project` scaffold into an initialized
  -- package and clobber it.
  t:expect(prova_block.in_package):equals("deny")
end)

prova.test("the declared identity is well-formed for a registry entry", function(t)
  local prova_block = manifest.prova or {}

  -- `in_package` must be a value prova's resolver understands. An unknown string degrades to "deny"
  -- there rather than raising, so a typo would be invisible at render time — catch it here.
  local valid = prova_block.in_package == "deny" or prova_block.in_package == "allow"
  t:expect(valid, "in_package must be exactly \"deny\" or \"allow\", got "
    .. tostring(prova_block.in_package)):is_true()

  -- The key becomes a filename (`archetypes/<key>.toml`) and a CLI argument, so it has to survive
  -- both: no spaces, no path separators, no shell metacharacters.
  local key = tostring(prova_block.init_key or "")
  t:expect(#key > 0, "init_key must not be empty"):is_true()
  t:expect(key:match("^[a-z0-9][a-z0-9%-_]*$") ~= nil,
    "init_key must be lowercase alphanumeric with - or _, got " .. key):is_true()

  -- `description` is the entry's description; an empty one fails registration at derive time, which
  -- is a worse place to find out than here.
  local description = tostring(manifest.description or "")
  t:expect(#description > 0, "archetype.yaml needs a description — the entry projects it"):is_true()
end)

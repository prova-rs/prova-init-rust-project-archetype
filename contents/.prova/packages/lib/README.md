# `lib` — the project's shared library package

Shared code for your proof suites: helpers, fixtures, and topologies that more than one suite needs.
`require("lib")` reaches it from any proof (the directory name here is the `require()` name).

- `init.lua` — the module. `lib.app` is the starter fixture: it `cargo build`s once per proof file
  and returns the binary's path, so black-box proofs drive the real artifact. Replace it with your
  project's real boot surface as it grows.
- `prova.toml` — the package's `[package]` section (name, and private `[dependencies]`). It's the
  same manifest a project uses: a package is a package, so `lib/` can grow its own `proofs/` to
  prove itself.

A multi-file library can `require("lib.<sub>")` its own siblings placed next to `init.lua`.

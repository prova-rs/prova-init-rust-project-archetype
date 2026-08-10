# prova-init-rust-project-archetype

An [Archetect](https://github.com/archetect/archetect) archetype that scaffolds a **Rust project
with its whole quality surface driven through [Prova](https://github.com/prova-rs/prova)** — the
setup prova's own repository runs on itself, distilled into a bootstrap: black-box proofs of the
real binary, the clippy wall, unwrap/expect and duplication ratchets, unit tests deputed through
cargo nextest, and ratcheted line coverage. One runner, one exit code, identical locally and in CI.

It's wired into prova's `prova init` catalog, so the usual way to use it is:

```bash
prova init rust-project
```

(or `archetect render https://github.com/prova-rs/prova-init-rust-project-archetype.git#v1`
directly). Its sibling is
[`prova-init-project-archetype`](https://github.com/prova-rs/prova-init-project-archetype) — the
language-agnostic package shape, without the Rust quality legs.

## Prompts

Two: the **project name** (the crate name — it lands in Cargo.toml, the binary path the proofs
drive, and the README title) and a one-line **description**. Everything else about the shape is
fixed — one complete quality surface, no menu of halves.

## What it generates

```
<project>/
├── Cargo.toml                  the crate; src/ is a starter (lib + bin) — replace with your project
├── clippy.toml                 function-size threshold for the too_many_lines census
├── .config/nextest.toml        the `prova` nextest profile — junit for the deputed ut leg
├── .gitignore                  ignores /target and /.luarc.json (the machine-local editor pointer)
├── README.md                   documents the bar and the first-run ritual
├── .github/workflows/
│   ├── proofs.yaml             CI legs: black-box suite (ci), quality gates, unit tests
│   └── coverage.yaml           nightly + on-demand coverage ratchet
├── proofs/
│   ├── cli.prova.lua           starter black-box proofs — build once, drive the real binary
│   ├── quality/                clippy -D warnings · unwrap/expect census · duplication · file sizes
│   ├── ut/                     cargo nextest conducted ONCE, every case adopted, claims bound by name
│   └── coverage/               cargo llvm-cov nextest, line % ratcheted
└── .prova/                     the nook: prova's own files, out of the way
    ├── prova.toml              the manifest — the profile surface (quality/ut/coverage/all/ci)
    ├── config.lua              the runtime companion — where capabilities are registered
    └── packages/lib/           the shared library — owns the `lib.app` built-binary fixture
```

The bar, as rendered:

```bash
prova                    # the black-box suite + the fast gates (file sizes) — the inner loop
prova run quality        # clippy -D warnings, unwrap/expect census, duplication — ratcheted
prova run ut             # unit tests, conducted once via cargo nextest, adopted into the account
prova run coverage       # line coverage, ratcheted against the committed baseline
prova run all            # the pre-push sweep: proofs + ut + quality, one exit code
```

The heavy legs sit behind switches (they recompile the workspace), thrown by their profiles —
`prova` stays a fast inner loop. Tools are `requires` world facts locally (a missing jscpd skips
its gate, visibly) and `must_run` promises in the profiles CI runs (a runner that lost its
toolchain fails loudly instead of green-washing a wall of skips).

**The first-run ritual:** the ratchets refuse to pass without committed floors, so once, then
commit `.prova/baselines/quality.json` with the code:

```bash
prova run quality --update-baseline
prova run coverage --update-baseline
```

The establishing pass reports red while it writes the floors (a metric with no floor passes
nothing); the run after it is the green ratchet. The scaffold's floors start at zero debt — zero
unwraps, zero expects, zero oversized functions — which is the whole point of bootstrapping the
surface on day one instead of retrofitting it later.

## Testing locally

The archetype carries its own black-box proof suite: render into a tempdir, then run the *rendered*
project's `prova` — the starter suite, the quality ritual, the ut leg, the coverage leg — so "it
generated files" is never mistaken for "it works".

```sh
prova                             # the archetype's own proofs (needs cargo; nextest/llvm-cov/jscpd
                                  # gate their legs via requires and skip visibly when absent)
PROVA_BIN=/path/to/prova prova    # pin the binary under test
```

While iterating before cutting a `v1` tag, render against the local working copy with `--local`:

```sh
archetect render --local <git-url> --dest /tmp/out
```

## Release versioning

Releases are automated by the
[`archetect-actions/repository-release`](https://github.com/archetect-actions/repository-release)
action under `.github/workflows/`. Consumers reference a specific version by suffixing the git URL
with `#v1` (or `#v1.3`, etc.) — which is how prova's catalog pins it, so scaffolding doesn't drift
when `main` moves.

## Author

Jimmie Fulton <jimmie.fulton@gmail.com>

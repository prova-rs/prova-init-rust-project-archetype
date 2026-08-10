# prova-init-rust-project-archetype

An [Archetect](https://github.com/archetect/archetect) archetype that **retrofits an existing Rust
project with a quality surface driven through [Prova](https://github.com/prova-rs/prova)** — the
setup prova's own repository runs on itself, distilled into an overlay: the clippy wall,
unwrap/expect and duplication and file-size ratchets, unit tests deputed through cargo nextest,
and ratcheted line coverage. One runner, one exit code, identical locally and in CI.

It's wired into prova's `prova init` catalog, so the usual way to use it is: walk into any Rust
project and

```bash
prova init rust-project
```

— and, with zero friction, the project has sophisticated quality gating. The other intended
caller is a **parent archetype** (a `rust-grpc-service-archetype`, say) composing this over a
tree it just generated: the render is promptless, so a parent can drive it headlessly and keep
owning its own prompts, README, and announcement.

## Promptless, layout-agnostic, safe over existing files

- **No prompts.** Both callers already own the project's name and description; there is nothing
  this overlay needs to ask.
- **No preconceived layout.** The gates read the project's structure at *runtime* from
  `cargo metadata` (via the rendered `lib` package) — a single crate and a many-member workspace
  get the same gates with zero configuration.
- **The project's files always win.** Rendering uses the preserve-on-collision policy, so an
  existing README, `.gitignore`, `clippy.toml`, or `.config/nextest.toml` is never touched. The
  pieces the suite *depends on* live in the `.prova/` nook, which is collision-free by
  construction (`in_package: deny` refuses to render into a project that already has one). In
  particular the ut leg's junit-emitting nextest profile ships at `.prova/nextest.toml` and
  reaches nextest as `--tool-config-file` **tool config**, composing under — never competing
  with — the project's own nextest configuration.
- **Detection, not assumption.** At render time the archetype inspects the destination and calls
  out real seams (no `Cargo.toml` in sight; a `.gitignore` that doesn't ignore the machine-local
  `/.luarc.json`) instead of silently rendering into them.

## What it renders

```
<project>/                      ← your existing project, untouched where it has opinions
├── clippy.toml                 function-size threshold (lands only if absent; clippy's default matches)
├── .github/workflows/
│   ├── proofs.yaml             CI legs: black-box suite (ci), quality gates, unit tests
│   └── coverage.yaml           nightly + on-demand coverage ratchet
├── proofs/
│   ├── blackbox.prova.lua      build smoke + a PROMISED placeholder for real black-box proofs
│   ├── quality/                clippy -D warnings · unwrap/expect census · duplication · file sizes
│   ├── ut/                     cargo nextest conducted ONCE, every case adopted, claims bound by name
│   └── coverage/               cargo llvm-cov nextest, line % ratcheted
└── .prova/                     the nook: prova's own files, out of the way
    ├── prova.toml              the manifest — the profile surface (quality/ut/coverage/all/ci)
    ├── nextest.toml            the junit-emitting `prova` profile, handed to nextest as tool config
    ├── README.md               documents the bar and the first-run ritual
    ├── config.lua              the runtime companion — where capabilities are registered
    └── packages/lib/           shared proof code: cargo-metadata discovery, build/bin helpers
```

The bar, as rendered:

```bash
prova                    # build smoke + your black-box proofs — the inner loop
prova run quality        # clippy -D warnings, unwrap/expect census, duplication, file sizes
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
nothing); the run after it is the green ratchet. **On a legacy codebase the floors land wherever
the project stands** — the existing unwraps, giants, and clones become ratcheted standing debt to
pay down, not a wall of red to bypass. From then on quality only moves one way: regressions are
red, improvements are banked with `--update-baseline` (which refuses to loosen), and a `goal` in
the baseline file schedules a paydown.

## Prompts

**None.** Promptlessness is itself held under proof (`proofs/render_test.lua` renders headlessly
with no answers), so if a prompt is ever added, the headless render starts failing and the
interface change becomes visible rather than silent.

## Testing locally

The archetype carries its own black-box proof suite: build host projects in tempdirs (a legacy
single-crate app with real debt; a workspace with its own nextest config), render the archetype
over them, then run the *retrofitted* projects' `prova` through every leg — so "it generated
files" is never mistaken for "it works".

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

# {{ project_name }}

{{ description }}

The quality surface here is driven through [prova](https://github.com/prova-rs/prova): black-box
proofs of behavior plus ratcheted quality gates, one runner, one exit code — the same command
locally and in CI.

## The bar

```bash
prova                    # the black-box suite + the fast gates (file sizes) — the inner loop
prova --last-failed      # re-run only what's red
prova run quality        # clippy -D warnings, unwrap/expect census, duplication — ratcheted
prova run ut             # unit tests, conducted once via cargo nextest, adopted into the account
prova run coverage       # line coverage, ratcheted against the committed baseline
prova run all            # the pre-push sweep: proofs + ut + quality, one exit code
```

Proofs live in `proofs/` (`*.prova.lua` — Lua, black-box, through the built binary via the shared
`lib.app` fixture). The manifest and its profile surface live in `.prova/prova.toml`; shared proof
code lives in `.prova/packages/lib/`.

## First-run ritual (once)

The ratchets — unwrap/expect counts, duplication, coverage — refuse to pass without a committed
floor. Establish the floors, then commit `.prova/baselines/quality.json` with the code:

```bash
prova run quality --update-baseline
prova run coverage --update-baseline
```

The establishing pass itself reports red (a metric with no floor passes nothing — that's the
refusal to green-wash) while it writes the floors; the run after it is the green ratchet.

From then on: a regression past a floor is red; an improvement is banked by re-running with
`--update-baseline` (which refuses to loosen).

## How the gates stay honest

- **Ratchets, not thresholds** — every metric is held to the committed baseline, so quality only
  moves one way. Tightening is a normal commit; loosening is a hand edit you have to own in review.
- **Switches, not env vars** — the heavy legs (`quality`, `ut`, `coverage`) recompile the
  workspace, so they never run because someone typed `prova`. Profiles throw the switches;
  `prova -s <class>` is the ad-hoc door.
- **`requires` vs `must_run`** — a missing tool skips a test on your laptop (visibly), but FAILS
  the profile that promised it in CI. A box that lost its toolchain can never green-wash a run.
- **Conduct once, read many** — `prova run ut` compiles and runs the unit tests exactly once, then
  any number of proofs bind prose claims to named cases from the junit account.

CI (`.github/workflows/`) runs the same profiles via
[`prova-rs/run-action`](https://github.com/prova-rs/run-action) — there is no separate CI command
to keep in step with the local one.

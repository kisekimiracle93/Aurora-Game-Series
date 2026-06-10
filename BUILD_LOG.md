# BUILD_LOG.md — Game Aurora Vertical Slice

Running log: what's built, test status, open issues, deviations. Newest milestone at the bottom.

## Environment

- **Engine:** Godot 4.6-stable (official, linux x86_64), installed at `/usr/local/bin/godot`.
- **Test framework:** GUT 9.6.0 at `addons/gut`.
- **Working headless test command** (confirmed against GUT 9.6.0):

  ```
  godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://test -ginclude_subdirs -gexit
  ```

  Wrapped in `./run_tests.sh` (auto-imports the project on first run; pass extra GUT args
  through, e.g. `./run_tests.sh -gselect=test_smoke.gd`).
- Note for playtesting: the project targets Godot **4.6 stable** — use that build locally.

## Doc provenance

`CLAUDE.md` and `VERTICAL_SLICE_BUILD_PLAN.md` were transcribed into the repo from the
human-supplied PDFs. Two values were cut off at the page edge in the PDF rendering and were
reconstructed (logged here per the deviation rule):

- **Damage `Random` coefficient** → `0.95–1.05` (the GDD states a "tight damage random
  range (0.95–1.05)"; the build plan PDF truncated at `Random 0.`).
- **Boss delay-resistance tail** → "immune at DR=100%" (matches the M1 test requirement
  "incl. immunity at DR=100%").

The GDD (Google Doc "Game Aurora") was reviewed for background; the build plan overrides
it wherever they differ.

---

## M0 — Project scaffold + test harness — DONE

**Built:**

- Godot 4.6 project skeleton (`project.godot`, 1280×720, mobile renderer for cheap grey-box).
- Folder layout per repo map: `/data`, `/components`, `/combat`, `/ui`, `/world`, `/test`,
  `/addons/gut`.
- GUT 9.6.0 installed; `run_tests.sh` CLI runner.
- Stub `CharacterData` resource script (`data/character_data.gd`) + a loading instance
  (`data/characters/bastil.tres`, placeholder numbers).
- `test/test_smoke.gd`: harness sanity + the stub resource loads with expected fields.

**Test status:** `2/2 passed (9 asserts)` — headless, green.

**Open issues:** none.

**Deviations:** none (doc reconstruction notes above).

---

## M1 — Core data + combat math (logic only) — DONE

**Built:**

- Resource classes (build plan 5.1): `AbilityData`, `EnemyData` (extends `CharacterData`),
  `StatusData` (+ existing `CharacterData`).
- Pure math helpers (static, scene-tree-free):
  - `combat/ctb_math.gd` — resolve/status/darkness speed mults, effective speed,
    ticks-to-act, jump-time `advance_to_next_turn`, timeline `build_preview`, action
    costs, delay + delay-resistance ramp.
  - `combat/damage_math.gd` — physical/magic formulas, element mods (absorb heals,
    immune=0), LayerMod (Resolve×Darkness), crit (+Resolve crit bonus), min-clamp,
    Resolve-based incoming-damage mult.
  - `combat/meter_math.gd` — Resolve band classification, Darkness max-HP degradation,
    accuracy penalty, forced-KO threshold.
- Components (thin Node wrappers over the math): `StatsComponent` (pools, affinities,
  death signal, Darkness HP-cap), `MetersComponent` (generic registry — Resolve/Darkness
  now, Duty/Burden plug in later), `CTBComponent` (CT, costs, delay + boss DR).

**Test status:** `51/51 passed (198 asserts)` — headless, green.
Covers every M1 checklist item: ticks-to-act, mixed-group turn order (hand-simulated
A→B→C→A with Normal costs), action-cost pushback, delay + DR incl. immunity at 100%,
hand-computed physical/magic values, element mods incl. absorb/immune, LayerMod
combination, min-damage clamp, crit multiplier, Resolve bands, Darkness curve.

**Numbers I chose (within plan ranges / spirit — tune at playtest):**

- Jecht's Darkness speed passive: up to **+15%** at Darkness 100 (`CTBMath.darkness_speed_bonus`).
- Darkness max-HP degradation: up to **−30%** at 100; accuracy penalty up to **−20 pts**
  ramping from Darkness 20; forced-KO threshold = **100** (meter full).
- Resolve crit bonus: 0 below R=81, scaling to **+10%** at 120.
- Effective-speed floor 0.01 (Stop-lite 0.05 still dominates; avoids div-by-zero).
- Damage `Random` variance **0.95–1.05**, injected as a parameter so formulas stay
  deterministic under test; components will pass a seeded RNG.

**Open issues:** none.

**Deviations:** `StatusData` carries data-driven behavior flags beyond the bare 5.1 schema
(`blocks_action`, `blocks_spells`, `accuracy_delta`, `tick_fraction`, resolve-shock drop
range) so status behavior stays in data rather than hardcoded by id.

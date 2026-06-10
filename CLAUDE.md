# CLAUDE.md — Game Aurora (Vertical Slice)

Standing instructions for the coding agent. **Read this at the start of every session.**

This is a turn-based JRPG vertical slice built in **Godot 4.x / GDScript**. The goal is to prove
the combat *feels good* with placeholder art — not to ship the finished game.

---

## Read first, every session

1. This file (`CLAUDE.md`).
2. `BUILD_LOG.md` — what's been done, test status, open issues. If it doesn't exist, create it.
3. `VERTICAL_SLICE_BUILD_PLAN.md` — the milestone roadmap, data schema, and exact
   formulas. The build plan is the source of truth for *what* to build and in *what order*.
4. The game design doc (GDD) — background only; the build plan overrides it wherever
   they differ.

Then check which milestone is active and continue from there.

---

## How you work here (prime rules)

- **Work one milestone at a time.** Finish and verify the current milestone before starting
  the next. Don't jump ahead.
- **You verify logic; the human verifies feel.** You can write and run automated tests for all
  combat math and meter logic. You **cannot** launch the engine and see or play the game. So:
  - Logic systems → prove them with green headless tests.
  - Anything visual, interactive, or "does it feel right" → stop at the milestone's
    PLAYTEST CHECKPOINT, summarize what to test, and **wait for the human's feedback.**
- **Never claim something works that you haven't verified.** "Tests pass" means you ran
  them and they're green (paste the count). "Plays correctly" is the human's call, not yours.
- **Don't block on art or audio.** Use grey-box placeholders (see conventions). Never
  attempt to produce real art/music.
- **Stay in scope.** If a feature isn't in the build plan's "IN" list, it doesn't go in the slice. Log
  the temptation in `BUILD_LOG.md` and defer it.
- **Log deviations.** If you depart from the build plan, write what and why in `BUILD_LOG.md`.
- **When genuinely unsure about intent, ask** rather than guessing on something hard to
  reverse.

---

## You own the numbers

The human has delegated stat tuning to you. **Pick reasonable starting values yourself** —
base stats, ability coefficients, status chances/durations, enemy stats — anywhere within
the ranges documented in the build plan (Section 5). Don't wait for the human to hand you
numbers.

- Keep all numbers in **data resources (`.tres`)**, never hardcoded, so they're trivial to
  retune.
- Randomized/seeded starting values are fine to bootstrap; expect to tune them from
  playtest feedback.
- Sanity-check against the build plan's feel goals: "dangerous, not spongey," every fight
  deliberate, bosses matter far more.

---

## Repo map

```
/data        # Resource scripts (CharacterData, AbilityData, EnemyData, StatusData) + their .tres instances
/components  # StatsComponent, MetersComponent, CTBComponent, StatusComponent, AbilitiesComponent
/combat      # CombatEncounter (state machine), turn queue, math helpers
/ui          # TurnTimeline, PartyHUD, ActionMenu, TargetSelect, StatusTray, CharacterMenu
/world       # town, outside area, dungeon scenes; player movement; encounter triggers; save points
/test        # GUT tests
/addons/gut  # test framework
CLAUDE.md, BUILD_LOG.md, VERTICAL_SLICE_BUILD_PLAN.md   # at root
```

---

## Stack & code conventions

- **Godot 4.x, GDScript.** Use static typing on variables, params, and returns wherever
  practical.
- **Composition over inheritance.** Combatants are a base node with child component
  nodes; the turn system shouldn't care whether a combatant is player, enemy, or merc.
- **Naming:** PascalCase for `class_name` types and node names; snake_case for functions
  and variables; SCREAMING_SNAKE for constants.
- **Keep the math pure and separable.** Put CTB / damage / status formulas in static
  functions (or a plain `RefCounted` helper) that take inputs and return outputs **without
  needing a running scene tree** — this is what makes them unit-testable headless.
  Components call into these helpers.
- **Decouple via signals.** Emit combat events (`turn_started`, `action_resolved`,
  `damage_dealt`, `meter_changed`, `combatant_died`, `phase_changed`) and let UI
  subscribe. UI reads combatant state through getter methods/signals, never by reaching
  into internals.
- **Data via Resources.** Content classes extend `Resource` with `@export` fields; instances
  are `.tres` files in `/data`.
- **Prefer `@onready` + exported `NodePath`s or groups** over fragile hardcoded
  `get_node("../../X")` paths.

---

## Commands

- **Open / run the game:** `godot --path .` (or open the project in the editor).
- **Run all tests headless:**

  ```
  godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://test -ginclude_subdirs -gexit
  ```

- **Run a single test file:** add `-gtest=res://test/test_ctb.gd` (or `-gselect=test_ctb.gd`).
- Confirm the exact GUT flags against the installed GUT version on first run, and record
  the working command in `BUILD_LOG.md` so future sessions reuse it.

---

## Testing rules

- Write tests **with or before** the implementation for every logic system.
- A logic milestone is **not done** until its tests are green. Always paste the pass/fail count
  when reporting.
- Headless test coverage (see the build plan's checklist) must include: CTB (speed, ticks-to-act,
  turn order, action-cost pushback, delay + DR), damage (formulas, element mods
  incl. absorb/immune, Resolve×Darkness layer mod, crit, min-clamp), Resolve (bands,
  modifiers, persistence, retry penalty), Darkness (damage curve, HP degradation, forced-KO
  threshold), status (hit-chance clamps, duration, resistance stacking, immunity,
  Resolve Shock), Echo gauge, and save↔load round-trips.

---

## Definition of done

- **Logic feature:** implemented + green headless tests + logged.
- **Visual / integrated feature:** implemented + the human has played it and confirmed it
  works and reads clearly. Until then it is *in progress*, not done.

---

## Guardrails / don'ts

- Don't switch engines or remove the test harness.
- Don't build **Duty** or **Burden** for the slice — but keep `MetersComponent` general enough
  to register more meters later.
- Where the boss design (Frozen Shepherd "Overflow Pulse") references Burden,
  substitute a **Resolve drain or flat damage ramp**.
- Don't add progression systems, extra bosses, real cutscenes, shops beyond a stub, or
  Heir transformations past Form I.
- Don't fake verification, and don't mark visual behavior "done" from code inspection
  alone.

---

## Per-session checklist

1. Read `CLAUDE.md` + `BUILD_LOG.md`; note the active milestone.
2. Build the next coherent chunk of that milestone.
3. Write/run headless tests for any logic; paste results.
4. Update `BUILD_LOG.md` (what changed, test status, open issues, deviations).
5. If you've hit a PLAYTEST CHECKPOINT: summarize what to test and stop for human
   feedback.

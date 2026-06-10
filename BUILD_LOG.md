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

---

## M2 — Status system + Echo + persistence (logic only) — DONE

**Built:**

- `combat/status_math.gd` — hit chance (5–95 clamp, Focus−Ward scaling, Resolve factor,
  resistance subtraction), duration scaling (min 1 turn), Resolve Shock drop roll.
- `components/status_component.gd` — deterministic `try_apply` (caller supplies rolls),
  per-status resistance stacking (+20 pts per successful application), innate resistance
  (boss `stability` hook), hard immunity, freeze/silence lockouts, stacked speed mult,
  accuracy deltas, per-turn `tick_turn()` with burn/bleed hooks + expiry. Tick damage is
  routed by the encounter (M3), keeping components decoupled.
- The six status definitions as `.tres` in `data/statuses/`: freeze (action lock, 2t),
  burn (5% max-HP/turn, 3t), slow (×0.7 speed, 3t), silence (spell lock, 2t), bleed
  (4% max-HP/turn, ×0.9 speed, 3t), resolve_shock (−20..−40 Resolve + ×0.85 speed,
  −10 accuracy, 2t).
- `combat/echo_math.gd` + `MetersComponent` echo helpers — gauge 0–100, battle-scoped,
  fills from damage dealt (25 pts per 100% of target max HP) and taken (50 pts per 100%
  of own max HP), spend requires full gauge, refillable (multi-use per battle).
- `data/save_data.gd` (`SaveData` resource) + `world/save_system.gd` — write/read/delete,
  save-point recovery (drain Darkness to 0, restore Resolve up to a 75 floor, never
  lowering), retry penalty (−15 Resolve, clamped at 0), per-character collect/apply.

**Test status:** `77/77 passed (316 asserts)` — headless, green.
Covers every M2 checklist item: hit-chance clamps at 5/95, duration scales with
Focus−Ward and Resolve, resistance reduces repeat applications, immunity blocks,
Resolve Shock drop + debuff, Echo gauge fill/spend (multi-use), save→load round-trip,
retry lowers Resolve.

**Numbers I chose (tunable):** resistance stack step 20 pts; burn 5% / bleed 4% max HP
per tick; Echo rates 25 (dealt) / 50 (taken); retry penalty −15; save-point Resolve
floor 75.

**Open issues:** none.

**Deviations:** none.

---

## M3 — Combat encounter loop (first playable) — BUILT, awaiting PLAYTEST CHECKPOINT 1

Visual/interactive work is **in progress, not done**, until the human has played it.
All M3 *logic* is headless-verified.

**Built:**

- `combat/base_combatant.gd` — `BaseCombatant` (Node2D) composing Stats/Meters/CTB/
  Status/Abilities components; factories `from_character` / `from_enemy`; Darkness wiring
  (HP-cap degradation + forced-KO at 100), accuracy after status/Darkness penalties,
  guard flag, enemy neutral-Resolve stand-in (ferocity applied as offense bias instead).
- `combat/action_resolver.gd` — one ability use end-to-end: accuracy roll (chosen rule:
  `clamp(accuracy − evasion, 20, 100)`; logged as a deviation-by-necessity since the plan
  defines no physical-hit formula), damage via DamageMath (element/Layer/crit/guard ×0.5/
  Resolve-defense), absorb→heal, status riders (incl. Resolve Shock drop), Time delay,
  Echo gains, Resolve erosion from damage taken (25 × dmg/maxHP). All RNG injected.
- `combat/combat_encounter.gd` — jump-time turn loop + state machine (Init→…→CheckEnd
  as a synchronous `advance_until_input()`); stub enemy AI (random living player target,
  M4 replaces with the priority list); freeze skips the turn at Normal cost; DoT ticks at
  turn start; ally-death Resolve drop (−20), victory gain (+10); timeline preview signal
  (next 8, assumes Normal cost); 10k-step runaway guard.
- UI (programmatic grey-box): `CombatantToken` (rect + name + HP sliver + hit flash +
  guard tag), `TurnTimeline`, `PartyHUD` (HP/Aether/Resolve+band/Darkness[heirs]/Echo),
  `ActionMenu` (greys out unaffordable/silenced), `TargetSelect`, `CombatLog`.
- `world/battle_test.tscn` (**main scene**): Bastil/Cavene/Jecht/Mati vs 3 Aether Wolves;
  victory/defeat overlay; "Fight again" carries meters; defeat "Retry" applies −15 Resolve.
- Data: `attack_basic` + `guard` abilities; cavene/jecht/mati character `.tres` (Heirs
  flagged); `aether_wolf.tres` (weak Fire / resists Ice).

**Test status:** `96/96 passed (385 asserts)` — headless, green. New coverage: resolver
(variance band, immune=0 no-echo, absorb heals, 20%-floor miss rate, guard ≈half,
echo+resolve side effects, Resolve Shock drop, Time delay, heal band, Darkness LayerMod
×1.3 on a live heir) and encounter (scripted 4v2 runs to victory; fastest-first turn
order [Cavene]; 8-entry preview; outnumbered defeat; ally-death Resolve drop; guard flow;
aether gating keeps awaiting input). Plus scene smoke tests: `battle_test.tscn` boots
headless to AWAITING_PLAYER with menu open; UI submit path advances. Game binary boots
clean (`--quit-after 5`, exit 0).

**Numbers I chose (tunable):** hit-chance clamp 20–100; Resolve erosion scale 25;
ally-death drop −20; victory gain +10; frozen turn costs 850; stub fight = 3 wolves.

**Open issues:**

- Timeline preview assumes a uniform Normal (850) cost for future turns; exact per-actor
  costs would need per-ability lookahead. Revisit if the preview reads wrong in play.
- Enemy AI is the M3 stub (random target). M4 brings merc-aggro → low-Resolve →
  high-Darkness priority.

**Deviations:** physical/magic accuracy roll formula chosen as above (plan silent);
Guard implemented as engine-handled ability id `guard` (still data-driven in menus).

**▶ PLAYTEST CHECKPOINT 1 — what to test (run `godot --path .` with Godot 4.6):**

1. Does the 4-vs-3 fight run start to finish (win AND lose at least once)?
2. Is the turn-order preview readable and does it match who actually acts next?
3. Do HP / Aether / Resolve (+band colors) / Darkness (Jecht & Mati) / Echo read clearly?
4. Guard: does damage visibly shrink? Defeat→Retry: does Resolve start 15 lower?
5. Report any crash/script error verbatim, plus anything that feels off.

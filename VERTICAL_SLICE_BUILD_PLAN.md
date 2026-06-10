# Game Aurora — Vertical Slice Build Plan

**For: a Claude coding agent (Fable). Read this whole file before writing any code, then
work milestone by milestone.**

The goal is a *playable vertical slice* that proves the combat systems feel good — not the
finished game. Visuals are placeholder (grey-box / primitives). The win condition for the
whole slice is the "Playtest checklist" at the end.

---

## 0. How to use this plan

**For the human (you):**

- Hand the agent **one milestone at a time**. Don't paste the whole plan and say "go" —
  review each milestone's output before moving on.
- Milestones M0–M2 are pure logic. The agent can build *and verify them itself* with
  automated tests — you don't need to do anything but read the test results.
- From **M3 onward you are the play-tester.** The agent cannot launch the engine and
  see/feel the game. At every "▶ PLAYTEST CHECKPOINT," run the build, then report back
  what broke or felt off (paste errors verbatim).

**For the agent:**

- Engine and approach are locked in Section 1. Do not switch engines or skip the test
  harness.
- For every logic system, **write the tests alongside (or before) the implementation and
  run them headless.** Report pass/fail counts. Do not report a logic milestone "done"
  without green tests.
- Keep a running `BUILD_LOG.md` at the project root: what you built, test results, and any
  deviations from this plan (with reasons).
- When you reach a PLAYTEST CHECKPOINT, stop, summarize what to test, and **wait for
  the human's feedback** before continuing.
- Use placeholder art only (Section 1). Never block on, or attempt to produce, real art or
  audio.

---

## 1. Locked tech decisions

- **Engine:** Godot 4.x (latest stable). Chosen because the entire project is human-readable
  text (`.gd` scripts and `.tscn`/`.tres` scenes/resources), so you can scaffold, edit, diff,
  and test it all from the command line.
- **Language:** GDScript.
- **Data:** Data-driven via custom `Resource` classes saved as `.tres` files (Godot's
  equivalent of Unreal Data Assets). Content = data, not hardcoded.
- **Tests:** GUT (Godot Unit Test). All logic tests must run headless via
  `godot --headless -s addons/gut/gut_cmdln.gd ...`.
- **Placeholder art:** `ColorRect`/`Polygon2D`/simple shapes for characters and
  environments, `Label`-based UI, plain tween animations. If the human supplies a folder
  of CC0 sprites, use them; otherwise stay grey-box.
- **Audio:** silent or simple stub beeps only.

---

## 2. Slice scope

**IN:**

- Combat: CTB turn system, **Resolve** meter, **Darkness** meter (Jecht & Mati only).
- 4 playable characters (Bastil, Cavene, Jecht, Mati) + 1 simple hireable merc.
- Status effects: Freeze, Burn, Slow, Silence, Bleed, Resolve Shock.
- Elements: Fire, Ice, plus Time (delay/slow utility only — no Time *damage*).
- Echo abilities: one unlockable Echo (Jecht's *or* Mati's) via one Memory Echo event.
- Enemies: Aether Wolf, Icebound Stag (mini-elite), Crystal Wolves (boss adds), **Frozen
  Shepherd** (boss, 3 phases).
- World: one small town, one outside area with random encounters, one crystal-site
  dungeon ending in the boss.
- Save point that: drains Darkness, restores Resolve, and saves. Meter persistence across
  battles + a retry penalty (Resolve lower on retry).

**EXPLICITLY OUT (do not build, but leave clean hooks):**

- **Duty and Burden meters.** Keep the meter component general enough to add two more
  meters later, but the slice ships with only Resolve + Darkness.
- Sphere grid / progression, shops beyond a stub, multiple bosses, transformations
  beyond Form I for the Heirs, branching, the secret boss, real cutscenes, real art/audio.

> Anywhere the GDD's boss/enemy design references Duty or Burden (e.g. the Frozen
> Shepherd's "Overflow Pulse" that adds Burden over time), **substitute a Resolve drain or
> a flat damage ramp** so the mechanic still creates pressure without the deferred
> systems.

---

## 3. Division of labor & feedback loop

| The agent does (self-verifiable) | The human does (eyes / play) |
| --- | --- |
| Combat math, meter logic, status math, save/load — with headless tests | Run the build, confirm it *feels* right and reads clearly |
| Enemy AI logic, boss phase logic | Judge fairness, difficulty, "every fight matters" |
| Scene scaffolding, UI wiring, encounter triggers | Catch runtime/visual bugs, UI layout problems, camera/feel issues |
| Provide grey-box placeholders | Supply real art/audio later (out of slice scope) |

Loop: agent builds + runs headless tests → at checkpoints, human plays → human pastes
back errors/feel notes → agent fixes → repeat.

---

## 4. Architecture (Godot)

Mirror of the GDD's component design, adapted to Godot nodes/resources.

**Combatant** — `CharacterBody2D` (or `Node2D`) `BaseCombatant`, parent of
player/enemy/merc, composed of child component nodes:

- `StatsComponent` — HP, Aether, Power, Focus, Guard, Ward, Speed, Accuracy, Evasion,
  Crit, element affinities.
- `MetersComponent` — Resolve (0–120) and Darkness (0–100, heirs only). **Generic
  enough to register more meters later.**
- `CTBComponent` — CT, threshold, effective-speed computation, ticks-to-act, action-cost
  payment.
- `StatusComponent` — active status instances, tick, immunity/resistance.
- `AbilitiesComponent` — list of unlocked `AbilityData`.

**CombatManager** — a scene (not an autoload) `CombatEncounter` that owns the combatant
list, the turn queue, and the battle state machine: `Init → BuildPreview → ChooseAction →
ResolveAction → PostTurn → CheckEnd`. Uses the jump-time method (Section 5) to advance
turns.

**Interfaces** — Godot has no formal interfaces; use `class_name` base types + duck typing. UI
reads combatants through getter methods, never by reaching into internals.

**UI scenes** — `TurnTimeline` (turn-order preview), `PartyHUD` (HP/Aether bars + Resolve
indicator + Darkness indicator for heirs + Echo gauge), `ActionMenu`, `TargetSelect`,
`StatusTray`, `CharacterMenu` (numeric bars + tooltips).

**Persistence** — a `SaveData` resource holding per-character Resolve and per-heir Darkness;
written at save points; applied on load; retry applies the Resolve penalty.

Suggested folders: `/data` (.tres + the resource scripts), `/components`, `/combat`, `/ui`,
`/world`, `/test`, `/addons/gut`.

---

## 5. Data schema & formulas

### 5.1 Resource classes (fields the agent should create)

```
# CharacterData (Resource)
name: String
class_type: String        # "Aetherion" | "Heir"
element: String           # "Fire" | "Ice"
is_heir: bool             # enables Darkness meter
base_stats: Dictionary    # hp, aether, power, focus, guard, ward, speed, accuracy, evasion, crit
affinities: Dictionary    # element -> "weak"|"neutral"|"resist"|"absorb"|"immune"
ability_ids: Array[String]

# AbilityData (Resource)
id: String
display_name: String
ability_type: String      # "attack"|"spell"|"support"|"echo"
damage_type: String       # "physical"|"magic"|"none"
element: String
coeff: float              # SkillCoeff or SpellCoeff
ct_cost: int              # action weight (see 5.3)
aether_cost: int
targeting: String         # "single"|"aoe"|"line"|"self"
statuses: Array           # [{status_id, base_chance, base_duration}]
requirements: Dictionary  # e.g. {min_darkness:..., form_required:...}  (slice: minimal)

# EnemyData (Resource) — like CharacterData plus:
ferocity: float           # offense bias (enemy stand-in for Resolve)
stability: float          # resistance to delay/status
ai_profile: String        # which targeting priority list to use

# StatusData (Resource)
id: String                # "freeze"|"burn"|"slow"|"silence"|"bleed"|"resolve_shock"
base_duration: int        # in turns
speed_mult: float         # for slow/haste-type statuses (else 1.0)
on_tick: String           # effect hook id (e.g. burn dmg, bleed dmg)
```

### 5.2 Meters (slice)

- **Resolve** 0–120. Bands: 0–30 Broken, 31–39 Shaken, 40–80 Neutral, 81–100 Steady,
  101–120 Unyielding. Persists between battles. Changes from: damage taken, ally death
  (big drop), victory (+), defeat (−), scripted events.
- **Darkness** 0–100 (Jecht & Mati only). Rises when using Dark abilities. Effects: ↓ max HP
  (until drained), ↓ accuracy, ↑ Power & Focus (damage curve below). At a critical
  threshold → forced KO requiring a special revive. Drained at save points.

### 5.3 CTB math

```
CT_THRESHOLD = 1000
Each tick:       CT += SPD_eff
SPD_eff (slice) = SPD_base * M_resolve_spd * M_status
                  (+ Jecht passive: small speed bonus scaling with Darkness)

M_resolve_spd:
  40 <= R <= 80 : 1.0
  R < 40        : 0.70 + 0.30 * (R / 40)
  R > 80        : 1.0 + 0.25 * ((R - 80) / 40)^1.2

M_status:  Haste 1.30 | Slow 0.70 | Cripple 0.50–0.85 | Stop-lite 0.05
           (multiply if stacked; clamp 0.05–1.50)

Action cost (subtract after acting):  CT -= cost
  Light 650 | Normal 850 | Heavy 1100 | Very Heavy 1350
  Attack 850 | Guard 650 | Item 750 | Basic spell 900 | Big spell 1150 | Echo 1200–1500

ticks_to_act = ceil((CT_THRESHOLD - CT) / SPD_eff)      # for the preview list
Jump-time execution: advance everyone by min(ticks_to_act), then the actor(s) at/above threshold act.

Delay (push enemy back):  CT_enemy -= DelayAmount   (Small 200 | Med 350 | Big 500)
Boss Delay Resistance:    DR += 25% per successful delay; Delay_eff = Delay * (1 - DR); immune at DR=100%.
```

### 5.4 Damage math

```
Physical = ((Power * SkillCoeff) - (Guard * GuardCoeff)) * ElementMod * LayerMod * Random
Magic    = ((Focus * SpellCoeff) - (Ward  * WardCoeff))  * ElementMod * LayerMod * Random

Coeffs:  SkillCoeff 1.2–3.5 | SpellCoeff 1.3–4.0 | GuardCoeff 0.6 | WardCoeff 0.7 | Random 0.95–1.05
Clamp minimum damage = 1.

ElementMod: weak 1.5 | neutral 1.0 | resist 0.5 | absorb -0.75 (heals) | immune 0

LayerMod (slice) = M_resolve_dmg * M_darkness      # Duty/Burden deferred
  M_resolve_dmg:
    40–80 : 1.0
    R<40  : 0.70 + 0.30 * (R/40)
    R>80  : 1.0 + 0.40 * ((R-80)/40)^1.2
  M_darkness (heirs):
    K<20  : 1.0
    K>=20 : 1.0 + 0.60 * ((K-20)/80)

Crit: chance = CritStat + ResolveBonus (up to +10% at high R); CritDMG = damage * 1.5
Defense from Resolve: high R -> -10% damage taken; low R -> +15% damage taken.
```

### 5.5 Status math

```
HitChance = BaseChance + (Focus - Ward)*0.5% + ResolveFactor - Resistance   (clamp 5–95%)
  ResolveFactor: target R<40 -> +15% ; R>80 -> -10%
Duration(turns) = BaseDuration * (1 + (Focus - Ward)/100) * ResolveDurationMod
  ResolveDurationMod: low R x1.3 | neutral x1.0 | high R x0.7
Resistance stacking (esp. bosses): each successful application lowers next chance; hard immunity possible.
Resolve Shock: instant Resolve -20 to -40 + temporary Speed & Accuracy debuff.
```

---

## 6. Milestones

Each milestone lists: **Goal · Agent builds · Headless tests · ▶ Playtest checkpoint** (where
present).

### M0 — Project scaffold + test harness

- **Goal:** a Godot project that runs tests green from the command line.
- **Agent builds:** project skeleton, folder layout, GUT installed, a CLI test-run script, one
  trivial passing test, a stub `CharacterData` resource that loads.
- **Headless tests:** the trivial test passes via `godot --headless`. Confirm and paste
  output.

### M1 — Core data + combat math (logic only, no UI)

- **Goal:** the combat brain, fully unit-tested.
- **Agent builds:** all Section 5.1 resource classes; `StatsComponent`, `CTBComponent`,
  `MetersComponent` (Resolve + Darkness); damage functions (5.4); CTB functions (5.3).
- **Headless tests:** ticks_to_act correct for known stats; turn order correct across a mixed
  group; action cost pushes the next turn back; delay + DR behave (incl. immunity at
  DR=100%); physical/magic formulas match hand-computed values; element mods incl.
  absorb-heals and immune=0; LayerMod combines Resolve + Darkness correctly; min-damage
  clamp; crit multiplier; Resolve band classification; Darkness damage curve.

### M2 — Status system + Echo + persistence (logic only)

- **Goal:** the rest of the combat logic, unit-tested.
- **Agent builds:** `StatusComponent` (the six statuses, 5.5 math, resistance stacking,
  immunity); Echo gauge (earned by damage dealt/taken, multi-use per battle); `SaveData`
  resource + save/load of Resolve and Darkness; retry penalty.
- **Headless tests:** hit-chance clamps at 5/95; duration scales with Focus−Ward and
  Resolve; resistance reduces repeat applications; immunity blocks; Resolve Shock
  applies the drop + debuff; Echo gauge fills and spends correctly; save→load round-trips
  meters; retry lowers Resolve.

### M3 — Combat encounter loop (first playable)

- **Goal:** a single fight you can actually play.
- **Agent builds:** `CombatEncounter` state machine; stub enemy AI (basic attack); player
  `ActionMenu` + `TargetSelect`; `TurnTimeline`; `PartyHUD` (HP/Aether + Resolve +
  Darkness + Echo gauge); placeholder combatant visuals; victory/defeat + retry flow.
- **▶ PLAYTEST CHECKPOINT 1:** Does a basic 4-vs-some fight run start to finish? Is the
  turn order preview readable and correct? Do HP/Resolve/Darkness display clearly?
  Report any crash verbatim.

### M4 — Character & enemy content

- **Goal:** distinct kits and real enemies.
- **Agent builds:** minimal kits as data for Bastil, Cavene, Jecht, Mati (one attack + 1–2 skills
  + one Echo each; Darkness only on the Heirs); the simple church merc (skills, no magic,
  low HP, high aggro); Aether Wolf, Icebound Stag, Crystal Wolves; enemy AI priority list
  (target merc → low-Resolve → high-Darkness).
- **▶ PLAYTEST CHECKPOINT 2:** Do the four characters feel different? Is damage
  "dangerous, not spongey"? Does the merc draw aggro and feel appropriately fragile?
  Does the Heirs' Darkness feel powerful-but-scary?

### M5 — Boss: Frozen Shepherd

- **Goal:** a fair-but-brutal boss with readable phases.
- **Agent builds:** 3-phase logic; **P1** Merc Freeze (freeze slot 4 early), summon 2 Crystal
  Wolves, Glacial Command (Slow + accuracy↓), Overflow substitute (Resolve drain /
  damage ramp after N turns — *not* Burden); **P2** at 60% HP: Echo Roar (Resolve Shock
  AoE), Ice Mirror (reflect Fire once), Hunt the Dark (target highest Darkness); **P3** at 25%
  HP: vulnerable to Ice, Darkness temptation; visual/audio phase cues (placeholder).
- **▶ PLAYTEST CHECKPOINT 3:** Are the phase transitions readable? Does Ice Mirror
  force Bastil/Cavene to adapt? Is it hard but fair?

### M6 — World: town, outside area, dungeon

- **Goal:** the end-to-end loop.
- **Agent builds:** simple top-down player movement + scene transitions; **town** (a few
  NPCs, save point [drain Darkness + restore Resolve + save], merc-hire spot, shop stub);
  **outside area** with a random-encounter trigger (step/zone based) using the M4 enemies;
  **dungeon** in three short zones (combat approach → memory-echo room → boss arena).
- **▶ PLAYTEST CHECKPOINT 4:** Can you walk town → outside → dungeon → boss, save,
  get into encounters, and retry after a loss with the Resolve penalty applied?

### M7 — Memory Echo + polish

- **Goal:** hit the "done" bar.
- **Agent builds:** Memory Echo trigger → placeholder cutscene (text + fade) → unlock one
  Echo ability → return to gameplay; `CharacterMenu` with numeric bars + tooltips; status
  icons; minor feedback polish; audio stubs.
- **▶ PLAYTEST CHECKPOINT 5:** Full run-through against the Playtest checklist below.

---

## 7. Headless test checklist (must be green before each playtest)

- CTB: effective speed, ticks-to-act, turn order, action-cost pushback, delay + DR.
- Damage: physical, magic, element mods (incl. absorb/immune), LayerMod
  (Resolve×Darkness), crit, min-clamp, Resolve-based defense.
- Resolve: band classification, modifiers, persistence, retry penalty.
- Darkness: damage curve, HP degradation, forced-KO threshold.
- Status: hit-chance clamps, duration scaling, resistance stacking, immunity, Resolve
  Shock.
- Echo gauge fill/spend. Save↔load round-trip.

---

## 8. Playtest checklist (slice "done" criteria)

- Player can predict turns from the timeline and feel smart doing it.
- Resolve visibly changes performance and can push a character into a panic/flow state.
- Darkness on the Heirs feels powerful **and** dangerous (HP cost, forced-KO risk, draining
  at save points matters).
- Combat is dangerous, not spongey; every fight feels deliberate; the boss matters far
  more.
- Boss phases are readable through visual/audio cues.
- The Memory Echo clearly grants a new combat capability.
- Full loop works: town → outside encounters → dungeon → boss, with save and retry.

---

## 9. Risks & guardrails

- **Scope creep is the #1 risk.** If a feature isn't in Section 2's IN list, it doesn't go in the
  slice. Log the temptation, defer it.
- **Meter legibility:** even with just Resolve + Darkness on screen, watch that the player can
  read state at a glance. If two meters already feel busy, that's a finding — note it for the
  Duty/Burden decision later.
- **Don't fake verification.** Logic milestones are not "done" without green headless tests;
  integrated/visual behavior is not "done" until the human has played it.
- **Don't block on art.** Grey-box everything; the slice is about feel and systems.

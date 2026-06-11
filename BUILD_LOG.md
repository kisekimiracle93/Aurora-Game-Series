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

## M3 — Combat encounter loop (first playable) — DONE (checkpoint 1 passed)

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

---

## ▶ PLAYTEST CHECKPOINT 1 — PASSED (human, 2026-06-10)

Human ran the 4-v-3 wolf fight: win and loss both completed cleanly, no crashes,
bars read clean, guard visibly cut damage, turn-order preview matched actual
turns, and the defeat-retry Resolve penalty was confirmed in play. M3 is done.

---

## M4 — Character & enemy content — BUILT, awaiting PLAYTEST CHECKPOINT 2

All M4 logic is headless-verified; feel verdict belongs to the human.

**Built:**

- **Kits as data** (one weapon art / spells + one Echo each; Aether costs now bite):
  - Bastil: Oathfire Strike (phys Fire 2.2, 12 AE, 40% Burn), Rally by Flame
    (+15 Resolve to an ally — new `resolve_gain` field), Echo: The Living Pyre
    (phys Fire AoE 2.6 + Burn chance).
  - Cavene: Aetherflare (magic Fire 2.4, 35% Burn), Scorchstep (magic Fire 1.6 +
    Small delay 200 — Time utility rider), Echo: Trial by Fire (magic Fire AoE 3.2).
  - Jecht (Heir): Rime Rend (phys Ice 2.4, +12 Darkness, 25% Freeze), Absolute Zero
    (magic Ice AoE 2.0, +20 Darkness, 40% Slow), Echo: Throne of Winter (magic Ice
    AoE 3.5, +25 Darkness). `darkness_speed_passive = true` (the M1 speed curve).
  - Mati (Heir): Glacial Benediction (heal, Focus×2.2), Hymn of Snowfall (AoE
    debuff: 45% Slow + 15% Freeze, +8 Darkness), Echo: The Last Snow (AoE heal 3.0).
  - **Pray** (shared, human-requested): true no-op, self, Heavy 1100 CT — passes
    the turn with zero protection, for damage testing. Encounter logs it distinctly.
- **Church Lancer merc**: slot 5, `is_merc` flag, 180 HP, 0 Aether (skills only:
  Lancer's Lunge — phys 2.0, 35% Bleed), draws all priority-AI aggro.
- **Enemies**: Aether Wolf gains Fearful Howl (40% Resolve Shock) + `priority` AI;
  Icebound Stag (mini-elite, 420 HP, stability 0.3, Antler Charge + Glacial Breath
  AoE Freeze, `hunt_dark` AI — stalks the highest-Darkness Heir); Crystal Wolf
  (boss add for M5: fast, fragile, **absorbs Ice**, weak to Fire).
- **EnemyAI** (`combat/enemy_ai.gd`): priority list per the plan (merc → lowest
  Resolve → highest Darkness tiebreak), `hunt_dark` profile, 35% special-move
  chance, respects Silence/affordability, never uses Echo/guard/pray.
- **Engine wiring**: Echo abilities gate on a full gauge and spend it; AoE targeting
  end-to-end (player UI submits all valid targets; enemy AoE hits the whole party);
  `resolve_gain` flows through resolver + combat log; weapon arts ("attack" type)
  appear in the skill menu but are not Silence-blocked; ActionMenu order:
  Attack / skills / Echo (gauge-gated) / Guard / Pray.
- **Scene**: party of 5 (incl. merc, grey-green token) vs 2 Aether Wolves + 1
  Icebound Stag; HUD resized for 5 panels (merc's 0-Aether bar handled).

**Test status:** `117/117 passed (880 asserts)` — headless, green; game boots clean.
New coverage: EnemyAI (merc-first, lowest-Resolve, Darkness tiebreak, hunt_dark +
fallback, silence/echo/guard/pray exclusions, basic/special mix), content sanity
(kits load with exactly one Echo each, coeffs inside plan ranges, echo CT 1200–1500,
merc magicless/0-cost, enemy wiring incl. Ice-absorb crystal wolf), and flow
(Echo gate→spend, Pray no-op + free enemy turn, Rally +15, Absolute Zero pays 20
Darkness + hits both wolves, Benediction heals 75–83, priority AI dogpiles the merc).

**Numbers I chose (tunable):** above per-ability values; merc 180 HP; stag ferocity
1.1; AI special chance 35%.

**Open issues / notes for playtest:**

- The glacial roster resists Ice, so the Heirs' Ice kits are deliberately
  situational here (their payoff is the boss's P3 Ice vulnerability). Watch
  whether that reads as "tactical" or just "bad" — tune affinities if the latter.
- Crystal Wolves absorbing Ice will punish careless Heir AoE in the boss fight
  (intended texture; verify it reads fairly in M5).

**Deviations:** `resolve_gain` added to AbilityData (Rally-type morale support is
core to Bastil's GDD identity and the slice's Resolve focus); Pray added on human
request as a shared no-op action.

**▶ PLAYTEST CHECKPOINT 2 — what to test (`godot --path .`):**

1. Do the four characters feel different (Bastil anchor / Cavene spell-debuffer /
   Jecht darkness burst / Mati support)?
2. Is damage "dangerous, not spongey" — do the wolves + stag threaten a 5-slot party?
3. Does the merc visibly soak aggro and feel appropriately fragile?
4. Does Darkness feel powerful-but-scary on the Heirs (HP cap shrinking as it rises)?
5. Do Aether costs force real choices? Does the Echo gauge → Echo ability loop read?
6. Pray: park the party on it and confirm enemies wail on you unprotected.

---

## ▶ PLAYTEST CHECKPOINT 2 — PASSED (human, 2026-06-11)

Human approved the M4 build and asked to push on ("yes - push to next phase").
No issues reported. M4 is done.

---

## M5 — Boss: Frozen Shepherd — BUILT, awaiting PLAYTEST CHECKPOINT 3

All M5 logic is headless-verified; fairness/readability verdict belongs to the human.

**Built:**

- `combat/boss_frozen_shepherd.gd` (`FrozenShepherdController`, child of the boss,
  routed by the encounter): 3-phase script with `phase_changed` cues.
  - **P1 "Preservation"** (>60% HP): turn 1 **Merc Freeze** (95% base, the Church's
    shield is disposable), turn 2 **Summon 2 Crystal Wolves** (mid-fight `add_enemy`
    + `combatant_added` signal), turn 3 **Glacial Command** (boss-flavored Slow
    instance `glacial_chill`: ×0.75 speed, −10 accuracy), then a Command/Rake
    rotation with merc-first priority targeting.
  - **P2 "Stagnation"** (≤60%): opens with **Echo Roar** (70% Resolve Shock AoE),
    raises **Ice Mirror** (next Fire hit rebounds onto the caster — generic
    `reflect_element`/`reflect_charges` on BaseCombatant, resolved in
    ActionResolver, re-armed every 3rd boss turn), and single-target attacks
    switch to **Hunt the Dark** (highest-Darkness stalking).
  - **P3 "Release"** (≤25%): Ice affinity flips to **weak** (the Heirs' payoff),
    guard/ward shed 30%, ferocity 1.15 → 1.4. Crossing straight to P3 still fires
    the P2 cue + kit (no skipped phases).
  - **Overflow substitute** (NOT Burden): from boss turn 7, every boss turn drains
    the party **−6 Resolve** with its own log line.
- Boss data: 1500 HP, stability 0.5 (25 innate status resistance),
  `accumulates_delay_resistance = true` (the M1 DR ramp finally bites).
- Scene work: `fight_select.tscn` (new main scene) → wolfpack skirmish or boss
  arena (`boss_test.tscn`, same battle script with `roster="boss"`); boss token
  ×1.7 ice-white; phase banner + background tint tween per phase (placeholder
  cues); summoned wolves get tokens beside the boss; end overlay gains a
  "Fight select" button.

**Test status:** `126/126 passed (936 asserts)` — headless, green; game boots clean.
New coverage: P1 opener sequence [merc_freeze → summon → glacial_command] with the
freeze landing and enemies growing to 3; overflow pulses exactly once per boss turn
from turn 7; phase flips at 60%/25% driven purely by HP signals; P3 Ice-weak +
armor shed + never-skip-P2; P2 roar→mirror order and armed mirror; mirror reflects
Fire once (boss untouched, caster burned, charge spent, second cast lands); Hunt
the Dark rakes the highest-Darkness Heir; fight-select + boss scenes boot headless
to player input with the controller wired.

**Numbers I chose (tunable):** boss HP 1500 / power 38 / focus 34 / speed 24;
overflow from turn 7 at −6 Resolve; mirror re-arm every 3 boss turns; P3 armor ×0.7,
ferocity 1.4; Crystal Wolves summoned once (2 of them).

**Open issues / notes for playtest:**

- Boss fight length and the P1 merc-freeze opener are feel-critical — watch whether
  1500 HP reads as "matters far more" or "spongey".
- Crystal Wolves absorb Ice: careless Heir AoE heals them (intended texture).

**Deviations:** Glacial Command's accuracy-down rides a second *instance* of the
existing `slow` status family (`glacial_chill.tres`, same id) rather than a new
status type, keeping the six-status scope intact.

**▶ PLAYTEST CHECKPOINT 3 — what to test (`godot --path .` → "Boss — The Frozen Shepherd"):**

1. Are the phase transitions readable (banner + tint + behavior shift)?
2. Does Ice Mirror force Bastil/Cavene to adapt (stop throwing Fire blindly)?
3. Does P1 (merc frozen, wolves summoned, chill AoE) feel scripted-but-fair?
4. Does the late-fight Overflow drain create pressure without feeling cheap?
5. Is P3 a real payoff for Jecht/Mati (Ice now rips; armor shed)?
6. Overall: hard but fair? How many retries did it take, and did the −15 Resolve
   retry penalty change how the rematch felt?

---

## Checkpoint feedback pass (post-M5 build, pre-boss-verdict) — tuning + UI fix

Human played the skirmish with the M4/M5 build. Verdict: characters felt
different, Aether costs forced real choices, Pray worked, damage "dangerous"
with real wolves-vs-stag triage. Three problems reported, all fixed:

1. **Action menu covered the first HUD panel** → command menus now bottom-anchor
   just above the HUD (deferred placement after the menu rebuilds), never
   overlapping character info.
2. **Echo gauge never filled → Echoes never used.** Root cause: dealt-gain was
   normalized by the TARGET's max HP, so chipping a 1500 HP boss gave ~nothing.
   Gains are now normalized by the attacker's own max HP and retuned:
   dealt 25→**60** pts per 100% own-HP-worth of damage; taken 50→**90** pts per
   100% of own HP. A character now reaches a first Echo in roughly 4-6 solid
   hits or 2-3 heavy hits taken.
3. **Darkness never built meaningfully.** Heir costs raised: Rime Rend 12→**15**,
   Absolute Zero 20→**30**, Throne of Winter 25→**40**, Hymn of Snowfall 8→**10**.
   A dark-leaning Jecht can now realistically flirt with the forced-KO
   threshold inside one long fight (the temptation mechanic, working).

**Test status:** `126/126 passed (936 asserts)` — updated gauge/darkness tests;
boots clean. PLAYTEST CHECKPOINT 3 (boss verdict) still open.

**Next discussion queued by the human:** free / AI-generated assets (3D + music)
to dress the slice. Note the locked slice scope says grey-box 2D + CC0 sprites
if supplied; a 3D port would be a logged deviation to decide deliberately.

---

## Asset pass A (human-directed) — main menu + drop-in art/music pipeline

Human picked option A (2D art + music now; 3D deferred until after the slice).
Their files live on their PC, so this pass ships the full plumbing + a
procedural title screen; binding real art is a file-drop away (see
ASSETS_README.md and its push loop).

**Built:**

- **Main menu** (`ui/main_menu.gd`, new main scene): black starfield sky under a
  living **aurora shader** (`ui/aurora_sky.gdshader` — emerald curtains overtaken
  by moody evil red in ~16s cycles), procedural **stormy castle silhouette**
  (crenellated towers) with **random lightning strikes** (jagged bolt + screen
  flash), "LIGHT'S EDGE — Part I of the Aurora Series" title treatment, and a
  drawn FF-style emblem (pale sun ringed by twin serpents, one emerald / one
  ember). Buttons: **Start** (→ fight select; becomes the world hub at M6),
  **Playtest** (jump-offs: Skirmish, Boss, disabled Town/Outside/Dungeon stubs
  awaiting M6), **Options** (master/music volume via bus, fullscreen toggle),
  **Quit**.
- **Asset pipeline** (`world/asset_library.gd` + `/assets` tree + ASSETS_README.md):
  convention-over-configuration — sprites/backgrounds/music resolve by exact
  documented paths with silent grey-box fallback. Naming: lowercase snake_case,
  trailing instance numbers shared ("Aether Wolf 2" → aether_wolf.png).
- **MusicManager autoload** (`world/music_manager.gd`): dedicated Music bus,
  crossfading two-player setup, loop-enabling per stream type, same-track no-op,
  silent no-op for missing files. Hooks: menu theme, battle/boss themes,
  optional `boss_release` on phase 3 and victory/defeat stings (only switch if
  the file exists, so missing tracks never kill running music).
- **Battle scene art hooks:** backdrop art (battle.png/boss.png) with the phase
  tint riding translucently on top so P1→P3 cues survive any art; combatant
  tokens swap their grey rect for `assets/sprites/characters/<name>.png` when
  present (hit-flash retargets the sprite); end overlay gains a Main Menu button;
  fight select gains a back-to-menu button.

**Test status:** `131/131 passed (957 asserts)` — headless, green; boots clean.
New coverage: naming convention, null-fallbacks with an empty /assets tree,
autoloaded MusicManager no-op safety + Music bus creation, main scene setting,
menu boots with 4 buttons + closed panels, battle scene boots with asset hooks.

**Deviations (logged):** main menu + options + music manager are slice-scope
extensions requested by the human (audio guardrail "silent or stub beeps"
remains true by default — real music only plays if the human supplies files).
3D port explicitly deferred until after M6/M7.

**Open:** waiting on the human's asset drop (Downloads → assets/ → push) to bind
real art; icons/ and tiles/ are reserved for the M6 world + a later UI-icon pass.

---

## Asset pass B — toolbox curation (art + music wired)

Human pushed a 26k-file / ~500MB toolbox into `assets/all files` ("pick what
fits, rename, ignore the rest"). Curated and wired this pass:

**Music (via new `assets/manifest.cfg` — maps logical names to toolbox files
with zero copying; AssetLibrary checks the manifest before convention paths):**
menu = "Stormfront" (K. MacLeod) · battle = "Fight Them Until We Cant"
(Zander Noriega) · boss = "Heroic Demise" (Matthew Pablo) · phase 3 =
"Black Vortex" · victory = "Discovery Hit" · defeat = "No More Magic" ·
reserved for M6: town/world/dungeon tracks. FLAC track skipped (Godot can't
import FLAC) — noted in CREDITS.

**Sprites:** party + merc cropped from the toolbox hero sheet via
`tools/crop_heroes.gd` (24×32 front-facing frames → bastil/cavene/jecht/mati/
church_lancer.png); enemies from the Dungeon Crawl Stone Soup set (CC0):
wolf→Aether Wolf, warg→Icebound Stag, ice_beast→Crystal Wolf,
frost_giant→Frozen Shepherd. Tokens render pixel art with NEAREST filtering,
integer upscale, bottom-aligned; grey-box rects remain the fallback.

**Backdrops:** ice-cavern parallax (background01) for both arenas via manifest;
phase tint rides translucently on top; NEAREST stretch.

**UI skin:** new `UiTheme` autoload builds a runtime Theme from Kenney's
UI Pack RPG (CC0) — brown panels, beige/blue/grey long buttons (normal/hover/
pressed/focus/disabled), ProgressBar backing — applied to the root window so
every menu/panel/button in the game is skinned at once; silently keeps the
default theme if the pack is absent.

**Housekeeping:** stripped __MACOSX shadow dirs + AppleDouble files and root
zips whose contents were already extracted (~13MB junk); `assets/CREDITS.txt`
records used-asset attribution (owner to verify items marked); ASSETS_README
documents the manifest. Lorc icon 7z left unextracted (no 7z in env). Reserved
for later passes: Ravenmore + Lorc icons (ability buttons), FireLoop/fireball
FX, town/terrain/overworld tilesets (M6), controller prompt packs, LPC pieces.

**Test status:** `133/133 passed (973 asserts)`; full 26k-asset import clean
(2m27s first pass); game boots clean. New coverage: manifest resolution,
curated sprite/backdrop/music lookups, root-window theme + textured button
skin, missing-asset fallbacks still null-safe.

**Deviations:** none beyond the already-logged asset-pass extension.

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

---

## Feedback pass — JRPG pointers, SFX everywhere, real battle FX (human-directed)

Playtest issues fixed + requested juice added:

- **Grey strip behind party (bug):** the hero sheet has an opaque flat background;
  `tools/crop_heroes.gd` now keys it out (corner-sample + tolerance) — re-cropped
  all five with true transparency (regression-guarded by test).
- **Yellow box on the active character (bug):** the old highlight ring drew OVER
  sprites. Ring removed entirely, replaced by the JRPG pointer system:
  **gold bouncing chevron** over whoever's turn it is, **crimson chevron** over the
  hovered target while choosing (driven by new `target_hovered` signal).
- **Grounding:** elliptical shadow under every combatant's feet; staggered
  FFX-style ranks for the party, arced enemy line, boss recentered.
- **SFX (new `SfxManager` autoload):** every UI/combat event now has a voice —
  hover/click on all menus, hit/crit/miss, fire/ice casts, heal, guard, pray,
  echo, status lands, resolve shock, delay, burn/bleed ticks. All sounds are
  **synthesized in code** (16-bit PCM recipes: tones/sweeps/noise bursts) so they
  work with zero files and are individually overridable by dropping
  `assets/audio/sfx/<name>.ogg`. Dedicated Sfx bus + options-menu volume slider
  (with audible preview).
- **Battle FX (`ui/battle_fx.gd`):** floating damage numbers (white/gold-crit/
  green-heal) on every HP change incl. DoT ticks and enemies; slash streaks for
  physical hits; elemental particle bursts (rising fire embers / falling ice
  shards / dark pulses for Darkness-cost casts); heal sparkles; guard ring;
  two-stage echo bursts; target shake; MISS / CRITICAL! / status-name /
  DELAYED / REFLECTED! text pops.
- Music note from playtest: first-fight silence couldn't be reproduced from
  here; boss/menu/victory confirmed working by the human. Watch whether the
  skirmish "battle" WAV plays on the next run — fallback swap to an mp3 track
  is a one-line manifest change if it stays silent.

**Test status:** `138/138 passed (1023 asserts)`; boots clean. New coverage:
all 16 SFX recipes synthesize real audio, autoload plays through the pool
without crashing, FX factories spawn nodes, hero-sprite corner transparency,
battle scene boots with the gold arrow locked to the active actor.

**Open:** harmless ObjectDB leak warning at forced quit (autoload audio
streams at exit) — cosmetic, headless-only.

---

## Cinematic combat pass (human-directed, post-checkpoint feel notes)

Human verdict on the feedback build: "sounds all working... it all felt good."
Asked for grander, slower, heavier presentation. Built:

- **Presenter pacing**: `CombatEncounter` gained optional async presenter gates —
  with no presenter attached every action resolves instantly (all logic tests
  stay synchronous; presenter also auto-disables headless). Boss script routed
  through the same gates. Action rhythm: stride in (0.28s) → declaration +
  windup hold → impact (all existing FX) → weight + follow hold → stride back.
  Basics ~2s, spells ~3s, **echoes ~5s with Engine.time_scale 0.55 slow-mo**,
  guard/pray brace backward instead.
- **Stone narrator** (`DeclarationBanner`): letterspaced stone slab center-stage
  declaring every action ("B A S T I L — O A T H F I R E  S T R I K E"), gold
  for party, red for enemies, crumble-fade on followthrough. Combat log moved
  to a corner history panel.
- **Screen weight**: stage layer (world shakes, UI doesn't), elemental
  full-screen flash tints, X-slash carving the screen on heavy hits (coeff
  ≥2.2 / echoes), per-hit stage shake scaled by gravity of the blow.
- **Blood & violence FX**: arterial spray on physical wounds (bigger on crits),
  lingering blood pools on kills, Options toggle (default on).
- **Controller**: ui_cancel (gamepad B / Esc) backs out of target selection;
  all menus already navigate via D-pad/stick + A through Godot's focus system.

## M6 — World: town, outside area, dungeon — BUILT, awaiting PLAYTEST CHECKPOINT 4

- **`WorldState` autoload**: run lifecycle (new/continue/reset), party meter
  persistence across scenes and battles, merc-hired flag, battle hand-off
  (pending roster + return scene/position), defeat retry penalty, save-point
  rest (drain Darkness, Resolve floor 75, write save), per-run flags
  (gauntlet cleared, boss cleared).
- **`PlayerAvatar`** (WASD/arrows/left stick, E/Enter/gamepad-A interact — new
  input map) + **`AreaBase`** scaffold: bounds, exits, interactables with
  prompts, sequential dialog, step-based random encounters.
- **Aethertown**: save crystal (rest+save), merc post (hire/dismiss the
  Lancer), shop stub, two lore NPCs, road to the fields.
- **Crystal Fields**: solid scenery, random encounters every ~260-430 walked px
  (rosters: wolves_2/wolves_3/stag_hunt/wolfpack), exits town/dungeon.
- **Crystal Site dungeon**: three zones — scripted gauntlet pack (once per
  run), memory crystal (M7 stub dialog), boss door → Frozen Shepherd; "slice
  complete" dialog after the boss falls.
- **Battle integration**: world battles consume the pending roster
  (`enemy_paths_for` compositions), pull meters from WorldState, include the
  merc only when hired; world end-overlay = Continue / Retry(−15) / Limp back
  to town(−15); boss victory sets `boss_cleared`. Standalone Playtest jumps
  unchanged. Main menu: **New Pilgrimage** (fresh run → town), **Continue**
  (from save), Playtest world spots now live.

**Test status:** `146/146 passed (1076 asserts)`; boots clean. New coverage:
run defaults, snapshot/apply round-trip, roster-wide retry penalty, rest+save
persistence (darkness drained, floor applied, file round-trip), pending-roster
hand-off, roster compositions, all three world scenes boot with a player, and
a world-mode battle honoring meters + merc flag + roster.

**▶ PLAYTEST CHECKPOINT 4 — what to test (`godot --path .` → New Pilgrimage):**

1. Walk town → fields → dungeon → boss; do exits/prompts/dialog read?
2. Random encounters in the fields: frequency feel? Battles return you to
   where you stood?
3. Save crystal: Darkness drained, Resolve restored, then quit → Continue
   resumes in town?
4. Hire the Lancer; does he appear in the next fight (and stay home if
   dismissed)?
5. Lose on purpose: Retry (−15 Resolve) and Limp-back-to-town both behave?
6. The cinematic layer: strides, stone declarations, X-slash, blood — grand
   without dragging? (Pacing knobs: `ActionPresenter.PACING`.)

---

## Expansion pass (owner-directed) — world depth, anime FX, Duty & Burden

Post-checkpoint-4 feedback build. Two explicit scope expansions ordered by the
owner and logged as deviations: **Duty & Burden meters** (plan deferred them;
GDD formulas used) and **consumable items** (HP/Aether potions). The sphere
grid remains OUT (no leveling system exists; EXP potions skipped as inert).

**Combat/system side:**
- **Duty & Burden live**: registered persistent meters on all party members
  (duty default 50, burden 0). Effects per GDD: damage ×1.00–1.25 by Duty,
  ×1.00→0.65 by Burden (both folded into LayerMod), speed ×1.00→0.55 by
  Burden, **Echo locked at Burden ≥80**, **Echo CT cost −40% at Duty 100**.
  Ally death: +10 Burden to survivors. Save-crystal rest eases Burden −15.
  Quests/dialogue nudge all four meters via `WorldState.adjust_party_meter`
  (Darkness only ever touches the Heirs). HUD shows DUTY (gold) + BUR rows.
- **Items**: `is_item`/`flat_heal`/`flat_aether` on AbilityData; HP Potion
  (120 HP) + Aether Draught (45 AE) as Item-cost (750 CT) actions in the
  battle menu (world runs), consumed from `WorldState.inventory`, persisted
  in saves with opened chests; starting kit 2+1.
- **Battle-start reactions** (enemy-type triggers): wolves shake Mati
  (Resolve −10), bandits steel Bastil (Duty +10), the Stag stirs Jecht's
  blood (Darkness +5) — logged lines + HUD movement.
- **New foes**: Roadside Bandit + Bandit Cutthroat (magicless raiders, bleed/
  delay kits, hero-sheet sprites) and Frost Wisp (fragile ice caster, DCSS
  wisp tile). New rosters: bandit_pair/bandit_ambush/wisp_pack.
- **Anime-scale magic staging** (`BattleFX.spell_cinematic`): additive-blend
  light layering — caster aura motes, a descending sky pillar of the element,
  expanding ground rings under the target, and a 70–110-mote storm; echoes get
  the big variant. Pacing slowed further (spells ~3.7s, echoes ~6s+slow-mo),
  shakes strengthened. **Per-spell synthesized sounds** for every named spell/
  echo (file-overridable by id, e.g. assets/audio/sfx/absolute_zero.ogg).
- **Stone UI**: all panels (log, timeline, HUD, menus, dialogs) now wear an
  opaque tiled cobblestone slab cropped from the toolbox cave terrain;
  Kenney buttons ride on top. Combat log opaque per feedback.
- **Debug exit** button in every battle (instant leave, no penalty/rewards).
- **Varied music**: skirmishes randomly pick battle / battle_alt (Redletter).

**World side:**
- **Scrolling maps + follow camera** (UI on a CanvasLayer). Town 1920×1280,
  fields 2560×1600.
- **Aethertown rebuilt with toolbox art**: tiled grass, dirt avenues, pine
  breaks, sprite houses (inn + tall homes), **two enterable homes** with
  furnished interiors + occupants, **Mercenary Post interior where the Lancer
  is actually hired/dismissed via choices**, shop stall stub, save crystal,
  3 roaming villagers with one-liner pools ("Move along, kid", the cat lady),
  **three choice-quests** that move the meters (the Letter, the Smuggler, the
  Festival Lie — each one-shot per run, gold "?" markers).
- **Crystal Fields rebuilt**: snow cliffs crowning the north, pine woods,
  scattered rocks/icicles, a **frozen river fed by a particle waterfall with
  mist pool**, and **7 visible patrolling foes** (wolves/stag/bandits/wisps)
  with aggro radius 185 / leash 360 — chase, give up, walk home; "!" + sting
  on aggro; defeated foes stay gone for the run. **Random encounters removed.**
- Treasure chests (toolbox crate sprite): 2 town, 2 fields, 1 dungeon —
  open once per run, loot persisted.

**Test status:** `157/157 passed (1141 asserts)`; boots clean. New coverage:
duty/burden curves + speed drag + echo lock/discount, flat-restore items +
inventory + save round-trip (incl. duty/burden/chests), wolf/bandit reactions,
foe state machine (aggro/leash/return/resume), quest nudges (heir-only
darkness, clamping), new enemy/roster files.

**Numbers I chose (tunable):** duty/burden deltas above; foe aggro 185 / leash
360; potion 120 HP / draught 45 AE; starting kit 2/1; burden relief 15/rest.

---

## Deep polish pass (post-expansion playtest feedback)

- **4-direction walk animation**: `tools/crop_walks.gd` cut all 84 frames
  (7 humans × 4 dirs × 3 frames) from the hero sheet; `AssetLibrary.walk_frames`
  builds cached SpriteFrames; new `WalkerSprite` (AnimatedSprite2D) watches its
  parent's motion and plays walk/idle per facing. Player avatar, town roamers,
  and bandit map-foes all turn properly now; single-tile beasts flip to face
  their motion. NPC fronts finally exist.
- **Combat menus are pure keyboard/controller**: WASD merged into ui_up/down/
  left/right (arrows + D-pad + stick kept); ActionMenu rebuilt as an **FF-style
  folder menu** — root: Attack / Magic ▸ / Skills ▸ / Items ▸ / Echo / Guard /
  Pray; folders list contents with a Back entry; B/Esc backs out; focus lands
  on the first entry of every page; the panel re-anchors per page.
  Supports (heals/rally) file under Magic, weapon arts under Skills, items
  show counts and only inside their folder.
- **FX louder still**: FF-style **summoning glyph** (twin counter-rotating arc
  rings) under casters, pillar wider + brighter (130/190px), storms 100/160
  motes, scale up — layered with the existing aura/rings/X-slash/shake stack.
- **Burden finally bites in play**: at ≥50 every action's CT cost +15% with a
  "moves heavily" log line; HUD BUR bar burns red at the threshold; reactions
  buffed (Mati −15 Resolve vs wolves, Bastil +12 Duty vs bandits); quest
  swings raised (±8–15 range).
- **Quests truly once-only**: committed the moment the choice sheet opens
  (no re-roll by re-talking), markers vanish, and `quests_done` now persists
  through saves.
- **Landscape pass on the Crystal Fields**: contiguous cliff rampart sealing
  the whole north edge, southern low-cliff ridge, real forest WALLS (west wood
  + mid grove + eastern skirt), a worn pilgrim trail from gate to gate with
  fence posts, ground mottling (soft light/dark patches kill the flat snow),
  rock/icicle clusters near landmarks. Brighter snow base.
- **Character menu** (`CharacterMenuOverlay`, C / gamepad Y in any area): a
  stone card per member — portrait, class/element, all ten stats, and every
  meter with band + plain-words effect text (Burden card turns red and warns
  of the Echo lock). Merc card appears only while hired.
- Battle foes render 1.3× with wider rank spacing (fully visible bodies).

**Test status:** `161/161 passed (1204 asserts)`; boots clean. New coverage:
walk-frame sets for all seven humans (and null for beasts), menu folder
categorization (supports→Magic, arts→Skills, echo stays root), burden drag
threshold, character menu overlay boot, updated reaction values.

**Still parked for M7:** the Memory Echo at the dungeon crystal (per the
human: "wait for the memory at the dungeon").

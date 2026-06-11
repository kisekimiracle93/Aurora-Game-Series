# Asset drop-in guide

The game looks for files at the exact paths below. **Drop a file in → it appears in
game. Delete it → grey-box returns.** No code changes needed. Missing files are
always safe (silent fallback).

Supported formats — images: `png` `jpg` `jpeg` `webp` · audio: `ogg` (best) `mp3` `wav`

## Where to put what

```
assets/
  sprites/
    characters/        # battle sprites, one per combatant (~256-512px tall reads well)
      bastil.png
      cavene.png
      jecht.png
      mati.png
      church_lancer.png
      aether_wolf.png      # shared by "Aether Wolf 1/2/3..."
      icebound_stag.png
      crystal_wolf.png
      frozen_shepherd.png
    backgrounds/
      menu.png         # title screen sky/castle art (1280x720; aurora shader overlays it)
      battle.png       # skirmish arena backdrop (1280x720)
      boss.png         # Frozen Shepherd arena backdrop (1280x720)
    icons/             # reserved: rpg/controller icon packs land here (wired in a later pass)
    tiles/             # reserved: grass/stone/etc tilesets for the M6 world
  audio/
    music/
      menu.ogg         # title theme
      battle.ogg       # skirmish theme
      boss.ogg         # Frozen Shepherd theme
      boss_release.ogg # optional: phase 3 escalation (falls back to boss.ogg)
      victory.ogg      # optional: end-of-battle sting
      defeat.ogg       # optional
    sfx/               # reserved: hit/heal/freeze blips (wired in a later pass)
```

Naming rule: lowercase, spaces → underscores, apostrophes dropped
("Church Lancer" → `church_lancer.png`). Trailing numbers are ignored so all
Aether Wolves share one sprite.

## How to send me your files (from your PC)

Copy files from Downloads into the matching folders inside your
`Desktop\aurora-slice\assets\` clone, then:

```powershell
cd $env:USERPROFILE\Desktop\aurora-slice
git add assets
git commit -m "Asset drop: art + music"
git push origin claude/loving-goodall-4ob9vx
```

That pushes them to the repo I work from — tell me they're up and I'll pull,
wire anything that needs custom treatment, retune sizes, and push back.

## Licensing note

Keep a `CREDITS.txt` inside `/assets` listing where each pack came from
(author + license, e.g. CC0/CC-BY) so attribution ships with the game.

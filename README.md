<div align="center">

<img src="Henge/Media/logo.png" alt="Henge" width="200">

<h1>Henge</h1>

<p>Graphics presets for World of Warcraft, swapped with one click, per location and per character.</p>

<p>
  <a href="https://github.com/yunodu/henge/releases/latest">Download</a>
  ·
  <a href="#what-it-does">What it does</a>
  ·
  <a href="#commands">Commands</a>
  ·
  <a href="Henge/CHANGELOG.md">Changelog</a>
</p>

</div>

Henge saves your graphics settings as presets for Retail and WoW Forever. Swap them from the window or a macro, and let Henge pick one per location or per character.

## What it does

- **Presets**: save your current graphics settings under a name, apply any preset with one click, update or delete your own. "FPS Settings" and "Inari Graphics" are built in. Your settings from before the first login are kept as "Original Settings".
- **Locations**: choose a preset for Open World, Dungeon and Raid. Henge switches when you arrive there or log in. Dungeon also covers delves, scenarios and arenas; Raid also covers battlegrounds.
- **Characters**: a character follows the account locations unless you give it its own.

Henge writes settings only when you swap a preset, log in, or change location. A preset you pick by hand stays until the kind of location changes. If the Open World location has no preset, leaving an instance brings back what you had before you entered.

## What a preset holds

The sliders on Blizzard's Graphics page, render scale, vertical sync and background FPS, plus the engine settings that graphics tweak addons commonly change (ground clutter, draw distances, shadows, water, fog, particles). Settings your game client does not have are skipped.

Window mode, resolution, monitor, HDR and anti-aliasing are never touched. Blizzard's separate raid and battleground graphics are turned off whenever a preset is applied, so the preset you see is the one in effect.

## Commands

| Command | Effect |
|---|---|
| `/henge` | open or close the window |
| `/henge next` | switch to the next preset |
| `/henge <name>` | apply a preset (`fps`, `inari`, or one of yours) |
| `/henge save <name>` | save the current settings as a preset |
| `/henge delete <name>` | delete one of your presets |
| `/henge set world\|dungeon\|raid <name>` | set the preset for a location (`none` clears it) |
| `/henge list` | show the current preset, all presets and the locations |

Henge is also in the minimap addon dropdown.

## Install

Copy the `Henge` folder into `Interface/AddOns` of your game install.

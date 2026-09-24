# GearDelta

GearDelta shows structured stat changes when you hover over equippable items in World of Warcraft: Forever. It does not score items or recommend upgrades.

The comparison identifies the equipped item or items used as the baseline. For example, a two-handed weapon can be compared against the currently equipped one-handed weapon **and** shield. Rings and trinkets are shown as separate possible replacements when Blizzard supplies both alternatives.

Only numeric item stats exposed through Blizzard's item API are included. This can include damage per second when the API provides it. Raw weapon damage, attack speed, use effects, procs, unusual equip effects, set effects, buffs, and talent effects are not evaluated. Blizzard's original tooltips remain visible.

## Status

Version 0.1.0 targets the WoW Forever beta client with interface version `16001`. A one-handed weapon comparison has been observed in-game. Two-handed weapon, shield, ring, and trinket comparisons still need in-game validation. Do not distribute this version as a CurseForge release yet.

## Install for testing

Put the `GearDelta` folder in `World of Warcraft/_classic_beta_/Interface/AddOns/`, then enable it in the game's AddOns list. The folder must contain `GearDelta.toc` and `GearDelta.lua` directly.

## Release packaging

A future CurseForge ZIP should contain exactly one top-level `GearDelta` folder. Tag the release for the Forever flavor and the tested game version. Recheck the interface number and finish in-game validation before publishing.

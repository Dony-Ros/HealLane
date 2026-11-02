# HealLane

HealLane is a healer addon for World of Warcraft that provides configurable unit frames and click casting. If you have used HealBot, the general idea may feel familiar, but HealLane is a newly created addon, not a port or copy of HealBot.

The interface is intentionally simpler than addons with extensive skin editors. Its default layout is inspired by the familiar HealBot-style unit-frame layout, with practical healing tools and straightforward options.

## Features

- Click-cast spells, macros, and unit actions using mouse buttons and modifier keys.
- Track configured healing-over-time effects (HoTs) on party and raid members.
- Monitor selected buffs and highlight units that are missing them.
- Show debuffs and configure smart dispels for supported debuff types.
- Smart Cast can cast a configured resurrection spell when clicking a dead unit, or a configured buff or dispel when appropriate.
- Display party and raid health frames with configurable layout, health text, role and raid-target icons, range fading, and optional incoming-heal indicators.

## Installation

1. Copy the `HealLane` folder into your WoW `Interface/AddOns` directory.
2. Make sure `HealLane.toc` is directly inside that folder.
3. Restart the game or use `/reload` in-game, then enable HealLane from the AddOns menu if needed.

This version targets the WoW 3.3.0 interface (`30300`).

## Getting started

- Type `/heallane` or `/hl` to open or close the configuration.
- In **Clicks**, choose a modifier and assign an action to each mouse button. Unassigned left-click targets and right-click opens the unit menu by default.
- In **HoTs**, add the spells you want to track.
- In **Buffs**, add buffs to monitor; missing buffs can be highlighted and handled by Smart Cast.
- In **Cure**, add dispel spells and select the debuff types each spell can remove.
- Configure the resurrection spell in **Clicks**. Smart Cast is enabled by default and can be changed in **General**.
- Type `/hlreset` to reset HealLane settings.

Settings are saved per character.

## Project status

HealLane is still early in development and has not been extensively battle-tested. It has been used in a few dungeons and worked as intended, but bugs and compatibility issues are possible. Please test it before relying on it in important content.

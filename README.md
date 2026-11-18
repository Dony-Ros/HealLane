# HealLane
HealLane is a healer addon for World of Warcraft that provides configurable unit frames and click casting. If you have used HealBot, the general idea may feel familiar, but HealLane is a newly created addon, not a port or copy of HealBot.
The interface is intentionally simpler than addons with extensive skin editors. Its default layout is inspired by the familiar HealBot-style unit-frame layout, with practical healing tools and straightforward options.
## Features
- Click-cast spells, macros, and unit actions using mouse buttons and modifier keys, with optional per-click spell rank selection and automatic rank lowering for supported spells on low-level units.
- Track configured healing-over-time effects (HoTs) on party and raid members.
- Monitor selected buffs and highlight units that are missing them.
- Show debuffs and configure smart dispels for supported debuff types.
- Smart Cast can cast a configured resurrection spell when clicking a dead unit, or a configured buff or dispel when appropriate.
- Display party and raid health frames with configurable layout, health text, role and raid-target icons, range fading, and optional incoming-heal indicators.
## Installation
1. Copy the `HealLane` folder into your WoW `Interface/AddOns` directory.
2. Make sure `HealLane.toc` is directly inside that folder.
3. Restart the game or use `/reload` in-game, then enable HealLane from the AddOns menu if needed.
This version supports the WoW Forever v1.60.1.70790 interface (`16001`), as well as interface versions `20506`, `50504`, and `120105`. Legacy and current WoW API differences are handled through compatibility helpers.
## Getting started
- Type `/heallane` or `/hl` to open or close the configuration.
- In **Clicks**, choose a modifier and assign an action to each mouse button. Spell assignments default to max rank; use the adjacent rank menu to choose a specific rank. The optional auto-downrank setting uses the inferred rule that a target can receive a spell rank learned up to 10 levels above their level. It is off by default, only covers spells in the built-in WoW: Forever table, and updates secure click bindings out of combat; unlisted spells keep their configured rank.
- In **HoTs**, add the spells you want to track.
- In **Buffs**, add buffs to monitor; missing buffs can be highlighted and handled by Smart Cast.
- In **Cure**, add dispel spells and select the debuff types each spell can remove.
- In **Debuffs**, add spell IDs to ignore; ignored auras do not show an icon or affect the bar color.
- Configure the resurrection spell in **Clicks**. Smart Cast is enabled by default and can be changed in **General**.
- Type `/hlreset` to reset HealLane settings.
On clients that provide Blizzard's native `AuraContainer`, HealLane uses the game-managed aura display to show configured HoT icons in application order. The icons reflow as HoTs expire, and their duration text shows whole numbers without unit labels. The health bar changes color for configured dispellable debuffs during combat, for low health, and when the unit has aggro. The **Debuffs** tab can exclude unwanted aura spell IDs from both the icon and bar-color behavior. This avoids reading restricted aura data in combat. If the client does not provide `AuraContainer`, aura scans remain out of combat only, and the aura display may be stale until combat ends. Missing-buff checks and Smart Cast also continue to use their existing out-of-combat scanning behavior.
Settings are saved per character.
## Project status
HealLane is still early in development and has not been extensively battle-tested. It has been used in a few dungeons and worked as intended, but bugs and compatibility issues are possible. Please test it before relying on it in important content.

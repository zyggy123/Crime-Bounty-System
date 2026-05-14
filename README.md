<p align="center">
  <img src="https://github.com/zyggy123/Crime-Bounty-System/blob/main/icon.png" width="200" />
</p>
# Crime & Bounty System

**AzerothCore Eluna module** — WoTLK 3.3.5a

Adds a wanted level system that tracks in-game crimes and sends NPC bounty hunters after offending players. Wanted levels persist in the database across logouts and server restarts.

---

## Features

- **Wanted Level** (1–5 stars) — increases when a player:
  - Kills a low-level player (≥10 levels difference)
  - Kills a civilian NPC (faction 35, level ≤50)
  - Camps the same player repeatedly
- **Persistent Database** — wanted level is saved to `crime_system_players` and survives logouts / server restarts
- **Bounty Hunters** — NPCs spawn near the wanted player (more at higher levels)
  - Level 1: 1 normal hunter
  - Level 2: 2 normal hunters
  - Level 3: 2 normal + 1 elite
  - Level 4: 2 normal + 2 elite
  - Level 5: 3 normal + 2 elite + 1 captain
- **PvP Bounty** — an enemy faction player who kills a wanted player receives their bounty gold
- **No decay** — wanted level only clears on death (by player or hunter), it never decays over time
- **Configurable** — all values can be tweaked in the `CONFIG` table at the top of the Lua file

---

## Installation

1. **Copy the Lua file** into your `lua_scripts/` directory:

   ```
   lua_scripts/crime_bounty_system.lua
   ```

2. **Import the SQL** into your **world** database:

   ```sql
   SOURCE path/to/crime_bounty_system.sql
   ```

3. **Restart your world server**.

---

## Configuration

Open `crime_bounty_system.lua` and edit the `CONFIG` table near the top:

| Setting | Default | Description |
|---------|---------|-------------|
| `Debug` | `false` | Print debug messages to worldserver console |
| `MaxWantedLevel` | `5` | Maximum wanted stars |
| `BountyPerStar` | `500000` | Gold per star (in copper). `500000` = 50 gold |
| `EnablePvPBounty` | `true` | Allow enemy players to claim bounty by killing a wanted player |
| `EnableNpcHunterClear` | `true` | Allow bounty hunter NPCs to clear wanted level on death |
| `CampingWindow` | `300` | Seconds before camping counter resets (5 min) |
| `CampingThreshold` | `3` | Kills within the same zone+window to trigger camping |
| `LowLevelDiff` | `10` | Level difference to consider a kill "low level" |
| `HunterSpawnChancePerStar` | `20` | % chance per star for hunters to spawn (level 5 = 100%) |
| `HunterSpawnTable` | _(see Lua)_ | Which NPCs and how many spawn per wanted level |

---

## How it works

```
Player kills low-level / civilian  ──►  Wanted +1 level
Player camps same victim           ──►  Wanted +1 level
Wanted player dies to enemy player ──►  Killer gets bounty, wanted cleared
Wanted player dies to bounty hunter ──►  Wanted cleared
```

Wanted data is saved to `crime_system_players` in the **world** database.

---

## NPC Entries

| Entry | Name | Rank | Level |
|-------|------|------|-------|
| 900010 | Bounty Hunter | Normal | 80 |
| 900011 | Bounty Hunter Elite | Elite | 82 |
| 900012 | Bounty Hunter Captain | Boss | 85 |

All use display ID 50 (Human Male) with varying scales (1.0, 1.1, 1.3).

---

## File Structure

```
CrimeBountySystem/
├── crime_bounty_system.lua    # Main Eluna script
├── crime_bounty_system.sql    # World database SQL
└── README.md                  # This file
```

---

## Requirements

- [AzerothCore](https://github.com/AzerothCore/azerothcore-wotlk) with [mod-eluna](https://github.com/azerothcore/mod-eluna)
- WoTLK 3.3.5a
- Lua engine must expose `WorldDBExecute`, `WorldDBQuery`, `PerformIngameSpawn`, `ModifyMoney`

---

## License

This project is licensed under the MIT License — feel free to use, modify and distribute.

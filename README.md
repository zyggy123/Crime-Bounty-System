<p align="center">
  <img src="https://github.com/zyggy123/Crime-Bounty-System/blob/main/icon.png" width="200" />
</p>
# Crime & Bounty System

An **Eluna module** for **AzerothCore** (WoTLK 3.3.5a) that adds a wanted level, bounty rewards and NPC bounty hunters to punish in-game crimes.

> Wanted levels persist in the database across logouts and server restarts. There is no decay — only death clears it.

---

## Features

- **Wanted Level** (1–5 stars) — increases when a player:
  - Kills a player ≥10 levels lower
  - Kills a civilian NPC (faction 35, level ≤50)
  - Camps the same player repeatedly (3+ kills within 5 min in the same zone)
- **Bounty Hunters** — NPCs spawn near the wanted player immediately upon each star increase:

  | Stars | Spawn |
  |-------|-------|
  | ⭐ | 1 Bounty Hunter (Normal) |
  | ⭐⭐ | 2 Bounty Hunters (Normal) |
  | ⭐⭐⭐ | 2 Normal + 1 Elite |
  | ⭐⭐⭐⭐ | 2 Normal + 2 Elite |
  | ⭐⭐⭐⭐⭐ | 3 Normal + 2 Elite + 1 Captain |

- **PvP Bounty** — an enemy faction player who kills a wanted player receives their bounty gold
- **Bounty Board** — NPC (entry `900013`) that lists wanted players from the opposing faction with their level and bounty
- **Fully configurable** — tweak everything in the `CONFIG` table inside the Lua file
- **No decay** — wanted level never decreases over time. Only death clears it.

---

## Installation

1. **Copy the Lua file** into your `lua_scripts/` folder:

   ```
   lua_scripts/crime_bounty_system.lua
   ```

2. **Run the SQL** in your **world database**:

   ```sql
   SOURCE path/to/crime_bounty_system.sql
   ```

3. **Restart the world server.**

4. (Optional) Spawn the Bounty Board NPC in-game:

   ```
   .npc add 900013
   ```

---

## Configuration

Open `crime_bounty_system.lua` and edit the `CONFIG` table (lines 16–58):

| Setting | Default | Description |
|---------|---------|-------------|
| `Debug` | `false` | Print debug messages to the worldserver console |
| `MaxWantedLevel` | `5` | Maximum wanted stars |
| `BountyPerStar` | `500000` | Bounty gold per star (in copper). `500000` = 50 gold |
| `EnablePvPBounty` | `true` | Allow enemy players to claim bounty by killing a wanted player |
| `EnableNpcHunterClear` | `true` | Allow bounty hunter NPCs to clear wanted level on death |
| `CampingWindow` | `300` | Seconds before the camping counter resets (5 min) |
| `CampingThreshold` | `3` | Kills within the same zone+window to trigger camping |
| `LowLevelDiff` | `10` | Level difference to consider a kill "low level" |
| `HunterSpawnChancePerStar` | `100` | % per star. `100` = always spawn, `20` = 20% at level 1 (random) |
| `HunterSpawnTable` | *(see snippet below)* | Which NPCs and how many spawn per wanted level |

### Hunter spawn table

```lua
HunterSpawnTable = {
    [1] = { {900010, 1} },                          -- 1 normal hunter
    [2] = { {900010, 2} },                          -- 2 normal hunters
    [3] = { {900010, 2}, {900011, 1} },             -- 2 normal + 1 elite
    [4] = { {900010, 2}, {900011, 2} },             -- 2 normal + 2 elite
    [5] = { {900010, 3}, {900011, 2}, {900012, 1} },-- 3 normal + 2 elite + 1 captain
}
```

Each entry is `{npc_entry, count}`. You can add more entries or change counts freely.

---

## NPC Entries

| Entry | Name | Level | Faction | Rank | Display ID |
|-------|------|-------|---------|------|-----------|
| 900010 | Bounty Hunter | 80 | Hostile (14) | Normal | 448 |
| 900011 | Bounty Hunter Elite | 82 | Hostile (14) | Elite | 534 |
| 900012 | Bounty Hunter Captain | 85 | Hostile (14) | Boss | 50 |
| 900013 | Bounty Board | 1 | Friendly (35) | — | 647 |

### Changing NPC display / appearance

To give a hunter or the bounty board a different look, edit the `CreatureDisplayID` in **two places**:

**1. The SQL file** `crime_bounty_system.sql` — change the value in the `INSERT INTO creature_template_model` statements:

```sql
-- Example: change Bounty Hunter (900010) to an Orc Male (display 175)
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`) VALUES
(900010, 0, 175, 1.0, 1),   -- was 448
```

**2. Run the updated SQL** or run this ALTER directly:

```sql
-- Change a single NPC's display on-the-fly (no restart needed after cache clear)
REPLACE INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`)
VALUES (900011, 0, 411, 1.0, 1);  -- new display ID for Elite

-- Clear the creature cache so the new model takes effect
DELETE FROM `creature_cache`;
```

Find display IDs on [WoW.tools](https://wow.tools/dbc/?dbc=creaturedisplayinfo) or by browsing NPCs in-game (use `.npc info` with a target).

### Scaling

The `DisplayScale` column controls size:
- `1.0` = normal
- `1.1` = slightly larger
- `1.3` = noticeably bigger

You can mix any display ID with any scale.

---

## How it works

```
Player kills low level or civilian  ──►  Wanted +1 star  ──►  Hunters spawn
Player camps same victim            ──►  Wanted +1 star  ──►  More hunters spawn
Wanted player dies to enemy         ──►  Killer gets bounty   ──►  Wanted cleared
Wanted player dies to hunter        ──►  Wanted cleared       ──►  Bounty lost
```

Data is stored in the `crime_system_players` table in the **world** database (auto-created by the Lua script).

---

## File structure

```
CrimeBountySystem/
├── crime_bounty_system.lua      # Main Eluna script
├── crime_bounty_system.sql      # World database SQL (NPCs + models)
└── README.md                    # This file
```

---

## Requirements

- [AzerothCore](https://github.com/AzerothCore/azerothcore-wotlk) with [mod-eluna](https://github.com/azerothcore/mod-eluna)
- WoTLK 3.3.5a
- Lua engine must expose: `WorldDBExecute`, `WorldDBQuery`, `PerformIngameSpawn`, `ModifyMoney`

---

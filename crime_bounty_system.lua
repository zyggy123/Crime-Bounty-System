-- Crime & Bounty System for AzerothCore (Eluna) - WoTLK 3.3.5a
-- Description: Wanted level, bounty and NPC bounty hunters for crimes
-- All settings are in the CONFIG table below.

local CrimeSystem = {
    WantedData = {}, -- [guid] = {level, bounty, lastCrime}
    CampData   = {}, -- [killerGuid] = {[victimGuid] = {kills, lastKill, zoneId}}
}

-- Wanted level persists indefinitely until the player is killed.
-- It does NOT decay over time, only death clears it.

-- ============================
-- CONFIG - EDIT THESE VALUES
-- ============================
local CONFIG = {
    -- Debug mode: prints extra info to worldserver console
    Debug               = false,

    -- Max wanted level (stars)
    MaxWantedLevel      = 5,

    -- Bounty gold per star (in copper). 500000 = 50 gold.
    BountyPerStar       = 500000,

    -- PvP Bounty: if true, an enemy player who kills a wanted player receives the bounty gold.
    EnablePvPBounty     = true,

    -- NPC Hunter Clear: if true, dying to a Bounty Hunter NPC clears your wanted level.
    EnableNpcHunterClear= true,

    -- Camping detection
    CampingWindow       = 300,        -- 5 min window for camping detection
    CampingThreshold    = 3,          -- kills before flagged as camping

    -- Low level kill detection
    LowLevelDiff        = 10,         -- levels difference for low-level kill

    -- Civilian NPC detection
    CiviliansFaction    = 35,         -- Friendly faction
    CiviliansMaxLevel   = 50,

    -- Hunter spawn chance per tick (percentage per star)
    -- Example: level 1 = 20%, level 5 = 100%
    HunterSpawnChancePerStar = 20,

    -- Hunter entries per wanted level.
    -- Each level can spawn multiple hunters (e.g. 2 normal hunters at level 2).
    -- Format: [wantedLevel] = { {entry, count}, {entry, count}, ... }
    HunterSpawnTable = {
        [1] = { {900010, 1} },                          -- 1 normal hunter
        [2] = { {900010, 2} },                          -- 2 normal hunters
        [3] = { {900010, 2}, {900011, 1} },             -- 2 normal + 1 elite
        [4] = { {900010, 2}, {900011, 2} },             -- 2 normal + 2 elite
        [5] = { {900010, 3}, {900011, 2}, {900012, 1} },-- 3 normal + 2 elite + 1 captain
    },
}

-- ============================
-- DEBUG HELPER
-- ============================
local function Log(msg)
    if CONFIG.Debug then
        print("[CRIME] " .. msg)
    end
end

-- ============================
-- DATABASE (World DB)
-- ============================
local function DB_Init()
    WorldDBExecute([[
        CREATE TABLE IF NOT EXISTS `crime_system_players` (
            `guid` INT UNSIGNED NOT NULL,
            `wanted_level` TINYINT UNSIGNED NOT NULL DEFAULT 0,
            `bounty` INT UNSIGNED NOT NULL DEFAULT 0,
            `last_crime` INT UNSIGNED NOT NULL DEFAULT 0,
            PRIMARY KEY (`guid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
end

local function DB_Load(guid)
    local result = WorldDBQuery("SELECT wanted_level, bounty, last_crime FROM crime_system_players WHERE guid = " .. guid)
    if result then
        return {
            level     = result:GetUInt32(0),
            bounty    = result:GetUInt32(1),
            lastCrime = result:GetUInt32(2)
        }
    end
    return nil
end

local function DB_Save(guid, data)
    WorldDBExecute(string.format(
        "REPLACE INTO crime_system_players (guid, wanted_level, bounty, last_crime) VALUES (%d, %d, %d, %d)",
        guid, data.level, data.bounty, data.lastCrime
    ))
end

local function DB_Clear(guid)
    WorldDBExecute("DELETE FROM crime_system_players WHERE guid = " .. guid)
end

-- ============================
-- WANTED LEVEL LOGIC
-- ============================
function CrimeSystem.AddWantedLevel(player, amount)
    Log("AddWantedLevel called for " .. player:GetName() .. " amount=" .. amount)
    local guid = player:GetGUIDLow()
    if not CrimeSystem.WantedData[guid] then
        CrimeSystem.WantedData[guid] = {level = 0, bounty = 0, lastCrime = 0}
    end

    local data = CrimeSystem.WantedData[guid]
    data.level = math.min(data.level + amount, CONFIG.MaxWantedLevel)
    data.bounty = data.level * CONFIG.BountyPerStar
    data.lastCrime = os.time()

    DB_Save(guid, data)
    Log("Saved to DB: guid=" .. guid .. " level=" .. data.level .. " bounty=" .. data.bounty)

    player:SendBroadcastMessage(
        string.format("|cFFFF0000[WANTED] Level %d/%d | Bounty: %d gold|r", data.level, CONFIG.MaxWantedLevel, data.level * 50)
    )

    CrimeSystem.TrySpawnHunter(player, data.level)
end

function CrimeSystem.ClearWantedLevel(player)
    local guid = player:GetGUIDLow()
    CrimeSystem.WantedData[guid] = nil
    DB_Clear(guid)
    Log("Wanted level cleared for guid=" .. guid)
end

-- ============================
-- BOUNTY HUNTERS
-- ============================
function CrimeSystem.TrySpawnHunter(player, wantedLevel)
    local chance = wantedLevel * CONFIG.HunterSpawnChancePerStar
    if math.random(1, 100) > chance then
        return
    end

    local spawnList = CONFIG.HunterSpawnTable[wantedLevel] or CONFIG.HunterSpawnTable[1]
    local x, y, z = player:GetLocation()
    local mapId = player:GetMapId()
    local instanceId = player:GetInstanceId()
    local o = player:GetO()

    for _, spawnInfo in ipairs(spawnList) do
        local entry = spawnInfo[1]
        local count = spawnInfo[2]
        for i = 1, count do
            local offsetX = math.random(-20, 20)
            local offsetY = math.random(-20, 20)
            PerformIngameSpawn(1, entry, mapId, instanceId, x + offsetX, y + offsetY, z, o, false, 300, 1)
        end
    end

    player:SendBroadcastMessage("|cFFFF0000A bounty hunter has tracked you down!|r")
    Log("Spawned hunters for wanted level " .. wantedLevel)
end

-- ============================
-- CAMPING TRACKER
-- ============================
function CrimeSystem.TrackCamping(killer, victim)
    local killerGuid = killer:GetGUIDLow()
    local victimGuid = victim:GetGUIDLow()

    if not CrimeSystem.CampData[killerGuid] then
        CrimeSystem.CampData[killerGuid] = {}
    end

    local now = os.time()
    local zoneId = killer:GetZoneId()
    local info = CrimeSystem.CampData[killerGuid][victimGuid]

    if info then
        if (now - info.lastKill) < CONFIG.CampingWindow and info.zoneId == zoneId then
            info.kills = info.kills + 1
            if info.kills >= CONFIG.CampingThreshold then
                CrimeSystem.AddWantedLevel(killer, 1)
                killer:SendBroadcastMessage(
                    string.format("|cFFFF0000You are camping %s! Wanted level increased!|r", victim:GetName())
                )
            end
        else
            info.kills = 1
            info.zoneId = zoneId
        end
        info.lastKill = now
    else
        CrimeSystem.CampData[killerGuid][victimGuid] = {kills = 1, lastKill = now, zoneId = zoneId}
    end
end

-- ============================
-- CIVILIAN CHECK
-- ============================
local function IsCivilianNPC(creature)
    if not creature then return false end
    local faction = creature:GetFaction()
    local level   = creature:GetLevel()
    return (faction == CONFIG.CiviliansFaction and level <= CONFIG.CiviliansMaxLevel)
end

-- ============================
-- EVENT HANDLERS
-- ============================
local function OnPlayerKillPlayer(event, killer, killed)
    Log("OnPlayerKillPlayer: killer=" .. killer:GetName() .. " killed=" .. killed:GetName())
    if killer:GetGUIDLow() == killed:GetGUIDLow() then
        return
    end

    -- ========== BOUNTY CLAIM (PvP) ==========
    if CONFIG.EnablePvPBounty then
        local killedGuid = killed:GetGUIDLow()
        local killedData = CrimeSystem.WantedData[killedGuid]
        if not killedData then
            killedData = DB_Load(killedGuid)
            if killedData then CrimeSystem.WantedData[killedGuid] = killedData end
        end
        if killedData and killedData.level > 0 then
            local pTeam = killer:GetTeam()
            local kTeam = killed:GetTeam()
            if pTeam ~= kTeam then
                Log("Bounty claimed by " .. killer:GetName() .. " from " .. killed:GetName())
                killer:ModifyMoney(killedData.bounty)
                killer:SendBroadcastMessage(
                    string.format("|cFF00FF00[BOUNTY] You claimed a bounty of %d gold from %s!|r", killedData.level * 50, killed:GetName())
                )
                killed:SendBroadcastMessage("|cFF00FF00[WANTED] An enemy has claimed your bounty. Wanted level cleared.|r")
                CrimeSystem.ClearWantedLevel(killed)
                return
            end
        end
    end

    -- Low level kill
    local diff = killer:GetLevel() - killed:GetLevel()
    if diff >= CONFIG.LowLevelDiff then
        CrimeSystem.AddWantedLevel(killer, 1)
        killer:SendBroadcastMessage("|cFFFF0000[WANTED] You killed a low level player! Wanted level increased!|r")
    end

    -- Camping check
    CrimeSystem.TrackCamping(killer, killed)
end

local function OnPlayerKillCreature(event, killer, killed)
    Log("OnPlayerKillCreature: killer=" .. killer:GetName() .. " creature=" .. killed:GetName() .. " entry=" .. killed:GetEntry())
    if IsCivilianNPC(killed) then
        CrimeSystem.AddWantedLevel(killer, 1)
        killer:SendBroadcastMessage("|cFFFF0000[WANTED] You killed a civilian NPC! Wanted level increased!|r")
    end
end

local function OnPlayerLogin(event, player)
    local guid = player:GetGUIDLow()
    Log("OnPlayerLogin: " .. player:GetName() .. " (GUID: " .. guid .. ")")
    local data = DB_Load(guid)
    if data and data.level > 0 then
        CrimeSystem.WantedData[guid] = data
        player:SendBroadcastMessage(
            string.format("|cFFFF0000[WANTED] You are still wanted! Level %d/%d | Bounty: %d gold|r", data.level, CONFIG.MaxWantedLevel, data.level * 50)
        )
        Log("Loaded wanted level " .. data.level .. " from DB")
    end
end

local function OnPlayerLogout(event, player)
    local guid = player:GetGUIDLow()
    local data = CrimeSystem.WantedData[guid]
    if data then
        DB_Save(guid, data)
    end
    CrimeSystem.CampData[guid] = nil
end

-- ============================
-- BOUNTY HUNTER TARGETING
-- ============================
local function OnHunterSpawn(event, creature)
    local entry = creature:GetEntry()
    local isHunter = false
    for _, spawnList in pairs(CONFIG.HunterSpawnTable) do
        for _, info in ipairs(spawnList) do
            if entry == info[1] then
                isHunter = true
                break
            end
        end
    end
    if not isHunter then return end

    -- Find nearest wanted player and attack
    local nearestPlayer = nil
    local nearestDist = 9999
    local players = creature:GetPlayersInRange(100)
    if players then
        for _, p in ipairs(players) do
            local guid = p:GetGUIDLow()
            if CrimeSystem.WantedData[guid] and CrimeSystem.WantedData[guid].level > 0 then
                local dist = creature:GetDistance(p)
                if dist < nearestDist then
                    nearestDist = dist
                    nearestPlayer = p
                end
            end
        end
    end

    if nearestPlayer then
        creature:AttackStart(nearestPlayer)
    end
end

-- ============================
-- BOUNTY HUNTER KILL CHECK
-- ============================
local function OnHunterTargetDied(event, creature, target)
    if not CONFIG.EnableNpcHunterClear then return end
    if not target then return end
    local guid = target:GetGUIDLow()
    local data = CrimeSystem.WantedData[guid]
    if not data then
        data = DB_Load(guid)
        if data then CrimeSystem.WantedData[guid] = data end
    end
    if data and data.level > 0 then
        target:SendBroadcastMessage("|cFF00FF00[WANTED] A bounty hunter has claimed your head. Wanted level cleared.|r")
        CrimeSystem.ClearWantedLevel(target)
        Log("Hunter cleared wanted for guid=" .. guid)
    end
end

-- ============================
-- INIT
-- ============================
DB_Init()

RegisterPlayerEvent(3,  OnPlayerLogin)
RegisterPlayerEvent(4,  OnPlayerLogout)
RegisterPlayerEvent(6,  OnPlayerKillPlayer)
RegisterPlayerEvent(7,  OnPlayerKillCreature)

-- Register spawn and death events for all hunter entries
for _, spawnList in pairs(CONFIG.HunterSpawnTable) do
    for _, info in ipairs(spawnList) do
        local entry = info[1]
        RegisterCreatureEvent(entry, 5, OnHunterSpawn)
        RegisterCreatureEvent(entry, 3, OnHunterTargetDied)
    end
end

Log("Crime & Bounty System loaded. Debug=" .. tostring(CONFIG.Debug))

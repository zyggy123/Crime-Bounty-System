-- ============================================================
-- Crime & Bounty System - World Database SQL
-- Run this in your world database
-- Drops and recreates all 3 NPC entries on every execution.
-- ============================================================

-- Clean up old data
DELETE FROM `creature_template` WHERE `entry` BETWEEN 900010 AND 900012;
DELETE FROM `creature_template_model` WHERE `CreatureID` BETWEEN 900010 AND 900012;
DELETE FROM `smart_scripts` WHERE `entryorguid` BETWEEN 900010 AND 900012;

-- Bounty Hunter entries
INSERT INTO `creature_template` (`entry`, `name`, `subname`, `minlevel`, `maxlevel`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `rank`, `unit_class`, `unit_flags`, `AIName`, `ScriptName`) VALUES
(900010, 'Bounty Hunter', 'Wanted', 80, 80, 14, 0, 1.0, 1.14286, 0, 1, 0, 'SmartAI', ''),
(900011, 'Bounty Hunter Elite', 'High Threat', 82, 82, 14, 0, 1.0, 1.14286, 1, 1, 0, 'SmartAI', ''),
(900012, 'Bounty Hunter Captain', 'Most Wanted', 85, 85, 14, 0, 1.0, 1.14286, 3, 1, 0, 'SmartAI', '');

-- Models (all Human Male display 50, different scales)
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`) VALUES
(900010, 0, 50, 1.0, 1),
(900011, 0, 50, 1.1, 1),
(900012, 0, 50, 1.3, 1);

-- SmartAI: attack the player who summoned them on spawn
-- event_type 54 = SMART_EVENT_JUST_SUMMONED
-- action_type 49 = SMART_ACTION_ATTACK_START
-- target_type 7  = SMART_TARGET_ACTION_INVOKER
INSERT INTO `smart_scripts` (`entryorguid`, `source_type`, `id`, `link`, `event_type`, `event_phase_mask`, `event_chance`, `event_flags`, `event_param1`, `event_param2`, `event_param3`, `event_param4`, `action_type`, `action_param1`, `action_param2`, `action_param3`, `action_param4`, `action_param5`, `action_param6`, `target_type`, `target_param1`, `target_param2`, `target_param3`, `target_x`, `target_y`, `target_z`, `target_o`, `comment`) VALUES
(900010, 0, 0, 0, 54, 0, 100, 0, 0, 0, 0, 0, 49, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 'Bounty Hunter - Attack Summoner'),
(900011, 0, 0, 0, 54, 0, 100, 0, 0, 0, 0, 0, 49, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 'Bounty Hunter Elite - Attack Summoner'),
(900012, 0, 0, 0, 54, 0, 100, 0, 0, 0, 0, 0, 49, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 'Bounty Hunter Captain - Attack Summoner');

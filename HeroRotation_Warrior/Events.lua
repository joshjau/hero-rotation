--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroLib
local HL = HeroLib
local HR = HeroRotation
local Cache = HeroCache
local Unit = HL.Unit
local Player = Unit.Player
local Target = Unit.Target
local Spell = HL.Spell
local Item = HL.Item
-- Lua
-- WoW API
local GetTime = GetTime
local Delay = C_Timer.After
-- File Locals
HR.Commons.Warrior = {}
local Warrior = HR.Commons.Warrior

--- ============================ CONTENT ============================
--- ===== Ravager Tracker =====
Warrior.Ravager = {}

HL:RegisterForSelfCombatEvent(
  function(...)
    local DestGUID, _, _, _, SpellID = select(8, ...)
    -- Ravager damage dealt
    if SpellID == 156287 then
      -- If this is the first tick, remove the entry 15 seconds later.
      if not Warrior.Ravager[DestGUID] then
        Delay(15, function()
            Warrior.Ravager[DestGUID] = nil
          end
        )
      end
      -- Record the tick time.
      Warrior.Ravager[DestGUID] = GetTime()
    end
  end
  , "SPELL_DAMAGE"
)

-- Remove the table entry upon unit death, if it still exists.
HL:RegisterForCombatEvent(
  function(...)
    local DestGUID = select(8, ...)
    if Warrior.Ravager[DestGUID] then
      Warrior.Ravager[DestGUID] = nil
    end
  end
  , "UNIT_DIED", "UNIT_DESTROYED"
)

--- ===== Enhanced Performance Tracking =====
Warrior.EnhancedStats = {
  LastCalculationTime = 0,
  PredictedEnrage = false,
  DamageMultiplier = 1.0,
  NextRageGen = 0,
  OptimalExecuteWindow = false,
  LastRageUpdate = 0,
  -- New enhanced tracking
  RecentDamageHistory = {},
  LastDamageTime = 0,
  PredictedBurstWindow = false,
  CombatStartTime = 0,
  AbilityHistory = {},
  PredictedCritChance = 0,
  LastCritUpdate = 0
}

-- Register for events that could affect our enhanced calculations
HL:RegisterForEvent(function()
  Warrior.EnhancedStats.LastCalculationTime = 0
  Warrior.EnhancedStats.LastRageUpdate = 0
  Warrior.EnhancedStats.NextRageGen = 0
  -- Reset enhanced tracking
  Warrior.EnhancedStats.RecentDamageHistory = {}
  Warrior.EnhancedStats.LastDamageTime = 0
  Warrior.EnhancedStats.PredictedBurstWindow = false
  Warrior.EnhancedStats.AbilityHistory = {}
  Warrior.EnhancedStats.PredictedCritChance = 0
  Warrior.EnhancedStats.LastCritUpdate = 0
  
  -- Cleanup old ability history entries
  for spellID, _ in pairs(Warrior.EnhancedStats.AbilityHistory) do
    Warrior.EnhancedStats.AbilityHistory[spellID] = nil
  end
end, "PLAYER_REGEN_ENABLED")

HL:RegisterForEvent(function()
  -- Reset calculations when entering combat
  Warrior.EnhancedStats.LastCalculationTime = 0
  Warrior.EnhancedStats.PredictedEnrage = false
  Warrior.EnhancedStats.DamageMultiplier = 1.0
  Warrior.EnhancedStats.NextRageGen = 0
  Warrior.EnhancedStats.OptimalExecuteWindow = false
  Warrior.EnhancedStats.LastRageUpdate = GetTime()
  -- Initialize enhanced tracking
  Warrior.EnhancedStats.CombatStartTime = GetTime()
  Warrior.EnhancedStats.RecentDamageHistory = {}
  Warrior.EnhancedStats.LastDamageTime = GetTime()
  Warrior.EnhancedStats.AbilityHistory = {}
  Warrior.EnhancedStats.PredictedCritChance = Player:CritChancePct()
  Warrior.EnhancedStats.LastCritUpdate = GetTime()
end, "PLAYER_REGEN_DISABLED")

-- Track damage events for burst window prediction
HL:RegisterForSelfCombatEvent(
  function(...)
    local timestamp, _, _, _, _, _, _, _, _, _, _, _, _, _, amount, _, _, _, _, _, isCrit = ...
    local currentTime = GetTime()
    
    -- Cleanup old entries first (more efficient)
    local cutoffTime = currentTime - 5
    while #Warrior.EnhancedStats.RecentDamageHistory > 0 and 
          Warrior.EnhancedStats.RecentDamageHistory[1].time < cutoffTime do
      table.remove(Warrior.EnhancedStats.RecentDamageHistory, 1)
    end
    
    -- Then add new entry
    table.insert(Warrior.EnhancedStats.RecentDamageHistory, {
      time = currentTime,
      amount = amount or 0,
      isCrit = isCrit or false
    })
    
    -- Update crit prediction every 2 seconds
    if currentTime - Warrior.EnhancedStats.LastCritUpdate > 2 then
      local critCount = 0
      local totalHits = #Warrior.EnhancedStats.RecentDamageHistory
      for _, hit in ipairs(Warrior.EnhancedStats.RecentDamageHistory) do
        if hit.isCrit then critCount = critCount + 1 end
      end
      if totalHits > 0 then
        Warrior.EnhancedStats.PredictedCritChance = (critCount / totalHits) * 100
      end
      Warrior.EnhancedStats.LastCritUpdate = currentTime
    end
    
    -- Predict burst windows based on recent damage
    local recentDamage = 0
    local totalWeight = 0
    -- Calculate estimated crit damage threshold based on current stats
    local critDamageThreshold = (Player:CritChancePct() / 100 + 1) * Player:AttackPower() * 2.5
    
    for _, hit in ipairs(Warrior.EnhancedStats.RecentDamageHistory) do
      local timeDiff = currentTime - hit.time
      if timeDiff <= 5 then  -- Early exit if too old
        local timeWeight = 1 + (timeDiff / 5)  -- More weight to recent damage
        recentDamage = recentDamage + (hit.amount * timeWeight)
        totalWeight = totalWeight + timeWeight
      end
    end
    
    -- Normalize the damage by total weight
    if totalWeight > 0 then
      recentDamage = recentDamage / totalWeight
      Warrior.EnhancedStats.PredictedBurstWindow = recentDamage > critDamageThreshold
    else
      Warrior.EnhancedStats.PredictedBurstWindow = false
    end
  end
  , "SPELL_DAMAGE"
)

-- Track ability usage patterns
HL:RegisterForSelfCombatEvent(
  function(...)
    local _, _, _, _, spellID = select(8, ...)
    local currentTime = GetTime()
    
    -- Store ability usage
    if not Warrior.EnhancedStats.AbilityHistory[spellID] then
      Warrior.EnhancedStats.AbilityHistory[spellID] = {}
    end
    table.insert(Warrior.EnhancedStats.AbilityHistory[spellID], currentTime)
    
    -- Keep only last 10 uses
    if #Warrior.EnhancedStats.AbilityHistory[spellID] > 10 then
      table.remove(Warrior.EnhancedStats.AbilityHistory[spellID], 1)
    end
  end
  , "SPELL_CAST_SUCCESS"
)

-- Existing rage tracking
HL:RegisterForSelfCombatEvent(
  function(...)
    local _, _, _, _, SpellID = select(8, ...)
    local currentTime = GetTime()
    
    -- Clear old rage predictions after 1.5s
    if currentTime - Warrior.EnhancedStats.LastRageUpdate > 1.5 then
      Warrior.EnhancedStats.NextRageGen = 0
    end
    
    -- Update rage prediction based on ability usage
    if SpellID == 23881 then -- Bloodthirst
      Warrior.EnhancedStats.NextRageGen = math.min(30, Warrior.EnhancedStats.NextRageGen + 8)
      Warrior.EnhancedStats.LastRageUpdate = currentTime
    elseif SpellID == 85288 then -- Raging Blow
      Warrior.EnhancedStats.NextRageGen = math.min(30, Warrior.EnhancedStats.NextRageGen + 12)
      Warrior.EnhancedStats.LastRageUpdate = currentTime
    end
  end
  , "SPELL_CAST_SUCCESS"
)

--- ======= NON-COMBATLOG =======

--- ======= COMBATLOG =======
  --- Combat Log Arguments
    ------- Base -------
      --     1        2         3           4           5           6              7             8         9        10           11
      -- TimeStamp, Event, HideCaster, SourceGUID, SourceName, SourceFlags, SourceRaidFlags, DestGUID, DestName, DestFlags, DestRaidFlags

    ------- Prefixes -------
      --- SWING
      -- N/A

      --- SPELL & SPELL_PACIODIC
      --    12        13          14
      -- SpellID, SpellName, SpellSchool

    ------- Suffixes -------
      --- _CAST_START & _CAST_SUCCESS & _SUMMON & _RESURRECT
      -- N/A

      --- _CAST_FAILED
      --     15
      -- FailedType

      --- _AURA_APPLIED & _AURA_REMOVED & _AURA_REFRESH
      --    15
      -- AuraType

      --- _AURA_APPLIED_DOSE
      --    15       16
      -- AuraType, Charges

      --- _INTERRUPT
      --      15            16             17
      -- ExtraSpellID, ExtraSpellName, ExtraSchool

      --- _HEAL
      --   15         16         17        18
      -- Amount, Overhealing, Absorbed, Critical

      --- _DAMAGE
      --   15       16       17       18        19       20        21        22        23
      -- Amount, Overkill, School, Resisted, Blocked, Absorbed, Critical, Glancing, Crushing

      --- _MISSED
      --    15        16           17
      -- MissType, IsOffHand, AmountMissed

    ------- Special -------
      --- UNIT_DIED, UNIT_DESTROYED
      -- N/A

  --- End Combat Log Arguments
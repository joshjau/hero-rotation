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
local SpellFury = Spell.Warrior.Fury

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
-- Initialize enhanced stats tracking ONCE
if not Warrior.EnhancedStats then
  Warrior.EnhancedStats = {
    -- Combat State
    CombatStartTime = 0,
    LastCalculationTime = 0,
    
    -- Damage Tracking
    RecentDamageHistory = {},
    LastDamageTime = 0,
    DamageMultiplier = 1.0,
    
    -- Prediction Systems
    PredictedBurstWindow = false,
    PredictedCritChance = 0,
    OptimalExecuteWindow = false,
    PredictedEnrage = false,
    
    -- Rage Management
    LastRageUpdate = 0,
    NextRageGen = 0,
    
    -- Ability Tracking
    AbilityHistory = {},
    RampageHistory = {},
    LastRampageTime = 0,
    
    -- Update Timers
    LastCritUpdate = 0,
    LastCleanupTime = 0,
    
    -- State Flags
    PendingCleanup = false
  }
end

-- Create a single frame for all event handling
local WarriorEventFrame = CreateFrame("Frame")
WarriorEventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
WarriorEventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
WarriorEventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")

local function CleanupOldEntries()
  if not Warrior.EnhancedStats.PendingCleanup then return end
  
  local currentTime = GetTime()
  if currentTime - Warrior.EnhancedStats.LastCleanupTime < 5 then return end
  
  -- Cleanup damage history (keep last 5 seconds)
  local cutoffTime = currentTime - 5
  while #Warrior.EnhancedStats.RecentDamageHistory > 0 and 
        Warrior.EnhancedStats.RecentDamageHistory[1].time < cutoffTime do
    table.remove(Warrior.EnhancedStats.RecentDamageHistory, 1)
  end
  
  -- Cleanup ability history (keep last 5 minutes)
  for spellID, history in pairs(Warrior.EnhancedStats.AbilityHistory) do
    for i = #history, 1, -1 do
      if currentTime - history[i] > 300 then
        table.remove(history, i)
      end
    end
    -- Remove empty histories
    if #history == 0 then
      Warrior.EnhancedStats.AbilityHistory[spellID] = nil
    end
  end
  
  -- Cleanup Rampage history (keep last 30 seconds)
  for i = #Warrior.EnhancedStats.RampageHistory, 1, -1 do
    if currentTime - Warrior.EnhancedStats.RampageHistory[i] > 30 then
      table.remove(Warrior.EnhancedStats.RampageHistory, i)
    end
  end
  
  Warrior.EnhancedStats.LastCleanupTime = currentTime
  Warrior.EnhancedStats.PendingCleanup = false
end

WarriorEventFrame:SetScript("OnEvent", function(self, event)
  if event == "COMBAT_LOG_EVENT_UNFILTERED" then
    local timestamp, subEvent, _, sourceGUID, _, _, _, destGUID, _, _, _, spellID, _, _, amount = CombatLogGetCurrentEventInfo()
    
    -- Handle unit death through combat log
    if subEvent == "UNIT_DIED" or subEvent == "UNIT_DESTROYED" then
      if Warrior.Ravager[destGUID] then
        Warrior.Ravager[destGUID] = nil
      end
    end
    
    if sourceGUID == Player:GUID() then
      local currentTime = GetTime()
      
      -- Track damage for burst window prediction
      if subEvent == "SPELL_DAMAGE" or subEvent == "SWING_DAMAGE" then
        -- Flag for cleanup on next tick
        Warrior.EnhancedStats.PendingCleanup = true
        
        -- Add new damage entry with time-weighted value
        table.insert(Warrior.EnhancedStats.RecentDamageHistory, {
          time = currentTime,
          damage = amount or 0,
          weight = math.exp(-(currentTime - (Warrior.EnhancedStats.LastDamageTime or currentTime)))
        })
        
        Warrior.EnhancedStats.LastDamageTime = currentTime
        
        -- Calculate burst window with normalized damage
        local totalDamage, totalWeight = 0, 0
        for _, entry in ipairs(Warrior.EnhancedStats.RecentDamageHistory) do
          totalDamage = totalDamage + entry.damage * entry.weight
          totalWeight = totalWeight + entry.weight
        end
        
        -- Calculate normalized damage and update burst window prediction
        if totalWeight > 0 then
          local normalizedDamage = totalDamage / totalWeight
          local critDamageThreshold = (Player:CritChancePct() / 100 + 1) * Player:AttackPower() * 2.5
          Warrior.EnhancedStats.PredictedBurstWindow = normalizedDamage > critDamageThreshold
        end
      end
      
      -- Track ability usage with pattern recognition
      if subEvent == "SPELL_CAST_SUCCESS" then
        if not Warrior.EnhancedStats.AbilityHistory[spellID] then
          Warrior.EnhancedStats.AbilityHistory[spellID] = {}
        end
        
        local history = Warrior.EnhancedStats.AbilityHistory[spellID]
        table.insert(history, currentTime)
        if #history > 10 then table.remove(history, 1) end
        
        -- Special tracking for Rampage
        if spellID == SpellFury.Rampage:ID() then
          table.insert(Warrior.EnhancedStats.RampageHistory, currentTime)
          Warrior.EnhancedStats.LastRampageTime = currentTime
        end
      end
      
      -- Track rage generation with caps
      if spellID == SpellFury.Bloodthirst:ID() then
        Warrior.EnhancedStats.LastRageUpdate = currentTime
        Warrior.EnhancedStats.NextRageGen = math.min(30, (Warrior.EnhancedStats.NextRageGen or 0) + 8)
      elseif spellID == SpellFury.RagingBlow:ID() then
        Warrior.EnhancedStats.LastRageUpdate = currentTime
        Warrior.EnhancedStats.NextRageGen = math.min(30, (Warrior.EnhancedStats.NextRageGen or 0) + 12)
      end
    end
  elseif event == "PLAYER_REGEN_ENABLED" then
    -- Reset all combat stats
    wipe(Warrior.EnhancedStats.RecentDamageHistory)
    wipe(Warrior.EnhancedStats.RampageHistory)
    Warrior.EnhancedStats.LastDamageTime = 0
    Warrior.EnhancedStats.PredictedBurstWindow = false
    Warrior.EnhancedStats.LastCalculationTime = 0
    Warrior.EnhancedStats.CombatStartTime = 0
    Warrior.EnhancedStats.PredictedCritChance = 0
    Warrior.EnhancedStats.LastCritUpdate = 0
    Warrior.EnhancedStats.LastRageUpdate = 0
    Warrior.EnhancedStats.NextRageGen = 0
    Warrior.EnhancedStats.OptimalExecuteWindow = false
    Warrior.EnhancedStats.DamageMultiplier = 1.0
    Warrior.EnhancedStats.LastRampageTime = 0
    Warrior.EnhancedStats.PendingCleanup = true
  elseif event == "PLAYER_REGEN_DISABLED" then
    -- Initialize combat start
    Warrior.EnhancedStats.CombatStartTime = GetTime()
    -- Reset prediction systems on combat start
    Warrior.EnhancedStats.PredictedBurstWindow = false
    Warrior.EnhancedStats.OptimalExecuteWindow = false
    Warrior.EnhancedStats.NextRageGen = 0
  end
end)

-- Update crit predictions every 2 seconds
local CritUpdateTimer = C_Timer.NewTicker(2, function()
  if Player:AffectingCombat() then
    local currentTime = GetTime()
    if currentTime - Warrior.EnhancedStats.LastCritUpdate >= 2 then
      Warrior.EnhancedStats.PredictedCritChance = Player:CritChancePct()
      Warrior.EnhancedStats.LastCritUpdate = currentTime
    end
  end
end)

-- Cleanup predicted rage after 1.5 seconds and handle pending cleanups
local MaintenanceTimer = C_Timer.NewTicker(0.1, function()
  local currentTime = GetTime()
  
  -- Rage cleanup
  if Warrior.EnhancedStats.LastRageUpdate and currentTime - Warrior.EnhancedStats.LastRageUpdate > 1.5 then
    Warrior.EnhancedStats.NextRageGen = 0
  end
  
  -- Handle pending cleanups
  CleanupOldEntries()
end)

-- Ensure timers are cleaned up if addon is disabled
local function CleanupTimers()
  if CritUpdateTimer then CritUpdateTimer:Cancel() end
  if MaintenanceTimer then MaintenanceTimer:Cancel() end
end

WarriorEventFrame:SetScript("OnDisable", CleanupTimers)

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
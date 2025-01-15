--- ============================ HEADER ============================
-- Import all required libraries and initialize local variables
local addonName, addonTable = ...
local DBC = HeroDBC.DBC
local HL = HeroLib
local Cache = HeroCache
local Unit = HL.Unit
local Player = Unit.Player
local Target = Unit.Target
local Spell = HL.Spell
local Item = HL.Item
local HR = HeroRotation
local Cast = HR.Cast
local AoEON = HR.AoEON
local CDsON = HR.CDsON
local mathmin = math.min
local mathmax = math.max

-- Import Frost Mage spells
local S = Spell.Mage.Frost

-- Initialize metrics for Winter's Chill tracking
local WCMetrics = {
  applications = 0,
  shatters = 0,
  wastedProcs = 0,
  perfectShatterCombos = 0,
  missedShatterOpportunities = 0,
  optimalShatterWindows = 0,
  cleaveEfficiency = 0,
  movementEfficiency = 0
}

-- Track in-flight spells that can trigger effects
local InFlightSpells = {
  [S.Frostbolt:ID()] = true,      -- Frostbolt
  [228597] = true,                 -- Frostbolt Impact
  [S.CometStorm:ID()] = true,      -- Comet Storm
  [153596] = true,                 -- Comet Storm Impact
  [S.Flurry:ID()] = true,          -- Flurry
  [228354] = true,                 -- Flurry Impact
  [S.GlacialSpike:ID()] = true,    -- Glacial Spike
  [228600] = true,                 -- Glacial Spike Impact
  [S.IceLance:ID()] = true,        -- Ice Lance
  [228598] = true,                 -- Ice Lance Impact
  [S.FrostfireBolt:ID()] = true,   -- Frostfire Bolt
  [S.FrozenOrb:ID()] = true,       -- Frozen Orb
  [84721] = true                   -- Frozen Orb Impact
}

-- Track spell states for optimization
local SpellStates = {
  lastFrostboltCast = 0,
  lastFlurryCast = 0,
  lastGlacialSpikeCast = 0,
  predictedIcicles = 0,
  lastWinterChillApplication = 0,
  incomingWintersChill = 0,
  lastShatterCombo = 0,
  lastFrozenState = 0,
  perfectShatterWindow = false,
  lastCleaveTarget = nil,
  missedShatterWindows = 0,
  suboptimalCasts = 0,
  movementCasts = 0
}

-- Register Combat Log Event Handler with enhanced tracking
HL:RegisterForEvent(function(...)
  local timestamp, subevent, _, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellID, spellName = ...
  
  -- Only process events from the player
  if sourceGUID ~= Player:GUID() then return end
  
  if subevent == "SPELL_CAST_SUCCESS" then
    -- Track spell casts for state prediction
    if spellID == S.Frostbolt:ID() then
      SpellStates.lastFrostboltCast = timestamp
      SpellStates.predictedIcicles = mathmin(5, SpellStates.predictedIcicles + 1)
      -- Track cast efficiency
      if Player:IsMoving() then 
        SpellStates.movementCasts = SpellStates.movementCasts + 1 
      end
    elseif spellID == S.Flurry:ID() then
      SpellStates.lastFlurryCast = timestamp
      SpellStates.incomingWintersChill = 2
      -- Check for optimal Shatter timing
      if Player:PrevGCDP(1, S.Frostbolt) or Player:PrevGCDP(1, S.GlacialSpike) then
        SpellStates.perfectShatterWindow = true
        WCMetrics.optimalShatterWindows = WCMetrics.optimalShatterWindows + 1
      else
        SpellStates.suboptimalCasts = SpellStates.suboptimalCasts + 1
      end
    elseif spellID == S.GlacialSpike:ID() then
      SpellStates.lastGlacialSpikeCast = timestamp
      SpellStates.predictedIcicles = 0
      -- Track Glacial Spike efficiency
      if not SpellStates.perfectShatterWindow then
        SpellStates.suboptimalCasts = SpellStates.suboptimalCasts + 1
      end
    end
  elseif subevent == "SPELL_DAMAGE" then
    -- Track spell impacts for in-flight effects
    if InFlightSpells[spellID] then
      -- Update metrics based on the spell that landed
      if spellID == 228354 then -- Flurry Impact
        -- Check if we shattered properly
        if Target:DebuffStack(S.WintersChillDebuff) > 0 then
          WCMetrics.shatters = WCMetrics.shatters + 1
          -- Check for perfect shatter combos
          if SpellStates.perfectShatterWindow then
            WCMetrics.perfectShatterCombos = WCMetrics.perfectShatterCombos + 1
            SpellStates.perfectShatterWindow = false
          end
        end
      end
      -- Track cleave efficiency
      if destGUID ~= SpellStates.lastCleaveTarget then
        WCMetrics.cleaveEfficiency = WCMetrics.cleaveEfficiency + 1
        SpellStates.lastCleaveTarget = destGUID
      end
    end
  elseif subevent == "SPELL_AURA_APPLIED" then
    -- Track Winter's Chill applications
    if spellID == S.WintersChillDebuff:ID() then
      SpellStates.lastWinterChillApplication = timestamp
      WCMetrics.applications = WCMetrics.applications + 1
      -- Check for potential waste
      if Target:DebuffStack(S.WintersChillDebuff) > 2 then
        WCMetrics.wastedProcs = WCMetrics.wastedProcs + 1
      end
    elseif spellID == S.FrozenDebuff:ID() then
      SpellStates.lastFrozenState = timestamp
    end
  elseif subevent == "SPELL_AURA_REMOVED" then
    -- Track Winter's Chill removals
    if spellID == S.WintersChillDebuff:ID() then
      -- Check for missed shatter opportunities
      if Target:DebuffStack(S.WintersChillDebuff) > 0 then
        WCMetrics.missedShatterOpportunities = WCMetrics.missedShatterOpportunities + 1
        SpellStates.missedShatterWindows = SpellStates.missedShatterWindows + 1
      end
    end
  end
end, "COMBAT_LOG_EVENT_UNFILTERED")

-- Reset metrics and states when leaving combat with enhanced cleanup
HL:RegisterForEvent(function()
  WCMetrics = {
    applications = 0,
    shatters = 0,
    wastedProcs = 0,
    perfectShatterCombos = 0,
    missedShatterOpportunities = 0,
    optimalShatterWindows = 0,
    cleaveEfficiency = 0,
    movementEfficiency = 0
  }
  
  SpellStates = {
    lastFrostboltCast = 0,
    lastFlurryCast = 0,
    lastGlacialSpikeCast = 0,
    predictedIcicles = 0,
    lastWinterChillApplication = 0,
    incomingWintersChill = 0,
    lastShatterCombo = 0,
    lastFrozenState = 0,
    perfectShatterWindow = false,
    lastCleaveTarget = nil,
    missedShatterWindows = 0,
    suboptimalCasts = 0,
    movementCasts = 0
  }
end, "PLAYER_REGEN_ENABLED")

-- Track player state changes with enhanced spec handling
HL:RegisterForEvent(function()
  -- Reset predicted states on spec change
  SpellStates.predictedIcicles = 0
  SpellStates.incomingWintersChill = 0
  SpellStates.perfectShatterWindow = false
  -- Reset performance metrics
  SpellStates.missedShatterWindows = 0
  SpellStates.suboptimalCasts = 0
  SpellStates.movementCasts = 0
end, "PLAYER_SPECIALIZATION_CHANGED")

-- Add movement efficiency tracking
HL:RegisterForEvent(function()
  if Player:IsMoving() then
    WCMetrics.movementEfficiency = WCMetrics.movementEfficiency + 1
  end
end, "PLAYER_STARTED_MOVING", "PLAYER_STOPPED_MOVING")

-- Export metrics and states for use in rotation
HR.Commons.Mage = HR.Commons.Mage or {}
HR.Commons.Mage.WCMetrics = WCMetrics
HR.Commons.Mage.SpellStates = SpellStates

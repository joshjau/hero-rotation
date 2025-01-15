--- ============================ HEADER ============================
-- HeroLib
local HL      = HeroLib
local Cache   = HeroCache
local Unit    = HL.Unit
local Player  = Unit.Player
local Pet     = Unit.Pet
local Target  = Unit.Target
local Spell   = HL.Spell
local Item    = HL.Item
-- HeroRotation
local HR      = HeroRotation
-- Spells
local SpellArcane = Spell.Mage.Arcane
local SpellFire   = Spell.Mage.Fire
local SpellFrost  = Spell.Mage.Frost
-- lua
local mathmin     = math.min
local mathmax     = math.max

-- Initialize Commons if needed
if not HR.Commons.Mage then HR.Commons.Mage = {} end

-- Initialize metrics and states at the start
if not HR.Commons.Mage.WCMetrics then
  HR.Commons.Mage.WCMetrics = {
    applications = 0,
    shatters = 0,
    optimalShatterWindows = 0,
    movementEfficiency = 0,
    suboptimalCasts = 0
  }
end

if not HR.Commons.Mage.SpellStates then
  HR.Commons.Mage.SpellStates = {
    predictedIcicles = 0,
    incomingWintersChill = 0,
    perfectShatterWindow = false,
    lastWinterChillApplication = 0,
    lastFlurryCast = 0,
    lastFrostboltCast = 0,
    lastGlacialSpikeCast = 0,
    movementCasts = 0
  }
end

-- Create local references
local WCMetrics = HR.Commons.Mage.WCMetrics
local SpellStates = HR.Commons.Mage.SpellStates

local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Mage.Commons,
  Frost = HR.GUISettings.APL.Mage.Frost,
  Fire = HR.GUISettings.APL.Mage.Fire,
  Arcane = HR.GUISettings.APL.Mage.Arcane,
}

-- Util
local function num(val)
  if val then return 1 else return 0 end
end

local function bool(val)
  return val ~= 0
end

--- ============================ CONTENT ============================
-- Mage

-- Enhanced spell readiness checks with movement optimization
HL.AddCoreOverride("Spell.IsReady",
  function (self, Range, AoESpell, ThisUnit, BypassRecovery, Offset)
    local BaseCheck = self:IsCastable(BypassRecovery, Range, AoESpell, ThisUnit, Offset) and self:IsUsableP()
    
    -- Ensure WCMetrics exists
    if not HR.Commons.Mage.WCMetrics then
      HR.Commons.Mage.WCMetrics = {
        applications = 0,
        shatters = 0,
        optimalShatterWindows = 0,
        movementEfficiency = 0,
        suboptimalCasts = 0
      }
    end
    
    local WCMetrics = HR.Commons.Mage.WCMetrics
    local SpellStates = HR.Commons.Mage.SpellStates
    
    -- Track movement efficiency
    if Player:IsMoving() then
      WCMetrics.movementEfficiency = (WCMetrics.movementEfficiency or 0) + 1
    end
    
    -- Track suboptimal casts
    if BaseCheck and Player:IsCasting() then
      WCMetrics.suboptimalCasts = (WCMetrics.suboptimalCasts or 0) + 1
    end
    
    -- Enhanced movement handling
    if self:CastTime() > 0 and Player:IsMoving() then
      -- Allow Ice Lance during movement
      if self == SpellFrost.IceLance then
        return BaseCheck
      -- Allow Flurry during movement with Brain Freeze
      elseif self == SpellFrost.Flurry and Player:BuffUp(SpellFrost.BrainFreezeBuff) then
        return BaseCheck
      -- Allow instant cast spells during movement
      elseif self:CastTime() == 0 then
        return BaseCheck
      else
        return false
      end
    end
    
    return BaseCheck
  end
, 64)

-- Arcane, ID: 62
local ArcaneOldPlayerAffectingCombat
ArcaneOldPlayerAffectingCombat = HL.AddCoreOverride("Player.AffectingCombat",
  function (self)
    return Player:IsCasting(SpellArcane.ArcaneBlast) or ArcaneOldPlayerAffectingCombat(self)
  end
, 62)

HL.AddCoreOverride("Spell.IsCastable",
  function (self, BypassRecovery, Range, AoESpell, ThisUnit, Offset)
    local RangeOK = true
    if Range then
      local RangeUnit = ThisUnit or Target
      RangeOK = RangeUnit:IsInRange( Range, AoESpell )
    end

    local BaseCheck = self:IsLearned() and self:CooldownRemains( BypassRecovery, Offset or "Auto") == 0 and RangeOK and Player:Mana() >= self:Cost()
    if self == SpellArcane.PresenceofMind then
      return BaseCheck and Player:BuffDown(SpellArcane.PresenceofMind)
    elseif self == SpellArcane.ShiftingPower then
      return BaseCheck and not Player:IsCasting(self)
    elseif self == SpellArcane.TouchoftheMagi then
      return BaseCheck and not Player:IsCasting(self)
    elseif self == SpellArcane.ArcaneSurge then
      return self:IsLearned() and self:CooldownUp() and RangeOK and not Player:IsCasting(self)
    else
      return BaseCheck
    end
  end
, 62)

local ArcaneChargesPowerType = Enum.PowerType.ArcaneCharges
local ArcaneOldPlayerArcaneCharges
ArcaneOldPlayerArcaneCharges = HL.AddCoreOverride("Player.ArcaneCharges",
  function (self)
    local BaseCharges = UnitPower("player", ArcaneChargesPowerType)
    if Player:IsCasting(SpellArcane.ArcaneBlast) then
      return mathmin(BaseCharges + 1, 4)
    else
      return BaseCharges
    end
  end
, 62)

local ArcanePlayerBuffUp
ArcanePlayerBuffUp = HL.AddCoreOverride("Player.BuffUp",
  function (self, Spell, AnyCaster, Offset)
    local BaseCheck = ArcanePlayerBuffUp(self, Spell, AnyCaster, Offset)
    if Spell == SpellArcane.ArcaneSurgeBuff then
      return BaseCheck or Player:IsCasting(SpellArcane.ArcaneSurge)
    else
      return BaseCheck
    end
  end
, 62)

local ArcanePlayerBuffDown
ArcanePlayerBuffDown = HL.AddCoreOverride("Player.BuffDown",
  function (self, Spell, AnyCaster, Offset)
    local BaseCheck = ArcanePlayerBuffDown(self, Spell, AnyCaster, Offset)
    if Spell == SpellArcane.ArcaneSurgeBuff then
      return BaseCheck and not Player:IsCasting(SpellArcane.ArcaneSurge)
    else
      return BaseCheck
    end
  end
, 62)

-- Fire, ID: 63
local FirePlayerBuffUp
FirePlayerBuffUp = HL.AddCoreOverride("Player.BuffUp",
  function (self, Spell, AnyCaster, Offset)
    local BaseCheck = FirePlayerBuffUp(self, Spell, AnyCaster, Offset)
    if Spell == SpellFire.HeatingUpBuff then
      -- "Predictive" Heating Up buff for SKB Pyroblast casts...
      return BaseCheck or Player:IsCasting(SpellFire.Pyroblast) and Player:BuffRemains(SpellFire.FuryoftheSunKingBuff) > 0
    else
      return BaseCheck
    end
  end
, 63)

local FirePlayerBuffDown
FirePlayerBuffDown = HL.AddCoreOverride("Player.BuffDown",
  function (self, Spell, AnyCaster, Offset)
    local BaseCheck = FirePlayerBuffDown(self, Spell, AnyCaster, Offset)
    if Spell == SpellFire.FuryoftheSunKingBuff then
      return BaseCheck or Player:IsCasting(SpellFire.Pyroblast)
    else
      return BaseCheck
    end
  end
, 63)

HL.AddCoreOverride("Spell.IsReady",
  function (self, Range, AoESpell, ThisUnit, BypassRecovery, Offset)
    local BaseCheck = self:IsCastable() and self:IsUsableP()
    local MovingOK = true
    if self:CastTime() > 0 and Player:IsMoving() and Settings.Commons.MovingRotation then
      if self == SpellFire.Scorch or (self == SpellFire.Pyroblast and Player:BuffUp(SpellFire.HotStreakBuff)) or (self == SpellFire.Flamestrike and Player:BuffUp(SpellFire.HotStreakBuff)) then
        MovingOK = true
      else
        return false
      end
    else
      return BaseCheck
    end
  end
, 63)

HL.AddCoreOverride("Spell.IsCastable",
  function (self, BypassRecovery, Range, AoESpell, ThisUnit, Offset)
    if self:CastTime() > 0 and Player:IsMoving() and Settings.Commons.MovingRotation then
      return false
    end

    local RangeOK = true
    if Range then
      local RangeUnit = ThisUnit or Target
      RangeOK = RangeUnit:IsInRange( Range, AoESpell )
    end

    local BaseCheck = self:IsLearned() and self:CooldownRemains(BypassRecovery, Offset or "Auto") == 0 and RangeOK
    if self == SpellFire.ShiftingPower then
      return BaseCheck and not Player:IsCasting(self)
    else
      return BaseCheck
    end
  end
, 63)

local FireOldPlayerAffectingCombat
FireOldPlayerAffectingCombat = HL.AddCoreOverride("Player.AffectingCombat",
  function (self)
    return FireOldPlayerAffectingCombat(self)
      or Player:IsCasting(SpellFire.Pyroblast)
      or Player:IsCasting(SpellFire.Fireball)
  end
, 63)

HL.AddCoreOverride("Spell.InFlightRemains",
  function(self)
    return self:TravelTime() - self:TimeSinceLastCast()
  end
, 63)

-- Frost, ID: 64
local FrostOldSpellIsCastable
FrostOldSpellIsCastable = HL.AddCoreOverride("Spell.IsCastable",
  function (self, BypassRecovery, Range, AoESpell, ThisUnit, Offset)
    local RangeOK = true
    if Range then
      local RangeUnit = ThisUnit or Target
      RangeOK = RangeUnit:IsInRange( Range, AoESpell )
    end

    local BaseCheck = self:IsLearned() and self:CooldownRemains(BypassRecovery, Offset or "Auto") == 0 and RangeOK
    
    -- Enhanced spell castability checks
    if self == SpellFrost.ShiftingPower then
      return BaseCheck and not Player:IsCasting(self)
    elseif self == SpellFrost.CometStorm then
      return BaseCheck and not Player:IsCasting(self) and not self:InFlight()
    elseif self == SpellFrost.Flurry then
      -- Prevent Flurry waste during Brain Freeze
      return BaseCheck and (not Player:BuffUp(SpellFrost.BrainFreezeBuff) or 
             Target:DebuffDown(SpellFrost.WintersChillDebuff) or
             Target:DebuffStack(SpellFrost.WintersChillDebuff) < 2)
    elseif self == SpellFrost.GlacialSpike then
      -- Prevent Glacial Spike waste
      return BaseCheck and not self:InFlight() and 
             (Player:BuffStack(SpellFrost.IciclesBuff) == 5 or
              Player:IsCasting(self))
    elseif self == SpellFrost.IceLance then
      -- Optimize Ice Lance usage
      return BaseCheck and 
             (Player:BuffUp(SpellFrost.FingersofFrostBuff) or
              Target:DebuffUp(SpellFrost.WintersChillDebuff) or
              Target:DebuffUp(SpellFrost.Freeze) or
              Player:IsMoving())
    else
      return BaseCheck
    end
  end
, 64)

-- Enhanced in-flight tracking with performance optimization
HL.AddCoreOverride("Spell.InFlight",
  function(self)
    local BaseCheck = self.InFlightSpell and self.InFlightSpell:InFlight() or false
    local SpellStates = HR.Commons.Mage.SpellStates
    local timeSince = GetTime() - (
      self == SpellFrost.Frostbolt and SpellStates.lastFrostboltCast or
      self == SpellFrost.Flurry and SpellStates.lastFlurryCast or
      self == SpellFrost.GlacialSpike and SpellStates.lastGlacialSpikeCast or
      0
    )
    
    -- Use spell-specific timing windows
    if timeSince > 0 then
      if self == SpellFrost.CometStorm then
        return timeSince < 2 or BaseCheck
      elseif self == SpellFrost.FrozenOrb then
        return timeSince < 2.5 or BaseCheck
      elseif self == SpellFrost.Flurry then
        return timeSince < 1.5 or BaseCheck
      elseif self == SpellFrost.Frostbolt then
        return timeSince < 2 or BaseCheck
      elseif self == SpellFrost.GlacialSpike then
        return timeSince < 2 or BaseCheck
      end
    end
    
    return BaseCheck
  end
, 64)

-- Enhanced combat state tracking with performance metrics
local FrostOldPlayerAffectingCombat
FrostOldPlayerAffectingCombat = HL.AddCoreOverride("Player.AffectingCombat",
  function (self)
    local SpellStates = HR.Commons.Mage.SpellStates
    -- Track movement efficiency during combat
    if Player:IsMoving() then
      SpellStates.movementCasts = SpellStates.movementCasts + 1
    end
    
    return SpellFrost.Frostbolt:InFlight() or 
           SpellFrost.CometStorm:InFlight() or 
           SpellFrost.FrozenOrb:InFlight() or 
           SpellFrost.Flurry:InFlight() or
           SpellFrost.GlacialSpike:InFlight() or
           SpellFrost.IceLance:InFlight() or
           FrostOldPlayerAffectingCombat(self)
  end
, 64)

-- Enhanced buff stack tracking with state prediction
HL.AddCoreOverride("Player.BuffStackP",
  function (self, Spell, AnyCaster, Offset)
    local BaseCheck = Player:BuffStack(Spell, AnyCaster, Offset)
    local SpellStates = HR.Commons.Mage.SpellStates
    
    if Spell == SpellFrost.IciclesBuff then
      return SpellStates.predictedIcicles
    elseif Spell == SpellFrost.GlacialSpikeBuff then
      return Player:IsCasting(SpellFrost.GlacialSpike) and 0 or BaseCheck
    elseif Spell == SpellFrost.WintersReachBuff then
      return Player:IsCasting(SpellFrost.Flurry) and 0 or BaseCheck
    elseif Spell == SpellFrost.FingersofFrostBuff then
      if SpellFrost.IceLance:InFlight() then
        return mathmax(0, BaseCheck - 1)
      end
      return BaseCheck
    else
      return BaseCheck
    end
  end
, 64)

-- Enhanced debuff stack tracking with cleave optimization
local FrostOldTargetDebuffStack
FrostOldTargetDebuffStack = HL.AddCoreOverride("Target.DebuffStack",
  function (self, Spell, AnyCaster, Offset)
    local BaseCheck = FrostOldTargetDebuffStack(self, Spell, AnyCaster, Offset)
    local SpellStates = HR.Commons.Mage.SpellStates
    local WCMetrics = HR.Commons.Mage.WCMetrics
    
    if Spell == SpellFrost.WintersChillDebuff then
      if SpellFrost.Flurry:InFlight() then
        -- Track optimal Winter's Chill applications
        if SpellStates.perfectShatterWindow then
          WCMetrics.optimalShatterWindows = WCMetrics.optimalShatterWindows + 1
        end
        return mathmin(2, BaseCheck + SpellStates.incomingWintersChill)
      elseif SpellFrost.IceLance:InFlight() or 
             Player:IsCasting(SpellFrost.GlacialSpike) or 
             SpellFrost.GlacialSpike:InFlight() then
        -- Track consumed stacks
        if BaseCheck > 0 then
          WCMetrics.shatters = WCMetrics.shatters + 1
        end
        return mathmax(0, BaseCheck - 1)
      end
      return BaseCheck
    else
      return BaseCheck
    end
  end
, 64)

-- Enhanced debuff remains tracking with precise timing
local FrostOldTargetDebuffRemains
FrostOldTargetDebuffRemains = HL.AddCoreOverride("Target.DebuffRemains",
  function (self, Spell, AnyCaster, Offset)
    local BaseCheck = FrostOldTargetDebuffRemains(self, Spell, AnyCaster, Offset)
    local SpellStates = HR.Commons.Mage.SpellStates
    
    if Spell == SpellFrost.WintersChillDebuff then
      if SpellFrost.Flurry:InFlight() then
        return 6
      elseif GetTime() - SpellStates.lastWinterChillApplication < 6 then
        return mathmax(0, 6 - (GetTime() - SpellStates.lastWinterChillApplication))
      end
      return BaseCheck
    else
      return BaseCheck
    end
  end
, 64)

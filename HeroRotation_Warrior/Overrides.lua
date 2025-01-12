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
local Warrior = HR.Commons.Warrior
-- Spells
local SpellFury             = Spell.Warrior.Fury
local SpellArms             = Spell.Warrior.Arms
local SpellProt             = Spell.Warrior.Protection
-- Lua
local GetTime = GetTime

--- ============================ CONTENT ============================
-- Arms, ID: 71
local ArmsOldSpellIsCastable
ArmsOldSpellIsCastable = HL.AddCoreOverride ("Spell.IsCastable",
  function (self, BypassRecovery, Range, AoESpell, ThisUnit, Offset)
    local BaseCheck = ArmsOldSpellIsCastable(self, BypassRecovery, Range, AoESpell, ThisUnit, Offset)
    if self == SpellArms.Charge then
      return BaseCheck and (self:Charges() >= 1 and not Target:IsInRange(8) and Target:IsInRange(25))
    else
      return BaseCheck
    end
  end
, 71)

local ArmsOldDebuffUp
ArmsOldDebuffUp = HL.AddCoreOverride ("Unit.DebuffUp",
  function (self, Spell, AnyCaster, BypassRecovery)
    local BaseCheck = ArmsOldDebuffUp(self, Spell, AnyCaster, BypassRecovery)
    if Spell == SpellArms.RavagerDebuff then
      if Warrior.Ravager[self:GUID()] then
        -- Add 0.2s buffer to tick timer.
        return GetTime() - Warrior.Ravager[self:GUID()] < SpellArms.Ravager:TickTime() + 0.2
      else
        return false
      end
    else
      return BaseCheck
    end
  end
, 71)

-- Fury, ID: 72
local FuryOldSpellIsCastable
FuryOldSpellIsCastable = HL.AddCoreOverride ("Spell.IsCastable",
  function (self, BypassRecovery, Range, AoESpell, ThisUnit, Offset)
    -- First check if we're charging - block EVERYTHING if true
    if Player:IsChanneling(SpellFury.Charge) then
      return false
    end
    
    local BaseCheck = FuryOldSpellIsCastable(self, BypassRecovery, Range, AoESpell, ThisUnit, Offset)
    
    -- Enhanced checks for specific abilities
    if BaseCheck then
      if self == SpellFury.Rampage then
        -- Don't suggest Rampage if we're in a burst window and have better options
        if Warrior.EnhancedStats.PredictedBurstWindow then
          -- Check if we have any high-priority abilities available
          if SpellFury.Execute:IsReady() or 
             SpellFury.Bloodbath:IsReady() or 
             SpellFury.CrushingBlow:IsReady() or
             SpellFury.OdynsFury:IsReady() then
            return false
          end
        end
        
        -- Check recent Rampage history to prevent overcapping
        local currentTime = GetTime()
        if #Warrior.EnhancedStats.RampageHistory > 0 then
          local lastRampageTime = Warrior.EnhancedStats.RampageHistory[#Warrior.EnhancedStats.RampageHistory]
          if currentTime - lastRampageTime < 1.5 then
            return false
          end
        end
        
        -- Don't count predicted rage if we're already at 80+ rage
        local predictedRage = Player:Rage() >= 80 and 0 or Warrior.EnhancedStats.NextRageGen
        
        -- Add Anger Management consideration
        if SpellFury.AngerManagement:IsAvailable() then
          -- More aggressive with rage spending if Recklessness CD is high
          if SpellFury.Recklessness:CooldownRemains() > 30 and Player:Rage() >= 50 then
            return true
          end
          -- Normal Anger Management check
          if Player:Rage() >= 40 then
            return true
          end
        end
        
        -- Check if we need Enrage
        if not Player:BuffUp(SpellFury.EnrageBuff) then
          return (Player:Rage() + predictedRage) >= self:Cost()
        end
        
        -- Default rage check
        return (Player:Rage() + predictedRage) >= self:Cost()
      elseif self == SpellFury.Execute then
        -- Enhanced execute condition using tracked stats
        if Warrior.EnhancedStats.OptimalExecuteWindow or
           (Target:HealthPercentage() < 35 and Warrior.EnhancedStats.PredictedBurstWindow) or
           (Player:BuffUp(SpellFury.SuddenDeathBuff) and 
            (Player:BuffStack(SpellFury.SuddenDeathBuff) == 2 or 
             Player:BuffRemains(SpellFury.SuddenDeathBuff) < 2)) then
          return true
        end
      elseif self == SpellFury.Bloodbath then
        -- Enhanced Bloodbath timing based on crit predictions
        if (Warrior.EnhancedStats.PredictedCritChance >= 85 and Player:BuffUp(SpellFury.EnrageBuff)) or 
           Player:BuffStack(SpellFury.BloodcrazeBuff) >= 3 or
           (Target:HealthPercentage() < 35 and Player:BuffUp(SpellFury.RecklessnessBuff)) then
          return true
        end
      elseif self == SpellFury.RagingBlow then
        -- Prioritize Raging Blow charges
        if (Player:BuffDown(SpellFury.RecklessnessBuff) and self:ChargesFractional() > 1.8) or
           (Player:BuffUp(SpellFury.RecklessnessBuff) and self:ChargesFractional() > 1.5) then
          return true
        end
      end
    end
    
    if self == SpellFury.Charge then
      return BaseCheck and (self:Charges() >= 1 and not Target:IsInRange(8) and Target:IsInRange(25))
    end
    
    return BaseCheck
  end
, 72)

local FuryOldSpellIsReady
FuryOldSpellIsReady = HL.AddCoreOverride ("Spell.IsReady",
  function (self, Range, AoESpell, ThisUnit, BypassRecovery, Offset)
    -- Block all abilities during Charge
    if Player:IsChanneling(SpellFury.Charge) then
      return false
    end
    
    local BaseCheck = FuryOldSpellIsReady(self, Range, AoESpell, ThisUnit, BypassRecovery, Offset)
    
    if BaseCheck then
      if self == SpellFury.Rampage then
        -- Enhanced Rampage timing
        if not Player:BuffUp(SpellFury.EnrageBuff) then
          return true -- Always allow Rampage if not Enraged
        end
        
        -- Check if we should delay Rampage
        if Warrior.EnhancedStats.PredictedBurstWindow then
          -- Don't suggest Rampage during burst windows unless we're about to cap rage
          if Player:Rage() >= 95 then
            return true
          end
          -- Check for better abilities
          if SpellFury.Execute:IsReady() or 
             SpellFury.Bloodbath:IsReady() or 
             SpellFury.CrushingBlow:IsReady() then
            return false
          end
        end
        
        -- Consider Anger Management
        if SpellFury.AngerManagement:IsAvailable() then
          local recklessnessCooldown = SpellFury.Recklessness:CooldownRemains()
          -- More aggressive rage spending for CDR if Recklessness is far from ready
          if recklessnessCooldown > 30 and Player:Rage() >= 50 then
            return true
          end
          -- Normal Anger Management check
          if Player:Rage() >= 40 then
            return true
          end
        end
        
        -- Don't count predicted rage if we're already at 80+ rage
        local predictedRage = Player:Rage() >= 80 and 0 or Warrior.EnhancedStats.NextRageGen
        return (Player:Rage() + predictedRage) >= self:Cost()
      elseif self == SpellFury.Execute then
        -- Enhanced execute timing
        return Warrior.EnhancedStats.OptimalExecuteWindow or
               (Target:HealthPercentage() < 35 and Warrior.EnhancedStats.PredictedBurstWindow) or
               (Player:BuffUp(SpellFury.SuddenDeathBuff) and 
                (Player:BuffStack(SpellFury.SuddenDeathBuff) == 2 or 
                 Player:BuffRemains(SpellFury.SuddenDeathBuff) < 2))
      elseif self == SpellFury.Bloodbath then
        -- Improved Bloodbath conditions
        return (Warrior.EnhancedStats.PredictedCritChance >= 85 and Player:BuffUp(SpellFury.EnrageBuff)) or
               Player:BuffStack(SpellFury.BloodcrazeBuff) >= 3 or
               (Target:HealthPercentage() < 35 and Player:BuffUp(SpellFury.RecklessnessBuff))
      elseif self == SpellFury.RagingBlow then
        -- Enhanced Raging Blow priority
        return (Player:BuffDown(SpellFury.RecklessnessBuff) and self:ChargesFractional() > 1.8) or
               (Player:BuffUp(SpellFury.RecklessnessBuff) and self:ChargesFractional() > 1.5)
      end
    end
    
    return BaseCheck
  end
, 72)

-- Protection, ID: 73
local ProtOldSpellIsCastable
ProtOldSpellIsCastable = HL.AddCoreOverride ("Spell.IsCastable",
  function (self, BypassRecovery, Range, AoESpell, ThisUnit, Offset)
    local BaseCheck = ProtOldSpellIsCastable(self, BypassRecovery, Range, AoESpell, ThisUnit, Offset)
    if self == SpellProt.Charge then
      return BaseCheck and (self:Charges() >= 1 and not Target:IsInRange(8))
    elseif self == SpellProt.HeroicThrow or self == SpellProt.TitanicThrow then
      return BaseCheck and (not Target:IsInRange(8))
    elseif self == SpellProt.Avatar then
      return BaseCheck and (Player:BuffDown(SpellProt.AvatarBuff))
    elseif self == SpellProt.Intervene then
      return BaseCheck and (Player:IsInParty() or Player:IsInRaid())
    else
      return BaseCheck
    end
  end
, 73)

-- Example (Arcane Mage)
-- HL.AddCoreOverride ("Spell.IsCastableP",
-- function (self, Range, AoESpell, ThisUnit, BypassRecovery, Offset)
--   if Range then
--     local RangeUnit = ThisUnit or Target
--     return self:IsLearned() and self:CooldownRemainsP( BypassRecovery, Offset or "Auto") == 0 and RangeUnit:IsInRange( Range, AoESpell )
--   elseif self == SpellArcane.MarkofAluneth then
--     return self:IsLearned() and self:CooldownRemainsP( BypassRecovery, Offset or "Auto") == 0 and not Player:IsCasting(self)
--   else
--     return self:IsLearned() and self:CooldownRemainsP( BypassRecovery, Offset or "Auto") == 0
--   end
-- end
-- , 62)
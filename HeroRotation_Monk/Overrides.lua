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
  local SpellBM = Spell.Monk.Brewmaster
  local SpellWW = Spell.Monk.Windwalker
  local SpellMW = Spell.Monk.Mistweaver
-- Lua

--- ============================ CONTENT ============================
-- Brewmaster, ID: 268
local BMOldSpellIsCastable
BMOldSpellIsCastable = HL.AddCoreOverride ("Spell.IsCastable",
  function (self, BypassRecovery, Range, AoESpell, ThisUnit, Offset)
    local BaseCheck = BMOldSpellIsCastable(self, BypassRecovery, Range, AoESpell, ThisUnit, Offset)
    if self == SpellBM.TouchofDeath then
      return BaseCheck and self:IsUsable()
    elseif self == SpellBM.ChiBurst then
      return BaseCheck and not Player:IsCasting(self)
    else
      return BaseCheck
    end
  end
, 268)

-- Windwalker, ID: 269
local WWOldSpellIsCastable
WWOldSpellIsCastable = HL.AddCoreOverride ("Spell.IsCastable",
  function (self, BypassRecovery, Range, AoESpell, ThisUnit, Offset)
    local BaseCheck = WWOldSpellIsCastable(self, BypassRecovery, Range, AoESpell, ThisUnit, Offset)
    if self == SpellWW.ChiBurst then
      return BaseCheck and not Player:IsCasting(self)
    else
      return BaseCheck
    end
  end
, 269)

-- Mistweaver, ID: 270
local MWOldSpellIsCastable
MWOldSpellIsCastable = HL.AddCoreOverride ("Spell.IsCastable",
  function (self, BypassRecovery, Range, AoESpell, ThisUnit, Offset)
    local BaseCheck = MWOldSpellIsCastable and MWOldSpellIsCastable(self, BypassRecovery, Range, AoESpell, ThisUnit, Offset) or 
      (self:IsLearned() and self:CooldownRemains( BypassRecovery, Offset or "Auto") == 0)
    if self == SpellMW.CracklingJadeLightning then
      return BaseCheck and not Player:IsChanneling() and Player:Energy() >= 20
    else
      return BaseCheck
    end
  end
, 270)

-- Add channeling override
HL.AddCoreOverride("Player.IsChanneling",
  function(self, ...)
    if self:IsCasting() then
      local CastingInfo = self:CastingInfo()
      if CastingInfo == SpellMW.CracklingJadeLightning:Name() then
        return true
      end
    end
    return false
  end
, 270)

-- Add buff override for Mistweaver
local MWOldBuffUp
MWOldBuffUp = HL.AddCoreOverride("Player.BuffUp",
  function(self, Spell, AnyCaster, Offset)
    if Spell == SpellMW.JadeEmpowermentBuff then
      local name = AuraUtil.FindAuraByName(Spell:Name(), "player", "HELPFUL")
      return name ~= nil
    end
    -- Use standard check for other buffs
    return MWOldBuffUp and MWOldBuffUp(self, Spell, AnyCaster, Offset) or false
  end
, 270)

-- Add buff stack override
local MWOldBuffStack
MWOldBuffStack = HL.AddCoreOverride("Player.BuffStack",
  function(self, Spell, AnyCaster, Offset)
    if Spell == SpellMW.JadeEmpowermentBuff then
      local name, _, count = AuraUtil.FindAuraByName(Spell:Name(), "player", "HELPFUL")
      return count or 0
    end
    -- Use standard check for other buffs
    return MWOldBuffStack and MWOldBuffStack(self, Spell, AnyCaster, Offset) or 0
  end
, 270)

-- Add buff remains override
local MWOldBuffRemains
MWOldBuffRemains = HL.AddCoreOverride("Player.BuffRemains", 
  function(self, Spell, AnyCaster, Offset)
    if Spell == SpellMW.JadeEmpowermentBuff then
      local name, _, _, _, duration, expirationTime = AuraUtil.FindAuraByName(Spell:Name(), "player", "HELPFUL")
      if name then
        return expirationTime - GetTime()
      end
      return 0
    end
    return MWOldBuffRemains and MWOldBuffRemains(self, Spell, AnyCaster, Offset) or 0
  end
, 270)

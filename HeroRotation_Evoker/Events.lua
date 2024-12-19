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
-- File Locals
HR.Commons.Evoker = {}
local Evoker = HR.Commons.Evoker

-- Pre-allocated tables for enemy tracking
Evoker.Enemies = {
  Melee = {},
  Range8 = {},
  Range25 = {},
  Range40 = {},
  LastUpdate = 0
}

-- Pre-allocated tables for buff tracking
Evoker.Buffs = {
  EbonMight = {},
  EssenceBurst = {},
  LastUpdate = 0
}

-- Add optimized buff tracking
Evoker.BuffTracker = {
  LastUpdate = 0,
  Buffs = {
    EbonMight = { remains = 0, stacks = 0 },
    EssenceBurst = { remains = 0, stacks = 0 },
    ImminentDestruction = { remains = 0 },
    TipTheScales = { remains = 0 }
  },
  Debuffs = {
    TemporalWound = { remains = 0 },
    Bombardments = { remains = 0 }
  }
}

-- Reset function to wipe tables instead of recreating
function Evoker.ResetTables()
  wipe(Evoker.Enemies.Melee)
  wipe(Evoker.Enemies.Range8)
  wipe(Evoker.Enemies.Range25)
  wipe(Evoker.Enemies.Range40)
  Evoker.Enemies.LastUpdate = 0
  
  wipe(Evoker.Buffs.EbonMight)
  wipe(Evoker.Buffs.EssenceBurst)
  Evoker.Buffs.LastUpdate = 0
end

-- Register events for table maintenance
HL:RegisterForEvent(function()
  Evoker.ResetTables()
end, "PLAYER_REGEN_ENABLED", "PLAYER_SPECIALIZATION_CHANGED")

--- ============================ CONTENT ============================
--- ======= NON-COMBATLOG =======
HL:RegisterForEvent(
  function(Event, Arg1, Arg2)
    -- Ensure it's the player
    if Arg1 ~= "player"then
      return
    end

    if Arg2 == "ESSENCE" then
      Cache.Persistent.Player.LastPowerUpdate = GetTime()
    end
  end,
  "UNIT_POWER_UPDATE"
)

HL:RegisterForSelfCombatEvent(
  function(_, _, _, _, _, _, _, DestGUID, _, _, _, SpellID)
    if SpellID == 369374 then
      Evoker.FirestormTracker[DestGUID] = GetTime()
    end
  end,
  "SPELL_DAMAGE"
)

HL:RegisterForCombatEvent(
  function(_, _, _, _, _, _, _, DestGUID)
    if Evoker.FirestormTracker[DestGUID] then
      Evoker.FirestormTracker[DestGUID] = nil
    end
  end,
  "UNIT_DIED",
  "UNIT_DESTROYED"
)

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

-- Update buff tracking function
function Evoker.UpdateBuffs()
  local now = GetTime()
  if now - Evoker.BuffTracker.LastUpdate > 0.1 then
    local Buffs = Evoker.BuffTracker.Buffs
    local Debuffs = Evoker.BuffTracker.Debuffs
    
    -- Update buffs
    Buffs.EbonMight.remains = Player:BuffRemains(S.EbonMightSelfBuff)
    Buffs.EbonMight.stacks = Player:BuffStack(S.EbonMightSelfBuff)
    Buffs.EssenceBurst.remains = Player:BuffRemains(S.EssenceBurstBuff)
    Buffs.EssenceBurst.stacks = Player:BuffStack(S.EssenceBurstBuff)
    Buffs.ImminentDestruction.remains = Player:BuffRemains(S.ImminentDestructionBuff)
    Buffs.TipTheScales.remains = Player:BuffRemains(S.TipTheScalesBuff)
    
    -- Update debuffs
    if Target:Exists() then
      Debuffs.TemporalWound.remains = Target:DebuffRemains(S.TemporalWoundDebuff)
      Debuffs.Bombardments.remains = Target:DebuffRemains(S.BombardmentsDebuff)
    end
    
    Evoker.BuffTracker.LastUpdate = now
  end
end

-- Reset function
function Evoker.ResetBuffTracker()
  wipe(Evoker.BuffTracker.Buffs)
  wipe(Evoker.BuffTracker.Debuffs)
  Evoker.BuffTracker.LastUpdate = 0
end

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
Evoker.Cache = {
  EmpowerTimes = {},
  BuffTracker = {
    LastUpdate = 0,
    EbonMight = 0,
    EssenceBurst = 0,
    ImminentDestruction = 0
  },
  SpellData = {
    LastUpdate = 0,
    FireBreathCD = 0,
    UpheavalCD = 0,
    EbonMightCD = 0,
    BreathOfEonsCD = 0
  }
}

-- Add cache reset function
function Evoker.ResetCache()
  wipe(Evoker.Cache.EmpowerTimes)
  Evoker.Cache.BuffTracker.LastUpdate = 0
  Evoker.Cache.SpellData.LastUpdate = 0
end

-- Register cache reset events
HL:RegisterForEvent(function()
  Evoker.ResetCache()
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

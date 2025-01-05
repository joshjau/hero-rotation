--- ============================ HEADER ============================
--- Mistweaver Monk DPS/Fistweaving Module
--- Supports two modes based on CDs toggle:
--- CDsON: Pure damage focus (4-stack rotation)
--- CDsOFF: Fistweaving with healing focus (3-stack rotation)
--- Built around proper stack management and Rising Sun Kick usage
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroDBC
local DBC = HeroDBC.DBC
-- HeroLib
local HL         = HeroLib
local Cache      = HeroCache
local Unit      = HL.Unit
local Player    = Unit.Player
local Target    = Unit.Target
local Spell     = HL.Spell
local Item      = HL.Item
-- HeroRotation
local HR        = HeroRotation
local Cast      = HR.Cast
local AoEON     = HR.AoEON
local CDsON     = HR.CDsON

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Spells
local S = Spell.Monk.Mistweaver
-- Add these new spells
S.InvokeChiJi             = Spell(325197)
S.InvokeYulon             = Spell(322118)
S.InvokersDelight         = Spell(388661)
S.SecretInfusion         = Spell(388491)
S.ThunderFocusTeaBuff    = Spell(116680)
S.DanceofChijiBuff       = Spell(325202)
S.JadefireStompBuff      = Spell(388663)

-- Items
local I = Item.Monk.Mistweaver

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  -- Trinkets
}

-- Rotation Var
local Enemies5y
local EnemiesCount5

-- GUI Settings
local Everyone = HR.Commons.Everyone
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Monk.Commons,
  CommonsOGCD = HR.GUISettings.APL.Monk.CommonsOGCD,
  CommonsDS = HR.GUISettings.APL.Monk.CommonsDS,
  Mistweaver = HR.GUISettings.APL.Monk.Mistweaver
}

-- Add this function before APL()
local function Precombat()
  -- Snapshot stats and use consumables
  if Settings.Commons.Enabled.Potions then
    local PotionSelected = Everyone.PotionSelected()
    if PotionSelected and PotionSelected:IsReady() then
      if Cast(PotionSelected, nil, Settings.CommonsDS.DisplayStyle.Potions) then return "potion precombat"; end
    end
  end

  -- Racial abilities pre-combat
  if S.BloodFury:IsCastable() then
    if Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury precombat"; end
  end

  -- Chi Burst - Valuable pre-pull for both healing and damage
  -- Try to hit multiple targets if possible
  if S.ChiBurst:IsCastable() and not Player:IsMoving() and EnemiesCount5 >= 3 then
    if Cast(S.ChiBurst, nil, nil, not Target:IsInRange(40)) then return "chi_burst precombat"; end
  end

  -- Chi Wave - Consistent damage/healing that bounces
  if S.ChiWave:IsCastable() then
    if Cast(S.ChiWave, nil, nil, not Target:IsInRange(40)) then return "chi_wave precombat"; end
  end

  -- Jadefire Stomp - Apply buffs before combat
  if S.JadefireStomp:IsReady() then
    if Cast(S.JadefireStomp, nil, nil, not Target:IsInRange(30)) then return "jadefire_stomp precombat"; end
  end

  return
end

local function PureDPSPriority()  -- Used when CDs ON - Maximum damage
  -- Invoke Chi-ji/Yu'lon
  if S.InvokeChiJi:IsReady() and S.InvokersDelight:IsAvailable() then
    if Cast(S.InvokeChiJi) then return "invoke_chiji pure_dps"; end
  end
  if S.InvokeYulon:IsReady() and S.InvokersDelight:IsAvailable() then
    if Cast(S.InvokeYulon) then return "invoke_yulon pure_dps"; end
  end

  -- Celestial Conduit
  if S.CelestialConduit:IsReady() then
    if Cast(S.CelestialConduit) then return "celestial_conduit pure_dps"; end
  end

  -- Thunder Focus Tea + Rising Sun Kick combo
  if S.ThunderFocusTea:IsReady() then
    if Cast(S.ThunderFocusTea, Settings.Mistweaver.OffGCDasOffGCD.ThunderFocusTea) then return "thunder_focus_tea pure_dps"; end
  end
  if S.RisingSunKick:IsReady() and S.SecretInfusion:IsAvailable() and Player:BuffUp(S.ThunderFocusTeaBuff) then
    if Cast(S.RisingSunKick) then return "rising_sun_kick pure_dps tft"; end
  end

  -- Fixed rotation without complex resets
  -- Rising Sun Kick on CD
  if S.RisingSunKick:IsReady() then
    if Cast(S.RisingSunKick, nil, nil, not Target:IsInMeleeRange(5)) then return "rising_sun_kick pure_dps"; end
  end

  -- Touch of Death
  if S.TouchofDeath:IsReady() then
    if Cast(S.TouchofDeath, nil, nil, not Target:IsInMeleeRange(5)) then return "touch_of_death pure_dps"; end
  end

  -- Chi Wave
  if S.ChiWave:IsReady() then
    if Cast(S.ChiWave, nil, nil, not Target:IsInRange(40)) then return "chi_wave pure_dps"; end
  end

  -- Jadefire Stomp
  if S.JadefireStomp:IsReady() then
    if Cast(S.JadefireStomp, nil, nil, not Target:IsInRange(30)) then return "jadefire_stomp pure_dps"; end
  end

  -- Simple 4-stack Blackout Kick usage
  if S.BlackoutKick:IsReady() and Player:BuffStack(S.TeachingsoftheMonasteryBuff) >= 4 then
    if Cast(S.BlackoutKick, nil, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick pure_dps"; end
  end

  -- Tiger Palm to build stacks
  if S.TigerPalm:IsReady() and Player:BuffStack(S.TeachingsoftheMonasteryBuff) < 4 then
    if Cast(S.TigerPalm, nil, nil, not Target:IsInMeleeRange(5)) then return "tiger_palm pure_dps"; end
  end

  return false
end

local function FistweavingPriority()  -- Used when CDs OFF - Normal fistweaving
  -- Dance of Chi-ji proc
  if S.SpinningCraneKick:IsReady() and Player:BuffUp(S.DanceofChijiBuff) then
    if Cast(S.SpinningCraneKick) then return "spinning_crane_kick dance_proc"; end
  end

  -- Chi Burst in AoE
  if S.ChiBurst:IsReady() and not Player:IsMoving() and EnemiesCount5 >= 2 then
    if Cast(S.ChiBurst) then return "chi_burst aoe"; end
  end

  -- Jadefire Stomp logic
  if S.JadefireStomp:IsReady() then
    if (EnemiesCount5 >= 4 and EnemiesCount5 <= 10) or Player:BuffDown(S.JadefireStompBuff) then
      if Cast(S.JadefireStomp) then return "jadefire_stomp"; end
    end
  end

  -- Rising Sun Kick - Core ability for HoT extension and Crane Style healing
  -- Extends Renewing Mist duration and provides passive healing
  if S.RisingSunKick:IsReady() then
    if Cast(S.RisingSunKick, nil, nil, not Target:IsInMeleeRange(5)) then return "rising_sun_kick fistweave"; end
  end

  -- Chi Burst - Strong AoE healing/damage if can hit multiple allies
  if S.ChiBurst:IsReady() and not Player:IsMoving() and EnemiesCount5 >= 3 then
    if Cast(S.ChiBurst, nil, nil, not Target:IsInRange(40)) then return "chi_burst fistweave"; end
  end

  -- Chi Wave - Consistent healing that bounces between allies and enemies
  if S.ChiWave:IsReady() then
    if Cast(S.ChiWave, nil, nil, not Target:IsInRange(40)) then return "chi_wave fistweave"; end
  end

  -- Jadefire Stomp - Maintains important healing buffs
  -- Keep Awakened Jadefire and Jadefire Teachings active
  if S.JadefireStomp:IsReady() then
    if Cast(S.JadefireStomp, nil, nil, not Target:IsInRange(30)) then return "jadefire_stomp fistweave"; end
  end

  -- Thunder Focus Tea - Use with healing abilities
  if S.ThunderFocusTea:IsReady() then
    if Cast(S.ThunderFocusTea, Settings.Mistweaver.OffGCDasOffGCD.ThunderFocusTea) then return "thunder_focus_tea fistweave"; end
  end

  -- Blackout Kick at 3 stacks
  -- Each stack causes additional hits, providing more healing through Crane Style
  if S.BlackoutKick:IsReady() and Player:BuffStack(S.TeachingsoftheMonasteryBuff) >= 3 then
    if Cast(S.BlackoutKick, nil, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick fistweave"; end
  end

  -- Tiger Palm to build stacks
  -- Generates ToM stacks for enhanced healing through Blackout Kick
  if S.TigerPalm:IsReady() and Player:BuffStack(S.TeachingsoftheMonasteryBuff) < 3 then
    if Cast(S.TigerPalm, nil, nil, not Target:IsInMeleeRange(5)) then return "tiger_palm fistweave"; end
  end

  -- Spinning Crane Kick for AoE healing
  -- Only use in AoE situations where the healing is valuable
  if S.SpinningCraneKick:IsReady() and EnemiesCount5 > 4 then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick fistweave"; end
  end

  return false
end

local function APL()
  -- Unit Update
  Enemies5y = Player:GetEnemiesInMeleeRange(5)
  if AoEON() then
    EnemiesCount5 = #Enemies5y
  else 
    EnemiesCount5 = 1
  end

  -- Precombat
  if not Player:AffectingCombat() then
    local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    return
  end

  -- Main Combat Rotation
  if Everyone.TargetIsValid() then
    -- Interrupts
    if Everyone.Interrupt(S.SpearHandStrike, Settings.CommonsOGCD.OffGCDasOffGCD.SpearHandStrike, false) then return "spear hand strike"; end

    -- Choose priority based on CDs toggle
    if CDsON() then
      local ShouldReturn = PureDPSPriority(); if ShouldReturn then return ShouldReturn; end
    else
      local ShouldReturn = FistweavingPriority(); if ShouldReturn then return ShouldReturn; end
    end

    -- Shared low priority abilities regardless of mode
    -- Expel Harm when buffs align
    if S.ExpelHarm:IsReady() and (not Settings.Mistweaver.RequireExpelHarmBuffs or 
      (Player:BuffUp(S.EnvelopingMistBuff) and Player:BuffUp(S.RenewingMistBuff) and Player:BuffUp(S.ChiHarmonyBuff))) then
      if Cast(S.ExpelHarm, nil, nil, not Target:IsInRange(20)) then return "expel_harm"; end
    end

    -- Crackling Jade Lightning when at range
    if S.CracklingJadeLightning:IsReady() and not Target:IsInMeleeRange(5) and Target:IsInRange(40) then
      if Cast(S.CracklingJadeLightning) then return "crackling_jade_lightning ranged"; end
    end
  end
end

local function Init()
  HR.Print("Mistweaver Monk rotation has been initialized")
end

HR.SetAPL(270, APL, Init) 
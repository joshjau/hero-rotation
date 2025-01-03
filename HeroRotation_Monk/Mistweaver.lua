--- ============================ HEADER ============================
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
  -- Potion
  if Settings.Commons.Enabled.Potions then
    local PotionSelected = Everyone.PotionSelected()
    if PotionSelected and PotionSelected:IsReady() then
      if Cast(PotionSelected, nil, Settings.CommonsDS.DisplayStyle.Potions) then return "potion precombat"; end
    end
  end

  -- Chi Burst
  if S.ChiBurst:IsCastable() and not Player:IsMoving() then
    if Cast(S.ChiBurst, nil, nil, not Target:IsInRange(40)) then return "chi_burst precombat"; end
  end

  -- Chi Wave
  if S.ChiWave:IsCastable() then
    if Cast(S.ChiWave, nil, nil, not Target:IsInRange(40)) then return "chi_wave precombat"; end
  end

  -- Jadefire Stomp
  if S.JadefireStomp:IsReady() then
    if Cast(S.JadefireStomp, nil, nil, not Target:IsInRange(30)) then return "jadefire_stomp precombat"; end
  end

  return
end

local function APL()
  -- Unit Update
  Enemies5y = Player:GetEnemiesInMeleeRange(5)
  if AoEON() then
    EnemiesCount5 = #Enemies5y
  else 
    EnemiesCount5 = 1
  end

  -- Out of Combat
  if not Player:AffectingCombat() then
    local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    return
  end

  -- In Combat
  if Everyone.TargetIsValid() then
    -- Interrupts
    if Everyone.Interrupt(S.SpearHandStrike, Settings.CommonsOGCD.OffGCDasOffGCD.SpearHandStrike, false) then return "spear hand strike"; end

    -- Touch of Death
    if S.TouchofDeath:IsReady() then
      if Cast(S.TouchofDeath, nil, nil, not Target:IsInMeleeRange(5)) then return "touch_of_death"; end
    end

    -- Thunder Focus Tea (if CDs are enabled)
    if CDsON() and Settings.Mistweaver.ThunderFocusTeaWithExpelHarm and S.ThunderFocusTea:IsReady() and (S.ExpelHarm:IsReady() or S.ExpelHarm:CooldownRemains() < 2) then
      if Cast(S.ThunderFocusTea, Settings.Mistweaver.OffGCDasOffGCD.ThunderFocusTea) then return "thunder_focus_tea"; end
    end

    -- Chi Burst
    if S.ChiBurst:IsReady() and not Player:IsMoving() then
      if Cast(S.ChiBurst, nil, nil, not Target:IsInRange(40)) then return "chi_burst"; end
    end

    -- Chi Wave 
    if S.ChiWave:IsReady() then
      if Cast(S.ChiWave, nil, nil, not Target:IsInRange(40)) then return "chi_wave"; end
    end

    -- Celestial Conduit for AoE
    if S.CelestialConduit:IsReady() and EnemiesCount5 > 1 then
      if Cast(S.CelestialConduit, nil, nil, not Target:IsInRange(40)) then return "celestial_conduit"; end
    end

    -- Expel Harm with buffs
    if S.ExpelHarm:IsReady() and (not Settings.Mistweaver.RequireExpelHarmBuffs or 
      (Player:BuffUp(S.EnvelopingMistBuff) and Player:BuffUp(S.RenewingMistBuff) and Player:BuffUp(S.ChiHarmonyBuff))) then
      if Cast(S.ExpelHarm, nil, nil, not Target:IsInRange(20)) then return "expel_harm"; end
    end

    -- Jadefire Stomp
    if S.JadefireStomp:IsReady() then
      if Cast(S.JadefireStomp, nil, nil, not Target:IsInRange(30)) then return "jadefire_stomp"; end
    end

    -- Spinning Crane Kick for AoE
    if S.SpinningCraneKick:IsReady() and EnemiesCount5 >= Settings.Mistweaver.SpinningCraneKickThreshold then
      if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick"; end
    end

    -- Rising Sun Kick
    if S.RisingSunKick:IsReady() then
      if Cast(S.RisingSunKick, nil, nil, not Target:IsInMeleeRange(5)) then return "rising_sun_kick"; end
    end

    -- Alternate Blackout Kick/Tiger Palm for RSK reset chance
    if Player:PrevGCD(1, S.BlackoutKick) then
      if S.TigerPalm:IsReady() then
        if Cast(S.TigerPalm, nil, nil, not Target:IsInMeleeRange(5)) then return "tiger_palm alternating"; end
      end
    else
      if S.BlackoutKick:IsReady() then
        if Cast(S.BlackoutKick, nil, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick alternating"; end
      end
    end
  end
end

local function Init()
  HR.Print("Mistweaver Monk rotation has been initialized")
end

HR.SetAPL(270, APL, Init) 
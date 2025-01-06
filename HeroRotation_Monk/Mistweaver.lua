--- ============================ HEADER ============================
--- Mistweaver Monk DPS/Fistweaving Module
--- Supports two modes based on CDs toggle:
--- CDsON: Pure damage focus (optimal DPS rotation)
--- CDsOFF: Fistweaving with healing focus (balances healing through damage)
--- Built around proper stack management and Rising Sun Kick usage
--- Current version focuses on 11.0.5 changes including Jade Empowerment mechanics
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
S.RisingMist              = Spell(274909)
S.RenewingMistBuff       = Spell(119611)
S.TeachingsoftheMonasteryBuff = Spell(202090)
S.JadeFireTeachings      = Spell(388023)
S.CraneStyle             = Spell(383999)
S.PoolofMists            = Spell(388477)
S.JadeEmpowerment          = Spell(467317)
S.AncientTeachings         = Spell(388023)
S.CracklingJadeLightning   = Spell(117952)
S.JadeEmpowermentBuff      = Spell(467317)

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

-- Helper function for Crackling Jade Lightning channeling conditions
-- CJL is particularly important with Jade Empowerment buff in 11.0.5+
local function CanChannelCJL()
  local isReady = S.CracklingJadeLightning:IsReady()
  local notMoving = not Player:IsMoving()
  local inRange = Target:IsInRange(40)
  local hasEnergy = Player:Energy() >= 20  -- Initial energy cost check
  local notChanneling = not Player:IsChanneling()

  return isReady and notMoving and inRange and hasEnergy and notChanneling
end

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

  -- Chi Burst - Single target pre-pull
  if S.ChiBurst:IsReady() and not Player:IsMoving() then
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
  -- Crackling Jade Lightning with Jade Empowerment
  -- Only used in AoE (4+ targets) when empowered by Thunder Focus Tea
  -- Each Jade Empowerment stack is a separate use, not a power increase
  if S.CracklingJadeLightning:IsReady() and Player:BuffUp(S.JadeEmpowermentBuff) and EnemiesCount5 >= 4 then
    if Cast(S.CracklingJadeLightning, nil, nil, not Target:IsSpellInRange(S.CracklingJadeLightning)) then 
      return "crackling_jade_lightning empowered aoe"; 
    end
  end

  -- Thunder Focus Tea optimization
  -- Used primarily for RSK cooldown reduction in pure DPS
  -- Also provides Jade Empowerment for AoE situations
  if S.ThunderFocusTea:IsReady() then
    if S.RisingSunKick:CooldownRemains() > 9 
       and (not Player:BuffUp(S.RenewingMistBuff) or Player:BuffRemains(S.RenewingMistBuff) > 8)
       and (not S.SecretInfusion:IsAvailable() or Player:HasTier(31, 2)) then
      if Cast(S.ThunderFocusTea, Settings.Mistweaver.OffGCDasOffGCD.ThunderFocusTea) then return "thunder_focus_tea for_rsk"; end
    end
  end

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

  -- Jadefire Stomp for buffs
  if S.JadefireStomp:IsReady() and (Player:BuffDown(S.AncientConcordanceBuff) or Player:BuffDown(S.AwakenedJadefireBuff)) then
    if Cast(S.JadefireStomp, nil, nil, not Target:IsInRange(30)) then return "jadefire_stomp pure_dps"; end
  end

  -- Chi Burst in AoE
  if S.ChiBurst:IsReady() and not Player:IsMoving() and EnemiesCount5 >= 2 then
    if Cast(S.ChiBurst, nil, nil, not Target:IsInRange(40)) then return "chi_burst aoe pure_dps"; end
  end

  -- Spinning Crane Kick in AoE
  if S.SpinningCraneKick:IsReady() and (EnemiesCount5 >= 4 or Player:BuffUp(S.DanceofChijiBuff)) then
    if Cast(S.SpinningCraneKick) then return "spinning_crane_kick aoe pure_dps"; end
  end

  return false
end

local function FistweavingPriority()  -- Used when CDs OFF - Optimized for DPS healing
  -- Touch of Death - Highest priority
  -- Important for both burst damage and healing through Ancient Teachings
  if S.TouchofDeath:IsReady() then
    if Cast(S.TouchofDeath, nil, nil, not Target:IsInMeleeRange(5)) then return "touch_of_death fistweave"; end
  end

  -- Rising Sun Kick priority
  -- Core ability for both damage and healing:
  -- 1. Extends Renewing Mist duration
  -- 2. Triggers Ancient Teachings healing
  -- 3. Core damage ability
  if S.RisingSunKick:IsReady() then
    if Cast(S.RisingSunKick, nil, nil, not Target:IsInMeleeRange(5)) then return "rising_sun_kick fistweave"; end
  end

  -- Blackout Kick for RSK resets
  -- Important to track stacks and cooldown timing
  -- Used to maintain healing through damage and reset RSK
  if S.BlackoutKick:IsReady() then
    local rskCD = S.RisingSunKick:CooldownRemains()
    local tomStacks = Player:BuffStack(S.TeachingsoftheMonasteryBuff)
    if (tomStacks >= 3 and rskCD > 3) or (rskCD > Player:GCD() * 2) then
      if Cast(S.BlackoutKick, nil, nil, not Target:IsInMeleeRange(5)) then 
        if S.RisingSunKick:IsReady() then
          if Cast(S.RisingSunKick, nil, nil, not Target:IsInMeleeRange(5)) then return "rising_sun_kick fistweave reset"; end
        end
        return "blackout_kick fistweave"; 
      end
    end
  end

  -- Tiger Palm for RSK resets and stack building
  if S.TigerPalm:IsReady() then
    local rskCD = S.RisingSunKick:CooldownRemains()
    if Player:BuffStack(S.TeachingsoftheMonasteryBuff) < 3 or rskCD > Player:GCD() then
      if Cast(S.TigerPalm, nil, nil, not Target:IsInMeleeRange(5)) then 
        if S.RisingSunKick:IsReady() then
          if Cast(S.RisingSunKick, nil, nil, not Target:IsInMeleeRange(5)) then return "rising_sun_kick fistweave reset"; end
        end
        return "tiger_palm fistweave"; 
      end
    end
  end

  -- Lower priority abilities
  -- Jadefire Stomp for buffs
  if S.JadefireStomp:IsReady() and (Player:BuffDown(S.AncientConcordanceBuff) or Player:BuffDown(S.AwakenedJadefireBuff)) then
    if Cast(S.JadefireStomp, nil, nil, not Target:IsInRange(30)) then return "jadefire_stomp fistweave"; end
  end

  -- Chi Burst for AoE healing/damage
  if S.ChiBurst:IsReady() and not Player:IsMoving() and EnemiesCount5 >= 2 then
    if Cast(S.ChiBurst, nil, nil, not Target:IsInRange(40)) then return "chi_burst aoe"; end
  end

  -- Spinning Crane Kick only in heavy AoE situations
  if S.SpinningCraneKick:IsReady() and EnemiesCount5 >= 5 then
    if Cast(S.SpinningCraneKick) then return "spinning_crane_kick aoe"; end
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

    -- Remove ranged CJL usage to save it for empowered AoE only
  end
end

local function Init()
  -- Register spell effects
  S.CracklingJadeLightning:RegisterInFlight()
  S.CracklingJadeLightning:RegisterInFlightEffect(117952)
  
  -- Register buff tracking
  S.JadeEmpowermentBuff:RegisterAuraTracking()
  S.TeachingsoftheMonasteryBuff:RegisterAuraTracking()
  
  HR.Print("Mistweaver Monk rotation has been initialized")
end

HR.SetAPL(270, APL, Init) 
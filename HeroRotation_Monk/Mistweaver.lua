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
local CastAnnotated = HR.CastAnnotated
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
S.RushingJadeWind          = Spell(116847)
S.InvokeChiJiBuff          = Spell(343820)
S.RisingMistTalent         = Spell(274909)
S.EnvelopingBreathBuff     = Spell(343819)  -- Chi-Ji proc for instant cast
S.EnvelopingMist           = Spell(124682)
S.ExpelHarm                = Spell(322101)
S.RenewingMist           = Spell(115151)
S.ThunderFocusTea        = Spell(116680)
S.EssenceFont            = Spell(191837)
S.Revival                = Spell(115310)
S.LifeCocoon            = Spell(116849)
S.SoothingMist          = Spell(115175)
S.Vivify                = Spell(116670)
S.InstantVivifyBuff     = Spell(392883)     -- Various procs for instant Vivify
S.ThunderFocusTeaBuff  = Spell(116680)   -- TFT buff for instant/enhanced spells
S.TeaOfSerenityBuff     = Spell(388518)    -- Tea of Serenity buff
S.VivifyBuff             = Spell(116670)           -- Vivify buff
S.StrengthofSpirit          = Spell(443112)  -- Strength of the Black Ox buff
S.RushingWindKick          = Spell(467307)  -- Rushing Wind Kick (replaces RSK)

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
  CommonsDS = HR.GUISettings.APL.Monk.CommonsDS,
  CommonsOGCD = HR.GUISettings.APL.Monk.CommonsOGCD,
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

-- Helper function to check optimal Expel Harm conditions
local function ShouldUseExpelHarm()
  -- Emergency usage based on HP threshold
  if Player:HealthPercentage() <= Settings.Mistweaver.ExpelHarmHP then
    return true
  end

  -- Optimal damage transfer conditions
  local hasEnvelopingMist = Player:BuffUp(S.EnvelopingMistBuff)
  local hasRenewingMist = Player:BuffUp(S.RenewingMistBuff)
  local hasChiHarmony = Player:BuffUp(S.ChiHarmonyBuff)
  local hasTFT = S.ThunderFocusTea:IsReady()

  -- Best case: All buffs + TFT available
  if hasEnvelopingMist and hasRenewingMist and hasChiHarmony and hasTFT then
    return true, true  -- Second return indicates TFT usage
  end

  -- Good case: All required buffs without TFT
  if hasEnvelopingMist and hasRenewingMist and hasChiHarmony then
    return true, false
  end

  return false
end

-- Helper function for instant heals that should show on left
local function HealLeft(spell, displayStyle)
  return HR.CastLeft(spell, displayStyle) 
end

-- Helper function for regular healing casts
local function Heal(spell, displayStyle)
  return HR.Cast(spell, displayStyle)
end

-- Add this function before APL()
local function Precombat()
  -- Remove potion check
  -- if Settings.Commons.Enabled.Potions then
  --   local PotionSelected = Everyone.PotionSelected(Settings.Mistweaver.PotionType.Selected)
  --   if PotionSelected and PotionSelected:IsReady() then
  --     if Cast(PotionSelected, Settings.CommonsDS.DisplayStyle.Potions) then return "potion precombat"; end
  --   end
  -- end

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

local function FistweavingPriority()
  -- Track what we want to show in each window
  local mainIcon, leftIcon = nil, nil

  -- Check instant heal procs for left icon
  -- Give Enveloping Mist with Chi-Ji proc highest priority, but only at 3 stacks
  if S.EnvelopingMist:IsReady() and Player:BuffUp(S.InvokeChiJiBuff) and Player:BuffStack(S.InvokeChiJiBuff) >= 3 then
    leftIcon = {S.EnvelopingMist, Settings.Mistweaver.DisplayStyle.InstantEnvelopingMist, "instant_enveloping_mist left from chiji"}
  -- Add Strength of the Black Ox check for Enveloping Mist
  elseif S.EnvelopingMist:IsReady() and Player:BuffUp(S.StrengthofSpirit) then
    leftIcon = {S.EnvelopingMist, Settings.Mistweaver.DisplayStyle.InstantEnvelopingMist, "enveloping_mist left from black ox"}
  -- Then check other instant heals
  elseif S.RenewingMist:IsReady() and S.RenewingMist:Charges() > 0 then
    leftIcon = {S.RenewingMist, Settings.Mistweaver.DisplayStyle.RenewingMist, "renewing_mist left"}
  elseif S.Vivify:IsReady() and (Player:BuffUp(S.TeaOfSerenityBuff) or Player:BuffUp(S.ThunderFocusTeaBuff)) then
    leftIcon = {S.Vivify, Settings.Mistweaver.DisplayStyle.InstantVivify, "instant_vivify left"}
  end

  -- Check DPS abilities for main icon
  if S.RushingWindKick:IsReady() then  -- Check Rushing Wind Kick first
    mainIcon = {S.RushingWindKick, nil, "rushing_wind_kick main"}
  elseif S.RisingSunKick:IsReady() then  -- Fallback to RSK if not equipped
    mainIcon = {S.RisingSunKick, nil, "rising_sun_kick main"}
  elseif S.BlackoutKick:IsReady() then
    mainIcon = {S.BlackoutKick, nil, "blackout_kick main"}
  elseif S.TigerPalm:IsReady() then
    mainIcon = {S.TigerPalm, nil, "tiger_palm main"}
  end

  -- Cast both main and left if available
  if leftIcon then
    if HealLeft(leftIcon[1], leftIcon[2]) then return leftIcon[3]; end
  end
  if mainIcon then
    if Cast(mainIcon[1], nil, nil, not Target:IsInMeleeRange(5)) then return mainIcon[3]; end
  end

  return false
end

local function APL()
  -- Unit Update
  Enemies5y = Player:GetEnemiesInMeleeRange(5)
  EnemiesCount5 = 0
  if AoEON() then
    EnemiesCount5 = #Enemies5y
  else 
    EnemiesCount5 = Target:Exists() and 1 or 0
  end

  -- Main Combat Rotation
  if Everyone.TargetIsValid() then
    -- Interrupts
    if Everyone.Interrupt(S.SpearHandStrike, Settings.CommonsDS.DisplayStyle.Interrupts, false) then 
      return "spear hand strike"; 
    end

    -- Major Cooldowns (controlled by CD toggle)
    if CDsON() then
      -- Empowered Crackling Jade Lightning
      if S.CracklingJadeLightning:IsReady() and Player:BuffUp(S.JadeEmpowermentBuff) then
        local canChannel = CanChannelCJL()
        local singleEnemy = AoEON() and (#Enemies5y <= 1) or Target:Exists()
        
        if canChannel and singleEnemy then
          if Cast(S.CracklingJadeLightning, "Cooldown") then 
            return "crackling_jade_lightning empowered"; 
          end
        end
      end

      -- Thunder Focus Tea
      if S.ThunderFocusTea:IsReady() then
        if Cast(S.ThunderFocusTea, Settings.Mistweaver.DisplayStyle.ThunderFocusTea) then 
          return "thunder_focus_tea cd"; 
        end
      end

      -- Celestial Conduit
      if S.CelestialConduit:IsReady() then
        if Cast(S.CelestialConduit, Settings.Mistweaver.DisplayStyle.CelestialConduit) then 
          return "celestial_conduit cd"; 
        end
      end
    end

    -- Invoke Chi-ji (Red Crane) - Used on CD regardless of CD toggle
    if S.InvokeChiJi:IsReady() then
      if Cast(S.InvokeChiJi, Settings.Mistweaver.DisplayStyle.InvokeChiJi) then 
        return "invoke_chiji"; 
      end
    end

    -- Regular rotation (former FistweavingPriority)
    local ShouldReturn = FistweavingPriority(); if ShouldReturn then return ShouldReturn; end
  end
end

local function Init()
  -- Register spell effects
  S.CracklingJadeLightning:RegisterInFlight()
  S.CracklingJadeLightning:RegisterInFlightEffect(117952)
  
  -- Register buff tracking - move JadeEmpowerment to top for visibility
  S.JadeEmpowermentBuff:RegisterAuraTracking()
  if S.TeachingsoftheMonasteryBuff then S.TeachingsoftheMonasteryBuff:RegisterAuraTracking() end
  if S.EnvelopingBreathBuff then S.EnvelopingBreathBuff:RegisterAuraTracking() end
  if S.ThunderFocusTeaBuff then S.ThunderFocusTeaBuff:RegisterAuraTracking() end
  if S.TeaOfSerenityBuff then S.TeaOfSerenityBuff:RegisterAuraTracking() end
  if S.VivifyBuff then S.VivifyBuff:RegisterAuraTracking() end
  
  HR.Print("Mistweaver Monk rotation has been initialized")
end

HR.SetAPL(270, APL, Init) 
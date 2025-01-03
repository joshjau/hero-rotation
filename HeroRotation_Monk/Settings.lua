--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroRotation
local HR = HeroRotation
-- HeroLib
local HL = HeroLib
-- File Locals
local GUI = HL.GUI
local CreateChildPanel = GUI.CreateChildPanel
local CreatePanelOption = GUI.CreatePanelOption
local CreateARPanelOption = HR.GUI.CreateARPanelOption
local CreateARPanelOptions = HR.GUI.CreateARPanelOptions

--- ============================ CONTENT ============================
-- All settings here should be moved into the GUI someday.
HR.GUISettings.APL.Monk = {
  Commons = {
    Enabled = {
      Trinkets = true,
      Potions = true,
      Items = true,
    },
  },
  CommonsDS = {
    DisplayStyle = {
      -- Common
      Interrupts = "Cooldown",
      Items = "Suggested",
      Potions = "Suggested",
      Trinkets = "Suggested",
      -- Class Specific
    },
  },
  CommonsOGCD = {
    -- {Display GCD as OffGCD, ForceReturn}
    GCDasOffGCD = {
      Paralysis = true,
      RingOfPeace = true,
      SummonWhiteTigerStatue = true,
    },
    -- {Display OffGCD as OffGCD, ForceReturn}
    OffGCDasOffGCD = {
      Racials = true,
      SpearHandStrike = true,
    }
  },
  Brewmaster = {
    ExpelHarmHP = 70,
    PotionType = {
      Selected = "Tempered",
    },
    -- DisplayStyle for Brewmaster-only stuff
    DisplayStyle = {
      CelestialBrew = "Suggested",
      DampenHarm = "Suggested",
      FortifyingBrew = "Suggested",
      Purify = "SuggestedRight"
    },
    -- {Display GCD as OffGCD, ForceReturn}
    GCDasOffGCD = {
      -- Abilities
      BreathOfFire = false,
      ExpelHarm = false,
      ExplodingKeg = false,
      InvokeNiuzaoTheBlackOx = true,
      TouchOfDeath = true,
    },
    -- {Display OffGCD as OffGCD, ForceReturn}
    OffGCDasOffGCD = {
      -- Racials
      -- Abilities
      BlackOxBrew = true,
      PurifyingBrew = true,
    }
  },
  Windwalker = {
    FortifyingBrewHP = 40,
    IgnoreFSK = true,
    IgnoreToK = false,
    ShowFortifyingBrewCD = false,
    MotCCountThreshold = 5,
    MotCMinTimeThreshold = 5,
    PotionType = {
      Selected = "Tempered",
    },
    -- {Display GCD as OffGCD, ForceReturn}
    GCDasOffGCD = {
      -- Abilities
      CracklingJadeLightning = false,
      FortifyingBrew = true,
      InvokeXuenTheWhiteTiger = true,
      StormEarthAndFireFixate = false,
      TouchOfDeath = true,
      TouchOfKarma = true,
    },
    -- {Display OffGCD as OffGCD, ForceReturn}
    OffGCDasOffGCD = {
      -- Racials
      -- Abilities
      EnergizingElixir = true,
      Serenity = true,
      StormEarthAndFire = true,
    }
  },
  Mistweaver = {
    -- Add potion type settings
    PotionType = {
      Selected = "Tempered",
    },
    -- Remove SpinningCraneKickThreshold
    RequireExpelHarmBuffs = true,    -- Whether to require buffs for Expel Harm
    ThunderFocusTeaWithExpelHarm = true, -- Use TFT with Expel Harm
    -- {Display GCD as OffGCD, ForceReturn}
    GCDasOffGCD = {
      -- Abilities
      TouchofDeath = true,
      ExpelHarm = false,
      ChiBurst = false,
      ChiWave = false,
    },
    -- {Display OffGCD as OffGCD, ForceReturn}
    OffGCDasOffGCD = {
      -- Racials
      -- Abilities
      ThunderFocusTea = true,
    }
  },
}

HR.GUI.LoadSettingsRecursively(HR.GUISettings)

-- Child Panels
local ARPanel = HR.GUI.Panel
local CP_Monk = CreateChildPanel(ARPanel, "Monk")
local CP_MonkDS = CreateChildPanel(CP_Monk, "Class DisplayStyles")
local CP_MonkOGCD = CreateChildPanel(CP_Monk, "Class OffGCDs")
local CP_Windwalker = CreateChildPanel(CP_Monk, "Windwalker")
local CP_Brewmaster = CreateChildPanel(CP_Monk, "Brewmaster")
local CP_Mistweaver = CreateChildPanel(CP_Monk, "Mistweaver")

-- Monk
CreateARPanelOptions(CP_Monk, "APL.Monk.Commons")
CreateARPanelOptions(CP_MonkDS, "APL.Monk.CommonsDS")
CreateARPanelOptions(CP_MonkOGCD, "APL.Monk.CommonsOGCD")

-- Windwalker
CreateARPanelOptions(CP_Windwalker, "APL.Monk.Windwalker")
CreatePanelOption("CheckButton", CP_Windwalker, "APL.Monk.Windwalker.ShowFortifyingBrewCD", "Fortifying Brew", "Enable or disable Fortifying Brew recommendations.")
CreatePanelOption("CheckButton", CP_Windwalker, "APL.Monk.Windwalker.IgnoreToK", "Ignore Touch of Karma", "Enable this setting to allow you to ignore Touch of Karma without stalling the rotation. (NOTE: Touch of Karma will never be suggested if this is enabled)")
CreatePanelOption("CheckButton", CP_Windwalker, "APL.Monk.Windwalker.IgnoreFSK", "Ignore Flying Serpent Kick", "Enable this setting to allow you to ignore Flying Serpent Kick without stalling the rotation. (NOTE: Flying Serpent Kick will never be suggested if this is enabled)")
CreatePanelOption("Slider", CP_Windwalker, "APL.Monk.Windwalker.FortifyingBrewHP", {1, 100, 1}, "Fortifying Brew HP Threshold", "Set the HP threshold for when to suggest Fortifying Brew.")
CreatePanelOption("Slider", CP_Windwalker, "APL.Monk.Windwalker.MotCCountThreshold", {1, 10, 1}, "Mark of the Crane Count Threshold", "Allow the profile to cycle through targets to apply Mark of the Crane is below this number of targets with the debuff applied. Default: 5.")
CreatePanelOption("Slider", CP_Windwalker, "APL.Monk.Windwalker.MotCMinTimeThreshold", {1, 20, 1}, "Mark of the Crane Min Time Threshold", "Allow the profile to cycle through targets to apply Mark of the Crane if the remaining time on any Mark of the Crane debuff is below this number of seconds. Default: 5.")

-- Brewmaster
CreatePanelOption("Slider", CP_Brewmaster, "APL.Monk.Brewmaster.ExpelHarmHP", {1, 100, 1}, "Expel Harm HP Threshold", "Set the HP threshold for when to suggest Expel Harm.")
CreateARPanelOptions(CP_Brewmaster, "APL.Monk.Brewmaster")

-- Mistweaver
CreateARPanelOptions(CP_Mistweaver, "APL.Monk.Mistweaver")
CreatePanelOption("CheckButton", CP_Mistweaver, "APL.Monk.Mistweaver.RequireExpelHarmBuffs", 
  "Require Expel Harm Buffs", "If enabled, only suggest Expel Harm when Enveloping Mist, Renewing Mist and Chi Harmony buffs are active.")
CreatePanelOption("CheckButton", CP_Mistweaver, "APL.Monk.Mistweaver.ThunderFocusTeaWithExpelHarm",
  "Thunder Focus Tea with Expel Harm", "If enabled, try to sync Thunder Focus Tea with Expel Harm for increased damage.")

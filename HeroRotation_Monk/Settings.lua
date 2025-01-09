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

--- ============================ CONTENT ===========================
HR.GUISettings.APL.Monk = {
  Commons = {
    Enabled = {
      Trinkets = true,
      Items = true,
    },
  },
  CommonsDS = {
    DisplayStyle = {
      Interrupts = "Cooldown",
      Items = "Suggested",
      Trinkets = "Suggested",
    },
  },
  CommonsOGCD = {
    GCDasOffGCD = {
      Paralysis = false,
      RingOfPeace = false,
      SummonWhiteTigerStatue = false,
    },
    OffGCDasOffGCD = {
      Racials = false,
      SpearHandStrike = true,
    }
  },
  Brewmaster = {
    ExpelHarmHP = 70,
    DisplayStyle = {
      CelestialBrew = "Suggested",
      DampenHarm = "Suggested",
      FortifyingBrew = "Suggested",
      Purify = "SuggestedRight"
    },
    GCDasOffGCD = {
      BreathOfFire = false,
      ExpelHarm = false,
      ExplodingKeg = false,
      InvokeNiuzaoTheBlackOx = true,
      TouchOfDeath = true,
    },
    OffGCDasOffGCD = {
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
    GCDasOffGCD = {
      CracklingJadeLightning = false,
      FortifyingBrew = true,
      InvokeXuenTheWhiteTiger = true,
      StormEarthAndFireFixate = false,
      TouchOfDeath = true,
      TouchOfKarma = true,
    },
    OffGCDasOffGCD = {
      EnergizingElixir = true,
      Serenity = true,
      StormEarthAndFire = true,
    }
  },
  Mistweaver = {
    DisplayStyle = {
      -- Main icon - DPS abilities
      RisingSunKick = "Suggested",
      BlackoutKick = "Suggested",
      TigerPalm = "Suggested",
      SpinningCraneKick = "Suggested",
      
      -- Left icon - Instant heals
      ExpelHarm = "SuggestedRight",
      RenewingMist = "SuggestedRight",
      InstantEnvelopingMist = "SuggestedRight",
      InstantVivify = "SuggestedRight",
      
      -- Cooldowns
      ThunderFocusTea = "Cooldown",
      InvokeChiJi = "Cooldown",
      Revival = "Cooldown",
      LifeCocoon = "Cooldown",
      CelestialConduit = "Cooldown",
    },
  },
}

HR.GUI.LoadSettingsRecursively(HR.GUISettings)

-- Create panels
local ARPanel = HR.GUI.Panel
local CP_Monk = CreateChildPanel(ARPanel, "Monk")
local CP_MonkDS = CreateChildPanel(CP_Monk, "Class DisplayStyles")
local CP_Windwalker = CreateChildPanel(CP_Monk, "Windwalker")
local CP_Brewmaster = CreateChildPanel(CP_Monk, "Brewmaster")

-- Create panel options
CreateARPanelOptions(CP_Monk, "APL.Monk.Commons")
CreateARPanelOptions(CP_MonkDS, "APL.Monk.CommonsDS")
CreateARPanelOptions(CP_Windwalker, "APL.Monk.Windwalker")
CreateARPanelOptions(CP_Brewmaster, "APL.Monk.Brewmaster")

-- Windwalker specific options
CreatePanelOption("CheckButton", CP_Windwalker, "APL.Monk.Windwalker.ShowFortifyingBrewCD", "Fortifying Brew", "Enable or disable Fortifying Brew recommendations.")
CreatePanelOption("CheckButton", CP_Windwalker, "APL.Monk.Windwalker.IgnoreToK", "Ignore Touch of Karma", "Enable this setting to allow you to ignore Touch of Karma without stalling the rotation.")
CreatePanelOption("CheckButton", CP_Windwalker, "APL.Monk.Windwalker.IgnoreFSK", "Ignore Flying Serpent Kick", "Enable this setting to allow you to ignore Flying Serpent Kick without stalling the rotation.")
CreatePanelOption("Slider", CP_Windwalker, "APL.Monk.Windwalker.FortifyingBrewHP", {1, 100, 1}, "Fortifying Brew HP Threshold", "Set the HP threshold for when to suggest Fortifying Brew.")
CreatePanelOption("Slider", CP_Windwalker, "APL.Monk.Windwalker.MotCCountThreshold", {1, 10, 1}, "Mark of the Crane Count Threshold", "Allow the profile to cycle through targets to apply Mark of the Crane.")
CreatePanelOption("Slider", CP_Windwalker, "APL.Monk.Windwalker.MotCMinTimeThreshold", {1, 20, 1}, "Mark of the Crane Min Time Threshold", "Allow the profile to cycle through targets to apply Mark of the Crane.")

-- Brewmaster specific options
CreatePanelOption("Slider", CP_Brewmaster, "APL.Monk.Brewmaster.ExpelHarmHP", {1, 100, 1}, "Expel Harm HP Threshold", "Set the HP threshold for when to suggest Expel Harm.")

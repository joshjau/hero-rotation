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
    },
    DisplayStyle = {
      Potions = "Suggested",
      Covenant = "Suggested",
      Trinkets = "Suggested"
    },
    -- {Display GCD as OffGCD, ForceReturn}
    GCDasOffGCD = {
      -- Abilities
      LegSweep = true,
      RingOfPeace = true,
      Paralysis = true,
    },
    -- {Display OffGCD as OffGCD, ForceReturn}
    OffGCDasOffGCD = {
      -- Racials
      Racials = true,
      -- Abilities
      Interrupts = true,
    }
  },
  Brewmaster = {
    -- Do not pool, this option only exists because people keep nagging me about it
    NoBrewmasterPooling = false,
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
      InvokeNiuzaoTheBlackOx = true,
      TouchOfDeath           = true,
    },
    -- {Display OffGCD as OffGCD, ForceReturn}
    OffGCDasOffGCD = {
      -- Racials
      -- Abilities
      BlackOxBrew            = true,
      PurifyingBrew          = true,
    }
  },
  Windwalker = {
  -- Do not pool, this option only exists because people keep nagging me about it
    ShowFortifyingBrewCD = false,
    NoWindwalkerPooling = false,
    IgnoreToK = false,
    IgnoreFSK = true,
    -- {Display GCD as OffGCD, ForceReturn}
    GCDasOffGCD = {
      -- Abilities
      InvokeXuenTheWhiteTiger = true,
      TouchOfDeath            = true,
      TouchOfKarma            = true,
      FortifyingBrew          = true,
    },
    -- {Display OffGCD as OffGCD, ForceReturn}
    OffGCDasOffGCD = {
      -- Racials
      -- Abilities
      EnergizingElixir        = true,
      Serenity                = true,
      StormEarthAndFire       = true,
    }
  },
  Mistweaver = {
  -- Do not pool, this option only exists because people keep nagging me about it
    ShowFortifyingBrewCD = false,
    NoMistweaverPooling = false,
    -- {Display GCD as OffGCD, ForceReturn}
    GCDasOffGCD = {
      -- Abilities
      InvokeYulonTheJadeSerpent = true,
      InvokeChiJiTheRedCrane    = true,
      SummonJadeSerpentStatue   = true,
      RenewingMist              = true,
      TouchOfDeath              = true,
      FortifyingBrew            = true,
    },
    -- {Display OffGCD as OffGCD, ForceReturn}
    OffGCDasOffGCD = {
      -- Racials
      -- Abilities
      ThunderFocusTea         = true,
    }
  }
};
HR.GUI.LoadSettingsRecursively(HR.GUISettings)

-- Child Panels
local ARPanel = HR.GUI.Panel
local CP_Monk = CreateChildPanel(ARPanel, "Monk")
local CP_Windwalker = CreateChildPanel(CP_Monk, "Windwalker")
local CP_Brewmaster = CreateChildPanel(CP_Monk, "Brewmaster")
local CP_Mistweaver = CreateChildPanel(CP_Monk, "Mistweaver")
-- Monk
CreateARPanelOptions(CP_Monk, "APL.Monk.Commons")

-- Windwalker
CreateARPanelOptions(CP_Windwalker, "APL.Monk.Windwalker")
CreatePanelOption("CheckButton", CP_Windwalker, "APL.Monk.Windwalker.ShowFortifyingBrewCD", "Fortifying Brew", "Enable or disable Fortifying Brew recommendations.")
CreatePanelOption("CheckButton", CP_Windwalker, "APL.Monk.Windwalker.IgnoreToK", "Ignore Touch of Karma", "Enable this setting to allow you to ignore Touch of Karma without stalling the rotation. (NOTE: Touch of Karma will never be suggested if this is enabled)")
CreatePanelOption("CheckButton", CP_Windwalker, "APL.Monk.Windwalker.IgnoreFSK", "Ignore Flying Serpent Kick", "Enable this setting to allow you to ignore Flying Serpent Kick without stalling the rotation. (NOTE: Flying Serpent Kick will never be suggested if this is enabled)")
CreatePanelOption("CheckButton", CP_Windwalker, "APL.Monk.Windwalker.NoWindwalkerPooling", "No Pooling", "If you want to ignore energy pooling.")

-- Brewmaster
CreateARPanelOptions(CP_Brewmaster, "APL.Monk.Brewmaster")
CreatePanelOption("CheckButton", CP_Brewmaster, "APL.Monk.Brewmaster.NoBrewmasterPooling", "No Pooling", "If you want to ignore energy pooling.")

-- Mistweaver
CreateARPanelOptions(CP_Mistweaver, "APL.Monk.Mistweaver")

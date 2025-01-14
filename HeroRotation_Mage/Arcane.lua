--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroDBC
local DBC           = HeroDBC.DBC
-- HeroLib
local HL            = HeroLib
local Unit          = HL.Unit
local Player        = Unit.Player
local Target        = Unit.Target
local Spell         = HL.Spell
local Item          = HL.Item
-- HeroRotation
local HR            = HeroRotation
local Mage          = HR.Commons.Mage
local Cast          = HR.Cast
local CastAnnotated = HR.CastAnnotated
local CastLeft      = HR.CastLeft
local CDsON         = HR.CDsON
local AoEON         = HR.AoEON
-- Num/Bool Helper Functions
local num           = HR.Commons.Everyone.num
local bool          = HR.Commons.Everyone.bool
-- lua
local mathmax       = math.max
-- WoW API
local Delay         = C_Timer.After
local GetItemCount  = GetItemCount

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Define S/I for spell and item arrays
local S = Spell.Mage.Arcane;
local I = Item.Mage.Arcane;

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  -- TWW Trinkets
  I.AberrantSpellforge:ID(),
  I.FearbreakersEcho:ID(),
  I.HighSpeakersAccretion:ID(),
  I.ImperfectAscendancySerum:ID(),
  I.MadQueensMandate:ID(),
  I.MereldarsToll:ID(),
  I.SpymastersWeb:ID(),
  I.TreacherousTransmitter:ID(),
}

--- ===== GUI Settings =====
local Everyone = HR.Commons.Everyone;
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Mage.Commons,
  CommonsDS = HR.GUISettings.APL.Mage.CommonsDS,
  CommonsOGCD = HR.GUISettings.APL.Mage.CommonsOGCD,
  Arcane = HR.GUISettings.APL.Mage.Arcane
};

--- ===== InFlight Registrations =====
S.ArcaneBlast:RegisterInFlight()
S.ArcaneBarrage:RegisterInFlight()

--- ===== Rotation Variables =====
local VarAoETargetCount = (not S.ArcingCleave:IsAvailable()) and 9 or 2
local VarOpener = true
local VarAoEList = false
local Enemies8ySplash, EnemiesCount8ySplash
local ClearCastingMaxStack = S.ImprovedClearcasting:IsAvailable() and 3 or 1
local BossFightRemains = 11111
local FightRemains = 11111
local CastAE

--- ===== Trinket Variables =====
local VarTreacherousTransmitterPrecombatCast = 11
local VarSteroidTrinketEquipped = Player:GladiatorsBadgeIsEquipped() or I.SignetofthePriory:IsEquipped() or I.HighSpeakersAccretion:IsEquipped() or I.SpymastersWeb:IsEquipped() or I.TreacherousTransmitter:IsEquipped() or I.ImperfectAscendancySerum:IsEquipped() or I.QuickwickCandlestick:IsEquipped()
local VarTransmitterDoubleOnUse = (Player:GladiatorsBadgeIsEquipped() or I.SignetofthePriory:IsEquipped() or I.HighSpeakersAccretion:IsEquipped() or I.SpymastersWeb:IsEquipped() or I.ImperfectAscendancySerum:IsEquipped() or I.QuickwickCandlestick:IsEquipped()) and I.TreacherousTransmitter:IsEquipped()

--- ===== Event Registrations =====
HL:RegisterForEvent(function()
  VarAoETargetCount = (not S.ArcingCleave:IsAvailable()) and 9 or 2
  VarOpener = true
  VarAoEList = false
  BossFightRemains = 11111
  FightRemains = 11111
end, "PLAYER_REGEN_ENABLED")

HL:RegisterForEvent(function()
  VarAoETargetCount = (not S.ArcingCleave:IsAvailable()) and 9 or 2
  ClearCastingMaxStack = S.ImprovedClearcasting:IsAvailable() and 3 or 1
end, "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB")

HL:RegisterForEvent(function()
  VarSteroidTrinketEquipped = Player:GladiatorsBadgeIsEquipped() or I.SignetofthePriory:IsEquipped() or I.HighSpeakersAccretion:IsEquipped() or I.SpymastersWeb:IsEquipped() or I.TreacherousTransmitter:IsEquipped() or I.ImperfectAscendancySerum:IsEquipped()
  VarTransmitterDoubleOnUse = (Player:GladiatorsBadgeIsEquipped() or I.SignetofthePriory:IsEquipped() or I.HighSpeakersAccretion:IsEquipped() or I.SpymastersWeb:IsEquipped() or I.ImperfectAscendancySerum:IsEquipped() or I.QuickwickCandlestick:IsEquipped()) and I.TreacherousTransmitter:IsEquipped()
end, "PLAYER_EQUIPMENT_CHANGED")

--- ===== Rotation Functions =====
local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- arcane_intellect
  -- Note: Moved to top of APL()
  -- variable,name=aoe_target_count,op=reset,default=2
  -- variable,name=aoe_target_count,op=set,value=9,if=!talent.arcing_cleave
  -- variable,name=opener,op=set,value=1
  -- variable,name=aoe_list,default=0,op=reset
  -- Note: Moved to variable declarations and Event Registrations to avoid potential nil errors.
  -- variable,name=steroid_trinket_equipped,op=set,value=equipped.gladiators_badge|equipped.signet_of_the_priory|equipped.high_speakers_accretion|equipped.spymasters_web|equipped.treacherous_transmitter|equipped.imperfect_ascendancy_serum|equipped.quickwick_candlestick
  -- variable,name=transmitter_double_on_use,op=set,value=(equipped.gladiators_badge|equipped.signet_of_the_priory|equipped.high_speakers_accretion|equipped.spymasters_web|equipped.imperfect_ascendancy_serum|equipped.quickwick_candlestick)&equipped.treacherous_transmitter
  -- Note: Moved to SetTrinketVariables().
  -- snapshot_stats
  -- variable,name=treacherous_transmitter_precombat_cast,value=11
  -- use_item,name=treacherous_transmitter
  if I.TreacherousTransmitter:IsEquippedAndReady() then
    if Cast(I.TreacherousTransmitter, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "treacherous_transmitter precombat 2"; end
  end
  -- mirror_image
  if S.MirrorImage:IsCastable() and CDsON() and Settings.Arcane.MirrorImagesBeforePull then
    if Cast(S.MirrorImage, Settings.Arcane.GCDasOffGCD.MirrorImage) then return "mirror_image precombat 4"; end
  end
  -- use_item,name=imperfect_ascendancy_serum
  if I.ImperfectAscendancySerum:IsEquippedAndReady() then
    if Cast(I.ImperfectAscendancySerum, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "imperfect_ascendancy_serum precombat 6"; end
  end
  -- arcane_blast,if=!talent.evocation
  if S.ArcaneBlast:IsReady() and (not S.Evocation:IsAvailable()) then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast precombat 8"; end
  end
  -- evocation,if=talent.evocation
  if S.Evocation:IsReady() then
    if Cast(S.Evocation, Settings.Arcane.GCDasOffGCD.Evocation) then return "evocation precombat 10"; end
  end
end

local function CDOpener()
  -- touch_of_the_magi,use_off_gcd=1,if=prev_gcd.1.arcane_barrage&(action.arcane_barrage.in_flight_remains<=0.5|gcd.remains<=0.5)&(buff.arcane_surge.up|cooldown.arcane_surge.remains>30)|(prev_gcd.1.arcane_surge&buff.arcane_charge.stack<4)
  -- Note: Added an extra half second buffer time.
  if S.TouchoftheMagi:IsReady() and (Player:PrevGCDP(1, S.ArcaneBarrage) and (S.ArcaneBarrage:TravelTime() - S.ArcaneBarrage:TimeSinceLastCast() <= 1 or Player:GCDRemains() <= 1) and (Player:BuffUp(S.ArcaneSurgeBuff) or S.ArcaneSurge:CooldownRemains() > 30) or (Player:PrevGCDP(1, S.ArcaneSurge) and Player:ArcaneCharges() < 4)) then
    if Cast(S.TouchoftheMagi, Settings.Arcane.GCDasOffGCD.TouchOfTheMagi, nil, not Target:IsSpellInRange(S.TouchoftheMagi)) then return "touch_of_the_magi cd_opener 2"; end
  end
  -- wait,sec=0.05,if=prev_gcd.1.arcane_surge&time-action.touch_of_the_magi.last_used<0.015,line_cd=15
  -- arcane_blast,if=buff.presence_of_mind.up
  if S.ArcaneBlast:IsReady() and (Player:BuffUp(S.PresenceofMindBuff)) then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast cd_opener 4"; end
  end
  -- arcane_orb,if=talent.high_voltage&variable.opener,line_cd=10
  if S.ArcaneOrb:IsReady() and S.ArcaneOrb:TimeSinceLastCast() >= 10 and (S.HighVoltage:IsAvailable() and VarOpener) then
    if Cast(S.ArcaneOrb, nil, nil, not Target:IsInRange(40)) then return "arcane_orb cd_opener 6"; end
  end
  -- arcane_barrage,if=buff.arcane_tempo.up&cooldown.evocation.ready&buff.arcane_tempo.remains<gcd.max*5,line_cd=11
  if S.ArcaneBarrage:IsReady() and S.ArcaneBarrage:TimeSinceLastCast() >= 11 and (Player:BuffUp(S.ArcaneTempoBuff) and S.Evocation:CooldownUp() and Player:BuffRemains(S.ArcaneTempoBuff) < Player:GCD() * 5) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsInRange(8)) then return "arcane_barrage cd_opener 7"; end
  end
  -- evocation,if=cooldown.arcane_surge.remains<(gcd.max*3)&cooldown.touch_of_the_magi.remains<(gcd.max*5)
  if S.Evocation:IsCastable() and (S.ArcaneSurge:CooldownRemains() < (Player:GCD() * 3) and S.TouchoftheMagi:CooldownRemains() < (Player:GCD() * 5)) then
    if Cast(S.Evocation, Settings.Arcane.GCDasOffGCD.Evocation) then return "evocation cd_opener 8"; end
  end
  -- arcane_missiles,if=((prev_gcd.1.evocation|prev_gcd.1.arcane_surge)|variable.opener)&buff.nether_precision.down&buff.aether_attunement.down,interrupt_if=tick_time>gcd.remains&buff.aether_attunement.down,interrupt_immediate=1,interrupt_global=1,chain=1,line_cd=30
  if Settings.Arcane.Enabled.ArcaneMissilesInterrupts and Player:IsChanneling(S.ArcaneMissiles) and (S.ArcaneMissiles:TickTime() > Player:GCDRemains() and Player:BuffDown(S.AetherAttunementBuff)) then
    if CastAnnotated(S.StopAM, false, "STOP AM") then return "arcane_missiles interrupt cd_opener 10"; end
  end
  if S.ArcaneMissiles:IsReady() and S.ArcaneMissiles:TimeSinceLastCast() >= 30 and (((Player:PrevGCDP(1, S.Evocation) or Player:PrevGCDP(1, S.ArcaneSurge)) or VarOpener) and Player:BuffDown(S.NetherPrecisionBuff) and Player:BuffDown(S.AetherAttunementBuff)) then
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles cd_opener 12"; end
  end
  -- arcane_surge,if=cooldown.touch_of_the_magi.remains<(action.arcane_surge.execute_time+(gcd.max*(buff.arcane_charge.stack=4)))
  if S.ArcaneSurge:IsCastable() and (S.TouchoftheMagi:CooldownRemains() < (S.ArcaneSurge:ExecuteTime() + (Player:GCD() * num(Player:ArcaneCharges() == 4)))) then
    if Cast(S.ArcaneSurge, Settings.Arcane.GCDasOffGCD.ArcaneSurge) then return "arcane_surge cd_opener 14"; end
  end
end

local function Spellslinger()
  -- shifting_power,if=(((((action.arcane_orb.charges=talent.charged_orb)&cooldown.arcane_orb.remains)|cooldown.touch_of_the_magi.remains<23)&buff.arcane_surge.down&buff.siphon_storm.down&debuff.touch_of_the_magi.down&cooldown.touch_of_the_magi.remains>(12+6*gcd.max))|(prev_gcd.1.arcane_barrage&talent.shifting_shards&(buff.arcane_surge.up|debuff.touch_of_the_magi.up|cooldown.evocation.remains<20)))&fight_remains>10&(buff.arcane_tempo.remains>gcd.max*2.5|buff.arcane_tempo.down)
  if S.ShiftingPower:IsReady() and ((((((S.ArcaneOrb:Charges() == num(S.ChargedOrb:IsAvailable())) and S.ArcaneOrb:CooldownDown()) or S.TouchoftheMagi:CooldownRemains() < 23) and Player:BuffDown(S.ArcaneSurgeBuff) and Player:BuffDown(S.SiphonStormBuff) and Target:DebuffDown(S.TouchoftheMagiDebuff) and S.TouchoftheMagi:CooldownRemains() > (12 + 6 * Player:GCD())) or (Player:PrevGCDP(1, S.ArcaneBarrage) and S.ShiftingShards:IsAvailable() and (Player:BuffUp(S.ArcaneSurgeBuff) or Target:DebuffUp(S.TouchoftheMagiDebuff) or S.Evocation:CooldownRemains() < 20))) and FightRemains > 10 and (Player:BuffRemains(S.ArcaneTempoBuff) > Player:GCD() * 2.5 or Player:BuffDown(S.ArcaneTempoBuff))) then
    if Cast(S.ShiftingPower, nil, Settings.CommonsDS.DisplayStyle.ShiftingPower, not Target:IsInRange(18)) then return "shifting_power spellslinger 2"; end
  end
  -- cancel_buff,name=presence_of_mind,use_off_gcd=1,if=prev_gcd.1.arcane_blast&buff.presence_of_mind.stack=1
  -- TODO: Handle cancel_buff.
  -- presence_of_mind,if=debuff.touch_of_the_magi.remains<=gcd.max&buff.nether_precision.up&active_enemies<variable.aoe_target_count&!talent.unerring_proficiency
  if S.PresenceofMind:IsCastable() and (Target:DebuffRemains(S.TouchoftheMagiDebuff) <= Player:GCD() and Player:BuffUp(S.NetherPrecisionBuff) and EnemiesCount8ySplash < VarAoETargetCount and not S.UnerringProficiency:IsAvailable()) then
    if Cast(S.PresenceofMind, Settings.Arcane.OffGCDasOffGCD.PresenceOfMind) then return "presence_of_mind spellslinger 4"; end
  end
  -- wait,sec=0.05,if=time-action.presence_of_mind.last_used<0.015,line_cd=15
  -- supernova,if=debuff.touch_of_the_magi.remains<=gcd.max&buff.unerring_proficiency.stack=30
  if S.Supernova:IsCastable() and (Target:DebuffRemains(S.TouchoftheMagiDebuff) <= Player:GCD() and Player:BuffStack(S.UnerringProficiencyBuff) == 30) then
    if Cast(S.Supernova, nil, nil, not Target:IsSpellInRange(S.Supernova)) then return "supernova spellslinger 6"; end
  end
  -- arcane_blast,if=((debuff.magis_spark_arcane_blast.up|(buff.leydrinker.up&buff.arcane_charge.stack=4))&!prev_gcd.1.arcane_blast&buff.nether_precision.up)
  if S.ArcaneBlast:IsReady() and ((Target:DebuffUp(S.MagisSparkABDebuff) or (Player:BuffUp(S.LeydrinkerBuff) and Player:ArcaneCharges() == 4)) and not Player:PrevGCDP(1, S.ArcaneBlast) and Player:BuffUp(S.NetherPrecisionBuff)) then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast spellslinger 8"; end
  end
  -- arcane_barrage,if=(cooldown.touch_of_the_magi.ready)|(buff.arcane_tempo.up&buff.arcane_tempo.remains<gcd.max)|((buff.aethervision.stack=2|buff.intuition.react)&(buff.nether_precision.up|buff.clearcasting.react=0))|((cooldown.arcane_orb.remains<gcd.max)&buff.arcane_charge.stack=4&buff.clearcasting.stack=0&buff.nether_precision.down&talent.orb_barrage&cooldown.touch_of_the_magi.remains>gcd.max*6)
  if S.ArcaneBarrage:IsCastable() and ((S.TouchoftheMagi:CooldownUp() and CDsON() and not Settings.Arcane.AllowHoldingTotM) or (Player:BuffUp(S.ArcaneTempoBuff) and Player:BuffRemains(S.ArcaneTempoBuff) < Player:GCD()) or ((Player:BuffStack(S.AethervisionBuff) == 2 or Player:BuffUp(S.IntuitionBuff)) and (Player:BuffUp(S.NetherPrecisionBuff) or Player:BuffDown(S.ClearcastingBuff))) or ((S.ArcaneOrb:CooldownRemains() < Player:GCD()) and Player:ArcaneCharges() == 4 and Player:BuffDown(S.ClearcastingBuff) and Player:BuffDown(S.NetherPrecisionBuff) and S.OrbBarrage:IsAvailable() and S.TouchoftheMagi:CooldownRemains() > Player:GCD() * 6)) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage spellslinger 10"; end
  end
  -- arcane_barrage,if=((buff.arcane_charge.stack=4&buff.nether_precision.up&active_enemies>1&(cooldown.arcane_orb.remains<gcd.max|action.arcane_orb.charges>0)&cooldown.touch_of_the_magi.remains>gcd.max*6)|(buff.arcane_charge.stack=4&talent.reverberate&active_enemies>2)|(buff.aether_attunement.up&talent.high_voltage&buff.clearcasting.react&buff.arcane_charge.stack>1&((target.health.pct<35&active_enemies=2)|active_enemies>2)))&talent.arcing_cleave
  if S.ArcaneBarrage:IsCastable() and (((Player:ArcaneCharges() == 4 and Player:BuffUp(S.NetherPrecisionBuff) and EnemiesCount8ySplash > 1 and (S.ArcaneOrb:CooldownRemains() < Player:GCD() or S.ArcaneOrb:Charges() > 0) and S.TouchoftheMagi:CooldownRemains() > Player:GCD() * 6) or (Player:ArcaneCharges() == 4 and S.Reverberate:IsAvailable() and EnemiesCount8ySplash > 2) or (Player:BuffUp(S.AetherAttunementBuff) and S.HighVoltage:IsAvailable() and Player:BuffUp(S.ClearcastingBuff) and Player:ArcaneCharges() > 1 and ((Target:HealthPercentage() < 35 and EnemiesCount8ySplash == 2) or EnemiesCount8ySplash > 2))) and S.ArcingCleave:IsAvailable()) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage spellslinger 12"; end
  end
  -- arcane_missiles,if=buff.clearcasting.react&buff.nether_precision.down&((cooldown.touch_of_the_magi.remains>gcd.max*7&cooldown.arcane_surge.remains>gcd.max*7)|buff.clearcasting.react>1|(cooldown.touch_of_the_magi.remains<gcd.max*4&buff.aether_attunement.down))|fight_remains<5,interrupt_if=tick_time>gcd.remains&buff.aether_attunement.down,interrupt_immediate=1,interrupt_global=1,chain=1
  if Settings.Arcane.Enabled.ArcaneMissilesInterrupts and Player:IsChanneling(S.ArcaneMissiles) and (S.ArcaneMissiles:TickTime() > Player:GCDRemains() and Player:BuffDown(S.AetherAttunementBuff)) then
    if CastAnnotated(S.StopAM, false, "STOP AM") then return "arcane_missiles interrupt spellslinger 14"; end
  end
  if S.ArcaneMissiles:IsReady() and (Player:BuffUp(S.ClearcastingBuff) and Player:BuffDown(S.NetherPrecisionBuff) and ((S.TouchoftheMagi:CooldownRemains() > Player:GCD() * 7 and S.ArcaneSurge:CooldownRemains() > Player:GCD() * 7) or Player:BuffStack(S.ClearcastingBuff) > 1 or (S.TouchoftheMagi:CooldownRemains() < Player:GCD() * 4 and Player:BuffDown(S.AetherAttunementBuff))) or BossFightRemains < 5) then
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles spellslinger 16"; end
  end
  -- arcane_orb,if=buff.arcane_charge.stack<((5-active_enemies)<?1)
  if S.ArcaneOrb:IsReady() and (Player:ArcaneCharges() < mathmax(1, 5 - EnemiesCount8ySplash)) then
    if Cast(S.ArcaneOrb, nil, nil, not Target:IsInRange(40)) then return "arcane_orb spellslinger 18"; end
  end
  -- arcane_explosion,if=(talent.reverberate|buff.arcane_charge.stack<1)&active_enemies>=4
  if S.ArcaneExplosion:IsReady() and ((S.Reverberate:IsAvailable() or Player:ArcaneCharges() < 1) and EnemiesCount8ySplash >= 4) then
    if CastAE(S.ArcaneExplosion) then return "arcane_explosion spellslinger 20"; end
  end
  -- arcane_barrage,if=buff.arcane_charge.stack=4&target.health.pct<35&buff.nether_precision.down&talent.orb_barrage&talent.arcane_bombardment&talent.arcing_cleave&active_enemies>2
  if S.ArcaneBarrage:IsReady() and (Player:ArcaneCharges() == 4 and Target:HealthPercentage() < 35 and Player:BuffDown(S.NetherPrecisionBuff) and S.OrbBarrage:IsAvailable() and S.ArcaneBombardment:IsAvailable() and S.ArcingCleave:IsAvailable() and EnemiesCount8ySplash > 2) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage spellslinger 22"; end
  end
  -- arcane_blast
  if S.ArcaneBlast:IsReady() then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast spellslinger 24"; end
  end
  -- arcane_barrage
  if S.ArcaneBarrage:IsCastable() then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage spellslinger 26"; end
  end
end

local function SpellslingerAoE()
  -- supernova,if=buff.unerring_proficiency.stack=30
  if S.Supernova:IsCastable() and (Player:BuffStack(S.UnerringProficiencyBuff) == 30) then
    if Cast(S.Supernova, nil, nil, not Target:IsSpellInRange(S.Supernova)) then return "supernova spellslinger_aoe 2"; end
  end
  -- shifting_power,if=((buff.arcane_surge.down&buff.siphon_storm.down&debuff.touch_of_the_magi.down&cooldown.evocation.remains>15&cooldown.touch_of_the_magi.remains>10)&(cooldown.arcane_orb.remains&action.arcane_orb.charges=0)&fight_remains>10)|(prev_gcd.1.arcane_barrage&(buff.arcane_surge.up|debuff.touch_of_the_magi.up|cooldown.evocation.remains<20)&talent.shifting_shards)
  if S.ShiftingPower:IsReady() and (((Player:BuffDown(S.ArcaneSurgeBuff) and Player:BuffDown(S.SiphonStormBuff) and Target:DebuffDown(S.TouchoftheMagiDebuff) and S.Evocation:CooldownRemains() > 15 and S.TouchoftheMagi:CooldownRemains() > 10) and (S.ArcaneOrb:CooldownDown() and S.ArcaneOrb:Charges() == 0) and FightRemains > 10) or (Player:PrevGCDP(1, S.ArcaneBarrage) and (Player:BuffUp(S.ArcaneSurgeBuff) or Target:DebuffUp(S.TouchoftheMagiDebuff) or S.Evocation:CooldownRemains() < 20) and S.ShiftingShards:IsAvailable())) then
    if Cast(S.ShiftingPower, nil, Settings.CommonsDS.DisplayStyle.ShiftingPower, not Target:IsInRange(18)) then return "shifting_power spellslinger_aoe 4"; end
  end
  -- arcane_orb,if=buff.arcane_charge.stack<3
  if S.ArcaneOrb:IsReady() and (Player:ArcaneCharges() < 3) then
    if Cast(S.ArcaneOrb, nil, nil, not Target:IsInRange(40)) then return "arcane_orb spellslinger_aoe 6"; end
  end
  -- arcane_blast,if=((debuff.magis_spark_arcane_blast.up|buff.leydrinker.up)&!prev_gcd.1.arcane_blast)
  if S.ArcaneBlast:IsReady() and ((Target:DebuffUp(S.MagisSparkABDebuff) or Player:BuffUp(S.LeydrinkerBuff)) and Player:PrevGCDP(1, S.ArcaneBlast)) then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast spellslinger_aoe 8"; end
  end
  -- arcane_barrage,if=buff.aether_attunement.up&talent.high_voltage&buff.clearcasting.react&buff.arcane_charge.stack>1
  if S.ArcaneBarrage:IsCastable() and (Player:BuffUp(S.AetherAttunementBuff) and S.HighVoltage:IsAvailable() and Player:BuffUp(S.ClearcastingBuff) and Player:ArcaneCharges() > 1) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage spellslinger_aoe 10"; end
  end
  -- arcane_missiles,if=buff.clearcasting.react&((talent.high_voltage&buff.arcane_charge.stack<4)|buff.nether_precision.down),interrupt_if=tick_time>gcd.remains&buff.aether_attunement.down,interrupt_immediate=1,interrupt_global=1,chain=1
  if Settings.Arcane.Enabled.ArcaneMissilesInterrupts and Player:IsChanneling(S.ArcaneMissiles) and (S.ArcaneMissiles:TickTime() > Player:GCDRemains() and Player:BuffDown(S.AetherAttunementBuff)) then
    if CastAnnotated(S.StopAM, false, "STOP AM") then return "arcane_missiles interrupt spellslinger_aoe 12"; end
  end
  if S.ArcaneMissiles:IsReady() and (Player:BuffUp(S.ClearcastingBuff) and ((S.HighVoltage:IsAvailable() and Player:ArcaneCharges() < 4) or Player:BuffDown(S.NetherPrecisionBuff))) then
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles spellslinger_aoe 14"; end
  end
  -- presence_of_mind,if=buff.arcane_charge.stack=3|buff.arcane_charge.stack=2
  if S.PresenceofMind:IsCastable() and (Player:ArcaneCharges() == 3 or Player:ArcaneCharges() == 2) then
    if Cast(S.PresenceofMind, Settings.Arcane.OffGCDasOffGCD.PresenceOfMind) then return "presence_of_mind spellslinger_aoe 16"; end
  end
  -- arcane_barrage,if=buff.arcane_charge.stack=4
  if S.ArcaneBarrage:IsCastable() and (Player:ArcaneCharges() == 4) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage spellslinger_aoe 18"; end
  end
  -- arcane_explosion,if=(talent.reverberate|buff.arcane_charge.stack<1)
  if S.ArcaneExplosion:IsReady() and (S.Reverberate:IsAvailable() or Player:ArcaneCharges() < 1) then
    if CastAE(S.ArcaneExplosion) then return "arcane_explosion spellslinger_aoe 20"; end
  end
  -- arcane_blast
  if S.ArcaneBlast:IsReady() then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast spellslinger_aoe 22"; end
  end
  -- arcane_barrage
  if S.ArcaneBarrage:IsCastable() then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage spellslinger_aoe 24"; end
  end
end

local function Sunfury()
  -- shifting_power,if=((buff.arcane_surge.down&buff.siphon_storm.down&debuff.touch_of_the_magi.down&cooldown.evocation.remains>15&cooldown.touch_of_the_magi.remains>10)&fight_remains>10)&buff.arcane_soul.down
  if S.ShiftingPower:IsReady() and (((Player:BuffDown(S.ArcaneSurgeBuff) and Player:BuffDown(S.SiphonStormBuff) and Target:DebuffDown(S.TouchoftheMagiDebuff) and S.Evocation:CooldownRemains() > 15 and S.TouchoftheMagi:CooldownRemains() > 10) and FightRemains > 10) and Player:BuffDown(S.ArcaneSoulBuff)) then
    if Cast(S.ShiftingPower, nil, Settings.CommonsDS.DisplayStyle.ShiftingPower, not Target:IsInRange(18)) then return "shifting_power sunfury 2"; end
  end
  -- cancel_buff,name=presence_of_mind,use_off_gcd=1,if=(prev_gcd.1.arcane_blast&buff.presence_of_mind.stack=1)|active_enemies<4
  -- TODO: Implement cancel_buff.
  -- presence_of_mind,if=debuff.touch_of_the_magi.remains<=gcd.max&buff.nether_precision.up&active_enemies<4
  if S.PresenceofMind:IsCastable() and (Target:DebuffRemains(S.TouchoftheMagiDebuff) <= Player:GCD() and Player:BuffUp(S.NetherPrecisionBuff) and EnemiesCount8ySplash < 4) then
    if Cast(S.PresenceofMind, Settings.Arcane.OffGCDasOffGCD.PresenceOfMind) then return "presence_of_mind sunfury 4"; end
  end
  -- wait,sec=0.05,if=time-action.presence_of_mind.last_used<0.015,line_cd=15
  -- arcane_barrage,if=(buff.arcane_charge.stack=4&buff.burden_of_power.down&buff.nether_precision.up&active_enemies>2&((talent.arcane_bombardment&target.health.pct<35)|active_enemies>4)&talent.arcing_cleave&((talent.high_voltage&buff.clearcasting.react)|(cooldown.arcane_orb.remains<gcd.max|action.arcane_orb.charges>0)))|(buff.aether_attunement.up&talent.high_voltage&buff.clearcasting.react&buff.arcane_charge.stack>1&active_enemies>2&(target.health.pct<35|!talent.arcane_bombardment|active_enemies>4))|(active_enemies>2&(buff.aethervision.stack=2|buff.glorious_incandescence.up|buff.intuition.react)&(buff.nether_precision.up|(target.health.pct<35&talent.arcane_bombardment&buff.clearcasting.react=0)))
  if S.ArcaneBarrage:IsCastable() and ((Player:ArcaneCharges() == 4 and Player:BuffDown(S.BurdenofPowerBuff) and Player:BuffUp(S.NetherPrecisionBuff) and EnemiesCount8ySplash > 2 and ((S.ArcaneBombardment:IsAvailable() and Target:HealthPercentage() < 35) or EnemiesCount8ySplash > 4) and S.ArcingCleave:IsAvailable() and ((S.HighVoltage:IsAvailable() and Player:BuffUp(S.ClearcastingBuff)) or (S.ArcaneOrb:CooldownRemains() < Player:GCD() or S.ArcaneOrb:Charges() > 0))) or (Player:BuffUp(S.AetherAttunementBuff) and S.HighVoltage:IsAvailable() and Player:BuffUp(S.ClearcastingBuff) and Player:ArcaneCharges() > 1 and EnemiesCount8ySplash > 2 and (Target:HealthPercentage() < 35 or not S.ArcaneBombardment:IsAvailable() or EnemiesCount8ySplash > 4)) or (EnemiesCount8ySplash > 2 and (Player:BuffStack(S.AethervisionBuff) == 2 or Player:BuffUp(S.GloriousIncandescenceBuff) or Player:BuffUp(S.IntuitionBuff)) and (Player:BuffUp(S.NetherPrecisionBuff) or (Target:HealthPercentage() < 35 and S.ArcaneBombardment:IsAvailable() and Player:BuffDown(S.ClearcastingBuff))))) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage sunfury 6"; end
  end
  -- arcane_orb,if=buff.arcane_charge.stack<2&buff.arcane_soul.down&(!talent.high_voltage|buff.clearcasting.react=0)
  if S.ArcaneOrb:IsReady() and (Player:ArcaneCharges() < 2 and Player:BuffDown(S.ArcaneSoulBuff) and (not S.HighVoltage:IsAvailable() or Player:BuffDown(S.ClearcastingBuff))) then
    if Cast(S.ArcaneOrb, nil, nil, not Target:IsInRange(40)) then return "arcane_orb sunfury 8"; end
  end
  -- arcane_missiles,if=buff.nether_precision.down&buff.clearcasting.react&(buff.arcane_soul.up&buff.arcane_soul.remains>gcd.max*(4-buff.clearcasting.stack)),interrupt_if=tick_time>gcd.remains,interrupt_immediate=1,interrupt_global=1,chain=1
  if Settings.Arcane.Enabled.ArcaneMissilesInterrupts and Player:IsChanneling(S.ArcaneMissiles) and (S.ArcaneMissiles:TickTime() > Player:GCDRemains()) then
    if CastAnnotated(S.StopAM, false, "STOP AM") then return "arcane_missiles interrupt sunfury 10"; end
  end
  if S.ArcaneMissiles:IsReady() and (Player:BuffDown(S.NetherPrecisionBuff) and Player:BuffUp(S.ClearcastingBuff) and (Player:BuffUp(S.ArcaneSoulBuff) and Player:BuffRemains(S.ArcaneSoulBuff) > Player:GCD() * (4 - Player:BuffStack(S.ClearcastingBuff)))) then
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles sunfury 12"; end
  end
  -- arcane_barrage,if=(buff.intuition.react|buff.aethervision.stack=2|buff.glorious_incandescence.up)&((target.health.pct<35&talent.arcane_bombardment)|(mana.pct<70&talent.enlightened&buff.arcane_surge.down&active_enemies<3)|buff.glorious_incandescence.up)&(buff.nether_precision.up|buff.clearcasting.react=0)&cooldown.touch_of_the_magi.remains>6|(buff.arcane_soul.up&((buff.clearcasting.react<3)|buff.arcane_soul.remains<gcd.max))|(buff.arcane_charge.stack=4&cooldown.touch_of_the_magi.ready)
  if S.ArcaneBarrage:IsCastable() and ((Player:BuffUp(S.IntuitionBuff) or Player:BuffStack(S.AethervisionBuff) == 2 or Player:BuffUp(S.GloriousIncandescenceBuff)) and ((Target:HealthPercentage() < 35 and S.ArcaneBombardment:IsAvailable()) or (Player:ManaPercentage() < 70 and S.Enlightened:IsAvailable() and Player:BuffDown(S.ArcaneSurgeBuff) and EnemiesCount8ySplash < 3) or Player:BuffUp(S.GloriousIncandescenceBuff)) and (Player:BuffUp(S.NetherPrecisionBuff) or Player:BuffDown(S.ClearcastingBuff)) and S.TouchoftheMagi:CooldownRemains() > 6 or (Player:BuffUp(S.ArcaneSoulBuff) and ((Player:BuffStack(S.ClearcastingBuff) < 3) or Player:BuffRemains(S.ArcaneSoulBuff) < Player:GCD())) or (Player:ArcaneCharges() == 4 and S.TouchoftheMagi:CooldownUp())) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage sunfury 14"; end
  end
  -- arcane_missiles,if=buff.clearcasting.react&((buff.nether_precision.down|buff.clearcasting.react=3|(talent.high_voltage&buff.arcane_charge.stack<3))),interrupt_if=tick_time>gcd.remains&buff.aether_attunement.down,interrupt_immediate=1,interrupt_global=1,chain=1
  if Settings.Arcane.Enabled.ArcaneMissilesInterrupts and Player:IsChanneling(S.ArcaneMissiles) and (S.ArcaneMissiles:TickTime() > Player:GCDRemains() and Player:BuffDown(S.AetherAttunementBuff)) then
    if CastAnnotated(S.StopAM, false, "STOP AM") then return "arcane_missiles interrupt sunfury 16"; end
  end
  if S.ArcaneMissiles:IsReady() and (Player:BuffUp(S.ClearcastingBuff) and ((Player:BuffDown(S.NetherPrecisionBuff) or Player:BuffStack(S.ClearcastingBuff) == 3 or (S.HighVoltage:IsAvailable() and Player:ArcaneCharges() < 3)))) then
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles sunfury 18"; end
  end
  -- presence_of_mind,if=(buff.arcane_charge.stack=3|buff.arcane_charge.stack=2)&active_enemies>=3
  if S.PresenceofMind:IsCastable() and ((Player:ArcaneCharges() == 3 or Player:ArcaneCharges() == 2) and EnemiesCount8ySplash >= 3) then
    if Cast(S.PresenceofMind, Settings.Arcane.OffGCDasOffGCD.PresenceOfMind) then return "presence_of_mind sunfury 20"; end
  end
  -- arcane_explosion,if=(talent.reverberate|buff.arcane_charge.stack<1)&active_enemies>=4
  if S.ArcaneExplosion:IsReady() and ((S.Reverberate:IsAvailable() or Player:ArcaneCharges() < 1) and EnemiesCount8ySplash >= 4) then
    if CastAE(S.ArcaneExplosion) then return "arcane_explosion sunfury 22"; end
  end
  -- arcane_blast
  if S.ArcaneBlast:IsReady() then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast sunfury 24"; end
  end
  -- arcane_barrage
  if S.ArcaneBarrage:IsCastable() then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage sunfury 26"; end
  end
end

local function SunfuryAoE()
  -- arcane_barrage,if=(buff.arcane_soul.up&((buff.clearcasting.react<3)|buff.arcane_soul.remains<gcd.max))
  if S.ArcaneBarrage:IsCastable() and (Player:BuffUp(S.ArcaneSoulBuff) and ((Player:BuffStack(S.ClearcastingBuff) < 3) or Player:BuffRemains(S.ArcaneSoulBuff) < Player:GCD())) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage sunfury_aoe 2"; end
  end
  -- arcane_missiles,if=buff.arcane_soul.up,interrupt_if=tick_time>gcd.remains&buff.aether_attunement.down,interrupt_immediate=1,interrupt_global=1,chain=1
  if Settings.Arcane.Enabled.ArcaneMissilesInterrupts and Player:IsChanneling(S.ArcaneMissiles) and (S.ArcaneMissiles:TickTime() > Player:GCDRemains() and Player:BuffDown(S.AetherAttunementBuff)) then
    if CastAnnotated(S.StopAM, false, "STOP AM") then return "arcane_missiles interrupt sunfury_aoe 4"; end
  end
  if S.ArcaneMissiles:IsReady() and (Player:BuffUp(S.ArcaneSoulBuff)) then
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles sunfury_aoe 6"; end
  end
  -- shifting_power,if=(buff.arcane_surge.down&buff.siphon_storm.down&debuff.touch_of_the_magi.down&cooldown.evocation.remains>15&cooldown.touch_of_the_magi.remains>15)&(cooldown.arcane_orb.remains&action.arcane_orb.charges=0)&fight_remains>10
  if S.ShiftingPower:IsReady() and ((Player:BuffDown(S.ArcaneSurgeBuff) and Player:BuffDown(S.SiphonStormBuff) and Target:DebuffDown(S.TouchoftheMagiDebuff) and S.Evocation:CooldownRemains() > 15 and S.TouchoftheMagi:CooldownRemains() > 15) and (S.ArcaneOrb:CooldownDown() and S.ArcaneOrb:Charges() == 0) and FightRemains > 10) then
    if Cast(S.ShiftingPower, nil, Settings.CommonsDS.DisplayStyle.ShiftingPower, not Target:IsInRange(18)) then return "shifting_power sunfury_aoe 8"; end
  end
  -- arcane_orb,if=buff.arcane_charge.stack<2&(!talent.high_voltage|!buff.clearcasting.react)
  if S.ArcaneOrb:IsReady() and (Player:ArcaneCharges() < 2 and (not S.HighVoltage:IsAvailable() or Player:BuffDown(S.ClearcastingBuff))) then
    if Cast(S.ArcaneOrb, nil, nil, not Target:IsInRange(40)) then return "arcane_orb sunfury_aoe 10"; end
  end
  -- arcane_blast,if=((debuff.magis_spark_arcane_blast.up|buff.burden_of_power.up|buff.leydrinker.up)&!prev_gcd.1.arcane_blast)
  if S.ArcaneBlast:IsReady() and ((Target:DebuffUp(S.MagisSparkABDebuff) or Player:BuffUp(S.BurdenofPowerBuff) or Player:BuffUp(S.LeydrinkerBuff)) and Player:PrevGCDP(1, S.ArcaneBlast)) then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast sunfury_aoe 12"; end
  end
  -- arcane_barrage,if=(buff.arcane_charge.stack=4|buff.glorious_incandescence.up|buff.aethervision.stack=2|buff.intuition.react)&(buff.nether_precision.up|buff.clearcasting.react=0)
  if S.ArcaneBarrage:IsCastable() and ((Player:ArcaneCharges() == 4 or Player:BuffUp(S.GloriousIncandescenceBuff) or Player:BuffStack(S.AethervisionBuff) == 2 or Player:BuffUp(S.IntuitionBuff)) and (Player:BuffUp(S.NetherPrecisionBuff) or Player:BuffDown(S.ClearcastingBuff))) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage sunfury_aoe 14"; end
  end
  -- arcane_missiles,if=buff.clearcasting.react&(buff.aether_attunement.up|talent.arcane_harmony),interrupt_if=tick_time>gcd.remains&buff.aether_attunement.down,interrupt_immediate=1,interrupt_global=1,chain=1
  if Settings.Arcane.Enabled.ArcaneMissilesInterrupts and Player:IsChanneling(S.ArcaneMissiles) and (S.ArcaneMissiles:TickTime() > Player:GCDRemains() and Player:BuffDown(S.AetherAttunementBuff)) then
    if CastAnnotated(S.StopAM, false, "STOP AM") then return "arcane_missiles interrupt sunfury_aoe 16"; end
  end
  if S.ArcaneMissiles:IsReady() and (Player:BuffUp(S.ClearcastingBuff) and (Player:BuffUp(S.AetherAttunementBuff) or S.ArcaneHarmony:IsAvailable())) then
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles sunfury_aoe 18"; end
  end
  -- presence_of_mind,if=buff.arcane_charge.stack=3|buff.arcane_charge.stack=2
  if S.PresenceofMind:IsCastable() and (Player:ArcaneCharges() == 3 or Player:ArcaneCharges() == 2) then
    if Cast(S.PresenceofMind, Settings.Arcane.OffGCDasOffGCD.PresenceOfMind) then return "presence_of_mind sunfury_aoe 20"; end
  end
  -- arcane_explosion,if=talent.reverberate|buff.arcane_charge.stack<1
  if S.ArcaneExplosion:IsReady() and (S.Reverberate:IsAvailable() or Player:ArcaneCharges() < 1) then
    if CastAE(S.ArcaneExplosion) then return "arcane_explosion sunfury_aoe 22"; end
  end
  -- arcane_blast
  if S.ArcaneBlast:IsReady() then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast sunfury_aoe 24"; end
  end
  -- arcane_barrage
  if S.ArcaneBarrage:IsCastable() then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage sunfury_aoe 26"; end
  end
end

--- ===== APL Main =====
local function APL()
  Enemies8ySplash = Target:GetEnemiesInSplashRange(8)
  if AoEON() then
    EnemiesCount8ySplash = Target:GetEnemiesInSplashRangeCount(8)
  else
    EnemiesCount8ySplash = 1
  end

  if Everyone.TargetIsValid() or Player:AffectingCombat() then
    -- Calculate fight_remains
    BossFightRemains = HL.BossFightRemains()
    FightRemains = BossFightRemains
    if FightRemains == 11111 then
      FightRemains = HL.FightRemains(Enemies8ySplash, false)
    end

    -- Set which cast function to use for ArcaneExplosion
    CastAE = (Settings.Arcane.AEMainIcon) and Cast or CastLeft
  end

  if Everyone.TargetIsValid() then
    -- arcane_intellect
    -- Note: Moved from of precombat
    if S.ArcaneIntellect:IsCastable() and (S.ArcaneFamiliar:IsAvailable() and Player:BuffDown(S.ArcaneFamiliarBuff) or Everyone.GroupBuffMissing(S.ArcaneIntellect)) then
      if Cast(S.ArcaneIntellect, Settings.CommonsOGCD.GCDasOffGCD.ArcaneIntellect) then return "arcane_intellect group_buff"; end
    end
    -- call precombat
    if not Player:AffectingCombat() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    -- counterspell
    local ShouldReturn = Everyone.Interrupt(S.Counterspell, Settings.CommonsDS.DisplayStyle.Interrupts); if ShouldReturn then return ShouldReturn; end
    -- potion,if=!equipped.spymasters_web&(buff.siphon_storm.up|(!talent.evocation&cooldown.arcane_surge.ready))|equipped.spymasters_web&(buff.spymasters_web.up|(fight_remains>330&buff.siphon_storm.up))
    if Settings.Commons.Enabled.Potions and (not I.SpymastersWeb:IsEquipped() and (Player:BuffUp(S.SiphonStormBuff) or (not S.Evocation:IsAvailable() and S.ArcaneSurge:CooldownUp())) or I.SpymastersWeb:IsEquipped() and (Player:BuffUp(S.SpymastersWebBuff) or (FightRemains > 330 and Player:BuffUp(S.SiphonStormBuff)))) then
      local PotionSelected = Everyone.PotionSelected()
      if PotionSelected and PotionSelected:IsReady() then
        if Cast(PotionSelected, nil, Settings.CommonsDS.DisplayStyle.Potions) then return "potion main 2"; end
      end
    end
    if CDsON() then
      -- lights_judgment,if=(buff.arcane_surge.down&debuff.touch_of_the_magi.down&active_enemies>=2)
      if S.LightsJudgment:IsCastable() and (Player:BuffDown(S.ArcaneSurgeBuff) and Target:DebuffDown(S.TouchoftheMagiDebuff) and EnemiesCount8ySplash >= 2) then
        if Cast(S.LightsJudgment, Settings.CommonsOGCD.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.LightsJudgment)) then return "lights_judgment main 4"; end
      end
      if (Player:PrevGCDP(1, S.ArcaneSurge) and VarOpener) or ((Player:PrevGCDP(1, S.ArcaneSurge) and (FightRemains < 80 or Target:HealthPercentage() < 35 or not S.ArcaneBombardment:IsAvailable() or Player:BuffUp(S.SpymastersWebBuff))) or (Player:PrevGCDP(1, S.ArcaneSurge) and not I.SpymastersWeb:IsEquipped())) then
        -- berserking,if=(prev_gcd.1.arcane_surge&variable.opener)|((prev_gcd.1.arcane_surge&(fight_remains<80|target.health.pct<35|!talent.arcane_bombardment|buff.spymasters_web.up))|(prev_gcd.1.arcane_surge&!equipped.spymasters_web))
        if S.Berserking:IsCastable() then
          if Cast(S.Berserking, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "berserking main 6"; end
        end
        -- blood_fury,if=(prev_gcd.1.arcane_surge&variable.opener)|((prev_gcd.1.arcane_surge&(fight_remains<80|target.health.pct<35|!talent.arcane_bombardment|buff.spymasters_web.up))|(prev_gcd.1.arcane_surge&!equipped.spymasters_web))
        if S.BloodFury:IsCastable() then
          if Cast(S.BloodFury, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "blood_fury main 8"; end
        end
        -- fireblood,if=(prev_gcd.1.arcane_surge&variable.opener)|((prev_gcd.1.arcane_surge&(fight_remains<80|target.health.pct<35|!talent.arcane_bombardment|buff.spymasters_web.up))|(prev_gcd.1.arcane_surge&!equipped.spymasters_web))
        if S.Fireblood:IsCastable() then
          if Cast(S.Fireblood, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "fireblood main 10"; end
        end
        -- ancestral_call,if=(prev_gcd.1.arcane_surge&variable.opener)|((prev_gcd.1.arcane_surge&(fight_remains<80|target.health.pct<35|!talent.arcane_bombardment|buff.spymasters_web.up))|(prev_gcd.1.arcane_surge&!equipped.spymasters_web))
        if S.AncestralCall:IsCastable() then
          if Cast(S.AncestralCall, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "ancestral_call main 12"; end
        end
      end
    end
    -- invoke_external_buff,name=power_infusion,if=(!equipped.spymasters_web&prev_gcd.1.arcane_surge)|(equipped.spymasters_web&prev_gcd.1.evocation)
    -- invoke_external_buff,name=blessing_of_summer,if=prev_gcd.1.arcane_surge
    -- invoke_external_buff,name=blessing_of_autumn,if=cooldown.touch_of_the_magi.remains>5
    -- Note: Not handling external buffs.
    -- use_items,if=prev_gcd.1.arcane_surge|prev_gcd.1.evocation|fight_remains<20|!variable.steroid_trinket_equipped
    if Settings.Commons.Enabled.Items or Settings.Commons.Enabled.Trinkets then
      local ItemToUse, ItemSlot, ItemRange = Player:GetUseableItems(OnUseExcludes)
      if ItemToUse and (Player:PrevGCDP(1, S.ArcaneSurge) or Player:PrevGCDP(1, S.Evocation) or BossFightRemains < 20 or not VarSteroidTrinketEquipped) then
        local DisplayStyle = Settings.CommonsDS.DisplayStyle.Trinkets
        if ItemSlot ~= 13 and ItemSlot ~= 14 then DisplayStyle = Settings.CommonsDS.DisplayStyle.Items end
        if ((ItemSlot == 13 or ItemSlot == 14) and Settings.Commons.Enabled.Trinkets) or (ItemSlot ~= 13 and ItemSlot ~= 14 and Settings.Commons.Enabled.Items) then
          if Cast(ItemToUse, nil, DisplayStyle, not Target:IsInRange(ItemRange)) then return "Generic use_items for " .. ItemToUse:Name() .. " main 14"; end
        end
      end
    end
    if Settings.Commons.Enabled.Trinkets then
      -- use_item,name=treacherous_transmitter,if=buff.spymasters_report.stack<40
      if I.TreacherousTransmitter:IsEquippedAndReady() and (Player:BuffStack(S.SpymastersReportBuff) < 40) then
        if Cast(I.TreacherousTransmitter, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "treacherous_transmitter main 16"; end
      end
      -- use_item,name=spymasters_web,if=((prev_gcd.1.arcane_surge|prev_gcd.1.evocation)&(fight_remains<80|target.health.pct<35|!talent.arcane_bombardment|(buff.spymasters_report.stack=40&fight_remains>240))|fight_remains<20)
      if I.SpymastersWeb:IsEquippedAndReady() and ((Player:PrevGCDP(1, S.ArcaneSurge) or Player:PrevGCDP(1, S.Evocation)) and (FightRemains < 80 or Target:HealthPercentage() < 35 or not S.ArcaneBombardment:IsAvailable() or (Player:BuffStack(S.SpymastersReportBuff) == 40 and FightRemains > 240)) or BossFightRemains < 20) then
        if Cast(I.SpymastersWeb, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "spymasters_web main 18"; end
      end
      -- use_item,name=high_speakers_accretion,if=(prev_gcd.1.arcane_surge|prev_gcd.1.evocation|(buff.siphon_storm.up&variable.opener)|cooldown.evocation.remains<4|fight_remains<20)&(buff.spymasters_report.stack<35)
      if I.HighSpeakersAccretion:IsEquippedAndReady() and ((Player:PrevGCDP(1, S.ArcaneSurge) or Player:PrevGCDP(1, S.Evocation) or (Player:BuffUp(S.SiphonStormBuff) and VarOpener) or S.Evocation:CooldownRemains() < 4 or BossFightRemains < 20) and (Player:BuffStack(S.SpymastersReportBuff) < 35)) then
        if Cast(I.HighSpeakersAccretion, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsItemInRange(I.HighSpeakersAccretion)) then return "high_speakers_accretion main 20"; end
      end
      -- use_item,name=imperfect_ascendancy_serum,if=cooldown.evocation.ready|cooldown.arcane_surge.ready|fight_remains<20
      if I.ImperfectAscendancySerum:IsEquippedAndReady() and (S.Evocation:CooldownUp() or S.ArcaneSurge:CooldownUp() or BossFightRemains < 20) then
        if Cast(I.ImperfectAscendancySerum, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "imperfect_ascendancy_serum main 22"; end
      end
      -- use_item,name=treacherous_transmitter,if=(cooldown.evocation.remains<7&cooldown.evocation.remains)|buff.siphon_storm.remains>15|fight_remains<20
      if I.TreacherousTransmitter:IsEquippedAndReady() and ((S.Evocation:CooldownRemains() < 7 and S.Evocation:CooldownDown()) or Player:BuffRemains(S.SiphonStormBuff) > 15 or BossFightRemains < 20) then
        if Cast(I.TreacherousTransmitter, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "treacherous_transmitter main 24"; end
      end
      -- do_treacherous_transmitter_task,use_off_gcd=1,if=buff.siphon_storm.up|fight_remains<20|(buff.cryptic_instructions.remains<?buff.realigning_nexus_convergence_divergence.remains<?buff.errant_manaforge_emission.remains)<3
      -- use_item,name=aberrant_spellforge,if=!variable.steroid_trinket_equipped|buff.siphon_storm.down|(equipped.spymasters_web&target.health.pct>35)
      if I.AberrantSpellforge:IsEquippedAndReady() and (not VarSteroidTrinketEquipped or Player:BuffDown(S.SiphonStormBuff) or (I.SpymastersWeb:IsEquipped() and Target:HealthPercentage() > 35)) then
        if Cast(I.AberrantSpellforge, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "aberrant_spellforge main 26"; end
      end
      -- use_item,name=mad_queens_mandate,if=!variable.steroid_trinket_equipped|buff.siphon_storm.down
      if I.MadQueensMandate:IsEquippedAndReady() and (not VarSteroidTrinketEquipped or Player:BuffDown(S.SiphonStormBuff)) then
        if Cast(I.MadQueensMandate, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsItemInRange(I.MadQueensMandate)) then return "mad_queens_mandate main 28"; end
      end
      -- use_item,name=fearbreakers_echo,if=!variable.steroid_trinket_equipped|buff.siphon_storm.down
      if I.FearbreakersEcho:IsEquippedAndReady() and (not VarSteroidTrinketEquipped or Player:BuffDown(S.SiphonStormBuff)) then
        if Cast(I.FearbreakersEcho, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsItemInRange(I.FearbreakersEcho)) then return "fearbreakers_echo main 30"; end
      end
      -- use_item,name=mereldars_toll,if=!variable.steroid_trinket_equipped|buff.siphon_storm.down
      if I.MereldarsToll:IsEquippedAndReady() and (not VarSteroidTrinketEquipped or Player:BuffDown(S.SiphonStormBuff)) then
        if Cast(I.MereldarsToll, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsItemInRange(I.MereldarsToll)) then return "mereldars_toll main 32"; end
      end
    end
    -- variable,name=opener,op=set,if=debuff.touch_of_the_magi.up&variable.opener,value=0
    -- Note: Added extra TotM checks so we don't get stuck in the opener if TotM is on CD or not talented.
    if (Target:DebuffUp(S.TouchoftheMagiDebuff) or S.TouchoftheMagi:CooldownRemains() > Player:GCD() * 4 or not S.TouchoftheMagi:IsAvailable()) and VarOpener then
      VarOpener = false
    end
    -- arcane_barrage,if=fight_remains<2
    if S.ArcaneBarrage:IsReady() and (FightRemains < 2) then
      if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage main 34"; end
    end
    -- call_action_list,name=cd_opener
    if CDsON() then
      local ShouldReturn = CDOpener(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=sunfury_aoe,if=talent.spellfire_spheres&variable.aoe_list
    if AoEON() and (S.SpellfireSpheres:IsAvailable() and VarAoEList) then
      local ShouldReturn = SunfuryAoE(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=spellslinger_aoe,if=!talent.spellfire_spheres&variable.aoe_list
    if AoEON() and (not S.SpellfireSpheres:IsAvailable() and VarAoEList) then
      local ShouldReturn = SpellslingerAoE(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=sunfury,if=talent.spellfire_spheres
    if S.SpellfireSpheres:IsAvailable() then
      local ShouldReturn = Sunfury(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=spellslinger,if=!talent.spellfire_spheres
    if not S.SpellfireSpheres:IsAvailable() then
      local ShouldReturn = Spellslinger(); if ShouldReturn then return ShouldReturn; end
    end
    -- arcane_barrage
    if S.ArcaneBarrage:IsReady() then
      if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage main 36"; end
    end
  end
end

local function Init()
  HR.Print("Arcane Mage rotation has been updated for patch 11.0.5.")
end

HR.SetAPL(62, APL, Init)

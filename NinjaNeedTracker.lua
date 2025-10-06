-- NinjaNeedTracker - MoP Classic
-- Flags party/raid members who roll NEED on gear their class can't use.
-- SavedVariables: NinjaNeedDB

local ADDON = "NinjaNeedTracker"
local NNT = CreateFrame("Frame")
NNT.roster = {}
NNT.cfg = {
  verbose = true,
  checkWeapons = true,       -- toggle weapon-eligibility checks
  checkArmor = true,         -- toggle armor-eligibility checks
  announceInInstance = true, -- echo to INSTANCE_CHAT if you're in LFG/RDF
}

-- Saved DB { offenders = { ["Name-Realm"] = { count=n, last=timestamp } } }
NinjaNeedDB = NinjaNeedDB or { offenders = {} }

-- Utility: safe name (strip realm if same)
local function CanonicalName(name)
  if not name then return nil end
  local n, r = name:match("^([^%-]+)%-?(.*)$")
  if r == "" or not r then r = GetRealmName():gsub("%s+", "") end
  return n .. "-" .. r
end

-- Group roster snapshot
local function BuildRoster()
  wipe(NNT.roster)
  local function addUnit(unit)
    if UnitExists(unit) then
      local name = UnitName(unit)
      local _, classENG = UnitClass(unit)
      if name and classENG then
        NNT.roster[CanonicalName(name)] = classENG
      end
    end
  end
  if IsInRaid() then
    for i=1,40 do addUnit("raid"..i) end
  elseif IsInGroup() then
    for i=1,5 do addUnit("party"..i) end
    addUnit("player") -- include self
  end
end

-- Allowed armor per class (primary armor category only)
-- Using LE_ITEM_* constants from MoP era.
local ARMOR = {
  CLOTH  = LE_ITEM_ARMOR_CLOTH,
  LEATH  = LE_ITEM_ARMOR_LEATHER,
  MAIL   = LE_ITEM_ARMOR_MAIL,
  PLATE  = LE_ITEM_ARMOR_PLATE,
}

local CLASS_PRIMARY_ARMOR = {
  MAGE = ARMOR.CLOTH, PRIEST = ARMOR.CLOTH, WARLOCK = ARMOR.CLOTH,
  ROGUE = ARMOR.LEATH, DRUID = ARMOR.LEATH, MONK = ARMOR.LEATH,
  SHAMAN = ARMOR.MAIL, HUNTER = ARMOR.MAIL,
  WARRIOR = ARMOR.PLATE, PALADIN = ARMOR.PLATE, DEATHKNIGHT = ARMOR.PLATE,
}

-- ===== SAFE WEAPON CONSTANTS BUILDER (replaces local W/w() + CLASS_WEAPONS literal) =====
local function _const(name) return rawget(_G, name) end
local function _add(tbl, constName)
  local v = _const(constName)
  if v ~= nil then tbl[v] = true end    -- only add if the constant exists on this client
end

local function BuildAllowedWeapons()
  local M = {}

  M.WARRIOR = {}
  _add(M.WARRIOR, "LE_ITEM_WEAPON_AXE1H"); _add(M.WARRIOR, "LE_ITEM_WEAPON_AXE2H")
  _add(M.WARRIOR, "LE_ITEM_WEAPON_MACE1H"); _add(M.WARRIOR, "LE_ITEM_WEAPON_MACE2H")
  _add(M.WARRIOR, "LE_ITEM_WEAPON_SWORD1H"); _add(M.WARRIOR, "LE_ITEM_WEAPON_SWORD2H")
  _add(M.WARRIOR, "LE_ITEM_WEAPON_POLEARM")

  M.PALADIN = {}
  _add(M.PALADIN, "LE_ITEM_WEAPON_AXE1H"); _add(M.PALADIN, "LE_ITEM_WEAPON_AXE2H")
  _add(M.PALADIN, "LE_ITEM_WEAPON_MACE1H"); _add(M.PALADIN, "LE_ITEM_WEAPON_MACE2H")
  _add(M.PALADIN, "LE_ITEM_WEAPON_SWORD1H"); _add(M.PALADIN, "LE_ITEM_WEAPON_SWORD2H")
  _add(M.PALADIN, "LE_ITEM_WEAPON_POLEARM")

  M.DEATHKNIGHT = {}
  _add(M.DEATHKNIGHT, "LE_ITEM_WEAPON_AXE1H"); _add(M.DEATHKNIGHT, "LE_ITEM_WEAPON_AXE2H")
  _add(M.DEATHKNIGHT, "LE_ITEM_WEAPON_MACE1H"); _add(M.DEATHKNIGHT, "LE_ITEM_WEAPON_MACE2H")
  _add(M.DEATHKNIGHT, "LE_ITEM_WEAPON_SWORD1H"); _add(M.DEATHKNIGHT, "LE_ITEM_WEAPON_SWORD2H")
  _add(M.DEATHKNIGHT, "LE_ITEM_WEAPON_POLEARM")

  M.HUNTER = {}
  _add(M.HUNTER, "LE_ITEM_WEAPON_POLEARM"); _add(M.HUNTER, "LE_ITEM_WEAPON_STAFF")
  _add(M.HUNTER, "LE_ITEM_WEAPON_SWORD1H"); _add(M.HUNTER, "LE_ITEM_WEAPON_AXE1H")
  _add(M.HUNTER, "LE_ITEM_WEAPON_AXE2H")
  _add(M.HUNTER, "LE_ITEM_WEAPON_BOWS"); _add(M.HUNTER, "LE_ITEM_WEAPON_GUNS"); _add(M.HUNTER, "LE_ITEM_WEAPON_CROSSBOW")

  M.SHAMAN = {}
  _add(M.SHAMAN, "LE_ITEM_WEAPON_AXE1H"); _add(M.SHAMAN, "LE_ITEM_WEAPON_AXE2H")
  _add(M.SHAMAN, "LE_ITEM_WEAPON_MACE1H"); _add(M.SHAMAN, "LE_ITEM_WEAPON_MACE2H")
  _add(M.SHAMAN, "LE_ITEM_WEAPON_STAFF"); _add(M.SHAMAN, "LE_ITEM_WEAPON_FIST_WEAPON")

  M.ROGUE = {}
  _add(M.ROGUE, "LE_ITEM_WEAPON_DAGGER"); _add(M.ROGUE, "LE_ITEM_WEAPON_SWORD1H")
  _add(M.ROGUE, "LE_ITEM_WEAPON_MACE1H"); _add(M.ROGUE, "LE_ITEM_WEAPON_FIST_WEAPON")
  _add(M.ROGUE, "LE_ITEM_WEAPON_AXE1H")

  M.DRUID = {}
  _add(M.DRUID, "LE_ITEM_WEAPON_STAFF"); _add(M.DRUID, "LE_ITEM_WEAPON_POLEARM")
  _add(M.DRUID, "LE_ITEM_WEAPON_MACE1H"); _add(M.DRUID, "LE_ITEM_WEAPON_MACE2H")
  _add(M.DRUID, "LE_ITEM_WEAPON_DAGGER"); _add(M.DRUID, "LE_ITEM_WEAPON_FIST_WEAPON")

  M.MONK = {}
  _add(M.MONK, "LE_ITEM_WEAPON_STAFF"); _add(M.MONK, "LE_ITEM_WEAPON_POLEARM")
  _add(M.MONK, "LE_ITEM_WEAPON_SWORD1H"); _add(M.MONK, "LE_ITEM_WEAPON_AXE1H"); _add(M.MONK, "LE_ITEM_WEAPON_MACE1H")
  _add(M.MONK, "LE_ITEM_WEAPON_FIST_WEAPON")

  M.PRIEST = {}
  _add(M.PRIEST, "LE_ITEM_WEAPON_STAFF"); _add(M.PRIEST, "LE_ITEM_WEAPON_DAGGER"); _add(M.PRIEST, "LE_ITEM_WEAPON_WAND")

  M.MAGE = {}
  _add(M.MAGE, "LE_ITEM_WEAPON_STAFF"); _add(M.MAGE, "LE_ITEM_WEAPON_DAGGER"); _add(M.MAGE, "LE_ITEM_WEAPON_WAND")

  M.WARLOCK = {}
  _add(M.WARLOCK, "LE_ITEM_WEAPON_STAFF"); _add(M.WARLOCK, "LE_ITEM_WEAPON_DAGGER"); _add(M.WARLOCK, "LE_ITEM_WEAPON_WAND")

  return M
end

NNT.WEAPON_ALLOW = BuildAllowedWeapons()

-- Equip loc constants we always ignore (no armor-type restriction)
local IGNORE_EQUIPLOC = {
  INVTYPE_NECK = true, INVTYPE_FINGER = true, INVTYPE_TRINKET = true,
  INVTYPE_CLOAK = true, INVTYPE_HOLDABLE = true, -- off-hand frills
  INVTYPE_RELIC = true, -- MoP-era relics/trinkets; safe-ignore
}

-- Shields: only Warrior/Paladin/Shaman can equip shields
local function CanUseShield(classENG) return (classENG=="WARRIOR" or classENG=="PALADIN" or classENG=="SHAMAN") end

-- Simple announcer
local function Announce(msg)
  if NNT.cfg.verbose then
    print("|cffff5050[NNT]|r "..msg)
  end
  if NNT.cfg.announceInInstance and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
    SendChatMessage("[NNT] "..msg, "INSTANCE_CHAT")
  end
end

-- Record an offense
local function FlagOffense(player, itemLink, reason)
  local key = CanonicalName(player)
  local t = NinjaNeedDB.offenders[key] or { count=0, last=0 }
  t.count = t.count + 1
  t.last  = time()
  NinjaNeedDB.offenders[key] = t
  Announce(("Flagged |cffd9d919%s|r NEED on %s |cffff7070(%s)|r — offenses: |cffffd100%d|r"):format(player, itemLink, reason, t.count))
end

-- Determine if the class can use the armor type
local function ArmorCheck(classENG, subClassID, equipLoc)
  if IGNORE_EQUIPLOC[equipLoc] then return true end
  -- Shields are special
  if equipLoc == "INVTYPE_SHIELD" then return CanUseShield(classENG) end
  if subClassID == LE_ITEM_ARMOR_SHIELD then return CanUseShield(classENG) end

  local primary = CLASS_PRIMARY_ARMOR[classENG]
  if not primary then return true end -- unknown class? be permissive
  return subClassID == primary
end

-- Determine if the class can use the weapon subtype
local function WeaponCheck(classENG, weaponSubID)
  local allowed = NNT.WEAPON_ALLOW and NNT.WEAPON_ALLOW[classENG]
  if not allowed or not next(allowed) then return true end   -- if we couldn't build constants on this client, don't false-flag
  if weaponSubID == nil then return true end
  return allowed[weaponSubID] == true
end


-- Analyze item for a given class; return (isUsable, reasonIfNot)
local function IsUsableByClass(itemLink, classENG)
  local itemID, itemType, itemSubType, itemEquipLoc, classID, subClassID = GetItemInfoInstant(itemLink)
  if not classID then return true end -- can't tell; don't flag
  -- Armor
  if NNT.cfg.checkArmor and classID == LE_ITEM_CLASS_ARMOR then
    -- ignore shirts/tabards/misc
    if subClassID == LE_ITEM_ARMOR_MISCELLANEOUS or subClassID == LE_ITEM_ARMOR_COSMETIC then
      return true
    end
    if not ArmorCheck(classENG, subClassID, itemEquipLoc) then
      return false, "wrong armor type"
    end
  end
  -- Weapons
  if NNT.cfg.checkWeapons and classID == LE_ITEM_CLASS_WEAPON then
    if not WeaponCheck(classENG, subClassID) then
      return false, "unusable weapon type"
    end
  end
  return true
end

-- Localization-agnostic roll detection via global strings → patterns
local function BuildRollPatterns()
  local patterns = {}
  local candidates = {
    LOOT_ROLL_NEED,      -- "%s has selected Need for: %s"
    LOOT_ROLL_NEED_SELF, -- "You selected Need for: %s"
    LOOT_ROLL_ROLL,      -- "%s has rolled %d for %s (Need)"
  }
  for _, s in ipairs(candidates) do
    if type(s) == "string" then
      local p = s
      p = p:gsub("%%s", "(.+)"):gsub("%%d", "(%%d+)")
      p = p:gsub("([%%%+%-%^%$%*%?%[%]%(%)%._])", "%%%1")
      table.insert(patterns, p)
    end
  end
  return patterns
end

NNT.patterns = nil

-- Parse incoming chat/system lines to (player, itemLink)
local function ParseRollLine(msg)
  -- Try all patterns we minted from globals
  if not NNT.patterns then NNT.patterns = BuildRollPatterns() end
  for _, p in ipairs(NNT.patterns) do
    local a,b,c = msg:match(p)
    -- Heuristics across locales:
    -- common variants produce (player,item) or (player, number, item)
    if a and b and a:find("|Hitem:") then
      return UnitName("player"), a -- (SELF pattern) treat as you
    elseif a and b and b:find("|Hitem:") then
      return a, b
    elseif a and c and c:find("|Hitem:") then
      return a, c
    end
  end

  -- Fallback English parse (if globals missing for some clients)
  -- e.g., "X has selected Need for: [Item Link]"
  local player, item = msg:match("^(.+) has selected Need for: (.+)$")
  if player and item and item:find("|Hitem:") then return player, item end

  -- Another common format:
  -- "X has rolled 99 for [Item Link] (Need)"
  local player2, item2 = msg:match("^(.+) has rolled %d+ for (.+) %((.+)%)$")
  if player2 and item2 and item2:find("|Hitem:") and msg:find("Need") then
    return player2, item2
  end
end

-- Main evaluator when a NEED selection is spotted
local function OnNeedRoll(playerRaw, itemLink)
  local player = CanonicalName(playerRaw)
  local classENG = NNT.roster[player]
  if not classENG then
    -- Try to resolve via GUID from nameplate/raid roster later; but don't spam.
    return
  end
  local ok, reason = IsUsableByClass(itemLink, classENG)
  if ok then return end
  FlagOffense(playerRaw, itemLink, reason or "unusable")
end

-- Slash commands
SLASH_NNT1 = "/nnt"
SlashCmdList.NNT = function(msg)
  msg = (msg or ""):lower()
  if msg == "show" or msg == "list" then
    print("|cffff5050[NNT]|r Offender counts:")
    local any=false
    for name,t in pairs(NinjaNeedDB.offenders) do
      any=true
      local ago = SecondsToTime(time() - (t.last or 0))
      print((" - |cffd9d919%s|r : |cffffd100%d|r (last %s ago)"):format(name, t.count or 0, ago))
    end
    if not any then print(" - none recorded") end

  elseif msg:match("^clear%s+all") then
    NinjaNeedDB.offenders = {}
    print("|cffff5050[NNT]|r Cleared all offender records.")

  elseif msg:match("^clear%s+") then
    local name = msg:match("^clear%s+(.+)$")
    name = CanonicalName(name)
    if NinjaNeedDB.offenders[name] then
      NinjaNeedDB.offenders[name] = nil
      print("|cffff5050[NNT]|r Cleared: "..(name or "?"))
    else
      print("|cffff5050[NNT]|r No record for: "..(name or "?"))
    end

  elseif msg == "verbose on" then
    NNT.cfg.verbose = true; print("|cffff5050[NNT]|r Verbose ON")
  elseif msg == "verbose off" then
    NNT.cfg.verbose = false; print("|cffff5050[NNT]|r Verbose OFF")

  elseif msg == "weapons on" then
    NNT.cfg.checkWeapons = true; print("|cffff5050[NNT]|r Weapon checks ON")
  elseif msg == "weapons off" then
    NNT.cfg.checkWeapons = false; print("|cffff5050[NNT]|r Weapon checks OFF")

  elseif msg == "armor on" then
    NNT.cfg.checkArmor = true; print("|cffff5050[NNT]|r Armor checks ON")
  elseif msg == "armor off" then
    NNT.cfg.checkArmor = false; print("|cffff5050[NNT]|r Armor checks OFF")

  else
    print("|cffff5050[NNT]|r Commands:")
    print("  /nnt show            - list offenders & counts")
    print("  /nnt clear <name>    - clear one player")
    print("  /nnt clear all       - wipe all records")
    print("  /nnt verbose on/off  - toggle chat spam")
    print("  /nnt weapons on/off  - toggle weapon-type checks")
    print("  /nnt armor on/off    - toggle armor-type checks")
  end
end

-- Event wiring
NNT:SetScript("OnEvent", function(_, event, ...)
  if event == "PLAYER_ENTERING_WORLD" or event == "GROUP_ROSTER_UPDATE" then
    BuildRoster()
    return
  end

  -- Need roll detection via chat/system feed (localization-safe)
  if event == "CHAT_MSG_SYSTEM" or event == "CHAT_MSG_LOOT" then
    local msg = ...
    local player, itemLink = ParseRollLine(msg)
    if player and itemLink then
      -- Only care if they're in our current roster (party/raid)
      local key = CanonicalName(player)
      if NNT.roster[key] then
        OnNeedRoll(player, itemLink)
      end
    end
  end
end)

NNT:RegisterEvent("PLAYER_ENTERING_WORLD")
NNT:RegisterEvent("GROUP_ROSTER_UPDATE")
NNT:RegisterEvent("CHAT_MSG_SYSTEM")
NNT:RegisterEvent("CHAT_MSG_LOOT")

-- Quality-of-life: report config on load
C_Timer.After(2, function()
  print("|cffff5050[NNT]|r loaded. Armor checks: "..(NNT.cfg.checkArmor and "ON" or "OFF")
        ..", Weapon checks: "..(NNT.cfg.checkWeapons and "ON" or "OFF")
        ..". Type |cffffff00/nnt|r for options.")
end)

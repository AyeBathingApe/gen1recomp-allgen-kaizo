-- Validates tools/pbs_convert.py output against the engine's real registry
-- schemas.  Run from the ENGINE repo root (src.* must be on package.path):
--
--   luajit <mod>/tools/check_gen.lua <mod>/gen
--
-- Dev tool, not mod code (lives under tools/, which is .modkitignore'd).

local genDir = arg[1] or "gen"
local Schemas = require("src.mods.Schemas")
local R = Schemas.REGISTRIES

local failures, checks = 0, 0

local function check(spec, registry, id, value, mode)
  checks = checks + 1
  local ok, err = Schemas.check(spec, registry, id, value, mode or "register")
  if not ok then
    failures = failures + 1
    print("FAIL " .. err)
  end
end

local function fail(msg)
  failures = failures + 1
  checks = checks + 1
  print("FAIL " .. msg)
end

local function loadGen(name)
  local chunk, err = loadfile(genDir .. "/" .. name)
  if not chunk then error("cannot load " .. name .. ": " .. tostring(err)) end
  return chunk()
end

local GEN1_TYPES = {
  NORMAL = true, FIGHTING = true, FLYING = true, POISON = true,
  GROUND = true, ROCK = true, BUG = true, GHOST = true, FIRE = true,
  WATER = true, GRASS = true, ELECTRIC = true, PSYCHIC = true,
  ICE = true, DRAGON = true,
}
local GROWTH = {
  MEDIUM_FAST = true, SLIGHTLY_FAST = true, SLIGHTLY_SLOW = true,
  MEDIUM_SLOW = true, FAST = true, SLOW = true,
}
local EVO_METHODS = { LEVEL = true, TRADE = true, ITEM = true }

-- effect vocabulary straight from the engine when it loads headless
local effectIds = nil
do
  local ok, MoveEffects = pcall(require, "src.battle.MoveEffects")
  if ok and type(MoveEffects) == "table" and MoveEffects.RECORDS then
    effectIds = {}
    for id in pairs(MoveEffects.RECORDS) do effectIds[id] = true end
  else
    print("note: src.battle.MoveEffects not loadable headless; "
      .. "effect ids not cross-checked")
  end
end

-- ---- types.lua

local T = loadGen("types.lua")
local knownTypes = {}
for id in pairs(GEN1_TYPES) do knownTypes[id] = true end
for _, t in ipairs(T.types) do
  check(R.type_chart, "type_chart", t.id,
    { name = t.name, category = t.category })
  knownTypes[t.id] = true
end
for _, row in ipairs(T.matchups) do
  check(R.type_chart, "type_chart", row.id, { multiplier = row.multiplier })
  local att, def = row.id:match("^([^>]+)>([^>]+)$")
  if not att then
    fail("type_chart." .. row.id .. ": not an ATT>DEF id")
  else
    if not knownTypes[att] then fail("matchup attacker unknown: " .. att) end
    if not knownTypes[def] then fail("matchup defender unknown: " .. def) end
  end
end

-- ---- moves.lua

local M = loadGen("moves.lua")
local knownMoves = {}
for _, mv in ipairs(M.moves) do
  local rec = {}
  for k, v in pairs(mv) do rec[k] = v end
  check(R.moves, "moves", mv.id, rec)
  if not knownTypes[mv.type] then
    fail("moves." .. mv.id .. ": unknown type " .. tostring(mv.type))
  end
  if effectIds and not effectIds[mv.effect] then
    fail("moves." .. mv.id .. ": unknown effect " .. tostring(mv.effect))
  end
  knownMoves[mv.id] = true
end

-- ---- species.lua

local S = loadGen("species.lua")
local knownSpecies = {}
for _, sp in ipairs(S.species) do knownSpecies[sp.id] = true end
for _, sp in ipairs(S.species) do
  check(R.pokemon, "pokemon", sp.id, sp)
  for _, t in ipairs(sp.types) do
    if not knownTypes[t] then
      fail("pokemon." .. sp.id .. ": unknown type " .. t)
    end
  end
  for _, mv in ipairs(sp.level1Moves) do
    if not knownMoves[mv] then
      fail("pokemon." .. sp.id .. ": unknown level1 move " .. mv)
    end
  end
  for _, row in ipairs(sp.learnset) do
    if not knownMoves[row.move] then
      fail("pokemon." .. sp.id .. ": unknown learnset move " .. row.move)
    end
  end
  for _, evo in ipairs(sp.evolutions) do
    if not EVO_METHODS[evo.method] then
      fail("pokemon." .. sp.id .. ": unknown evo method " .. evo.method)
    end
    if not knownSpecies[evo.species] then
      fail("pokemon." .. sp.id .. ": evo target not in set: " .. evo.species)
    end
  end
  if not GROWTH[sp.growthRate] then
    fail("pokemon." .. sp.id .. ": unknown growth rate " .. sp.growthRate)
  end
end

print(("%d/%d checks passed  (%d types, %d matchup rows, %d moves, "
  .. "%d species)"):format(checks - failures, checks, #T.types, #T.matchups,
  #M.moves, #S.species))
if failures > 0 then os.exit(1) end

-- Headless loader test for gen1_kaizo. Run from the gen1recomp repo root
-- with a Lua interpreter (the harness stubs love):
--
--   lua mods/gen1_kaizo/tests/test_kaizo.lua
--
-- Uses the engine's fixture dataset (FIXMON species, FIX_* moves), so it
-- asserts the mod's *degradation contract* as much as its effects: levels
-- always bump; padding and curated sets degrade to warnings when the
-- fixture registry lacks the real species/move ids.
package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.modkit")

local Data = T.fixtures.fresh()
local run = T.sdk.loadMod("mods/gen1_kaizo", { data = Data })
T.eq(#run.errors, 0, "loads clean")

-- Stated effect #1: static trainer level bump (+3), applied per slot of
-- every roster in the parties list. Fixture: OPP_FIX_YOUNGSTER has one
-- party of two level-5 mons.
local trainer = Data.trainers.OPP_FIX_YOUNGSTER
T.check(trainer and type(trainer.parties) == "table", "fixture trainer present")
local party = trainer.parties[1]
T.eq(party[1].level, 8, "slot 1 bumped 5 -> 8")
T.eq(party[2].level, 8, "slot 2 bumped 5 -> 8")

-- Stated effect #2: parties stay schema-valid. Padding species must exist
-- in the pokemon registry; the fixture set has none of the real Kanto ids,
-- so the party may stay short -- but never invalid, never over six.
T.check(#party >= 2 and #party <= 6, "party size stays in bounds")
for i, slot in ipairs(party) do
  T.check(type(slot.level) == "number" and type(slot.species) == "string",
    "slot " .. i .. " keeps the strict {level, species} shape")
  T.check(Data.pokemon[slot.species] ~= nil,
    "slot " .. i .. " species exists in the registry (" .. slot.species .. ")")
end

-- Stated effect #3: static wild level bump (+2) on grass/water slots.
-- Fixture: FIX_ROUTE grass = level-3 FIXMON_A, level-4 FIXMON_C. Rare-slot
-- species swaps also require registered species, so here only levels move.
local route = Data.encounters.FIX_ROUTE
T.check(route and route.grass and type(route.grass.slots) == "table",
  "fixture route present")
T.eq(route.grass.slots[1].level, 5, "grass slot 1 bumped 3 -> 5")
T.eq(route.grass.slots[2].level, 6, "grass slot 2 bumped 4 -> 6")

-- Stated effect #4: both battle seams are armed -- trainer.party carries
-- the curated movesets past the schema-strict registry slots, and
-- battle.enemy_action carries the competitive AI. The loader's own hook
-- bus is queried (run.loader.hooks) rather than engine internals, so no
-- engine_internals permission is needed.
local chains = run.loader.hooks.chains
T.check(chains["trainer.party"] ~= nil, "trainer.party hook registered")
T.check(chains["battle.enemy_action"] ~= nil, "battle.enemy_action hook registered")

-- Stated effect #5: the Genesis roster. When the generated gen/ data pack
-- is present (tools/pbs_convert.py output; gitignored, so absent in bare
-- checkouts), the merged dataset carries the new types, new moves, and
-- the expanded dex; without it the mod degrades to classic kaizo, which
-- the loads-clean check above already covers.
local hasGen = io.open("mods/gen1_kaizo/gen/species.lua", "r")
if hasGen then
  hasGen:close()
  T.check(Data.type_chart.types.DARK ~= nil, "DARK type registered")
  T.check(Data.moves.DARKPULSE ~= nil, "new move DARKPULSE registered")
  T.check(Data.pokemon.TOGEPI ~= nil, "new species TOGEPI registered")
  T.check(Data.pokemon.TOGEPI.baseStats.special ~= nil,
    "SpA/SpD folded into Gen 1 special")
else
  print("note: gen/ data pack absent; Genesis checks skipped")
end

run.release()
T.finish("gen1_kaizo")

-- One-off audit: tier sizes, legend pool, starter chains, type coverage.
-- Run from engine root: luajit mods/gen1_kaizo/tools/audit_gen.lua
local S = loadfile("mods/gen1_kaizo/gen/species.lua")()
local evoTarget = {}
for _, sp in ipairs(S.species) do
  for _, e in ipairs(sp.evolutions) do evoTarget[e.species] = true end
end
local tiers, water, legends, byType = {0,0,0,0}, {0,0}, {}, {}
for _, sp in ipairs(S.species) do
  if sp.dex > 151 then
    local s = sp.baseStats
    local bst = s.hp + s.attack + s.defense + s.speed + s.special
    local standalone = #sp.evolutions == 0 and not evoTarget[sp.id]
    if standalone and (sp.catchRate <= 5 or (bst >= 490 and sp.catchRate <= 45)) then
      legends[#legends + 1] = sp.id .. "(" .. bst .. "/cr" .. sp.catchRate .. ")"
    else
      if bst <= 545 then
        local t = bst <= 310 and 1 or bst <= 370 and 2 or bst <= 430 and 3 or 4
        tiers[t] = tiers[t] + 1
        for _, ty in ipairs(sp.types) do
          if ty == "WATER" then water[bst <= 370 and 1 or 2] = water[bst <= 370 and 1 or 2] + 1; break end
        end
      end
      for _, ty in ipairs(sp.types) do byType[ty] = (byType[ty] or 0) + 1 end
    end
  end
end
print(("land tiers: %d / %d / %d / %d   water: %d / %d"):format(
  tiers[1], tiers[2], tiers[3], tiers[4], water[1], water[2]))
local tl = {}
for ty, n in pairs(byType) do tl[#tl + 1] = ty .. "=" .. n end
table.sort(tl); print("bench type coverage: " .. table.concat(tl, " "))
print(#legends .. " legends:"); print(table.concat(legends, ", "))
-- starter chains reach their finals via LEVEL rows
local byId = {}
for _, sp in ipairs(S.species) do byId[sp.id] = sp end
for _, base in ipairs({"CHIKORITA","CYNDAQUIL","TOTODILE","TREECKO","TORCHIC",
    "MUDKIP","TURTWIG","CHIMCHAR","PIPLUP","SNIVY","TEPIG","OSHAWOTT",
    "CHESPIN","FENNEKIN","FROAKIE","ROWLET","LITTEN","POPPLIO"}) do
  local chain, sp = base, byId[base]
  while sp and #sp.evolutions > 0 do
    local e = sp.evolutions[1]
    chain = chain .. " -" .. (e.level or e.method) .. "-> " .. e.species
    sp = byId[e.species]
  end
  print(chain)
end

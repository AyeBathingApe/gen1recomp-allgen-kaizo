-- Gen 1 Kaizo: trainers hit harder, fight smarter, and the wild keeps
-- pace. Every trainer fields a full party of six padded with varied
-- species that fit the trainer's class, topped by one surprise ace, at a
-- flat static level bump. Species with a known competitive Gen 1 set get
-- it, and trainer AI picks moves competitively: exploiting type weaknesses,
-- spreading status, healing low, and never clicking into an immunity. The
-- very first rival battle stays vanilla: one starter, untouched.
--
-- To keep the player competitive, each area's encounter pool is widened:
-- the rare slots of every zone are replaced with fresh, progression-
-- appropriate species (Abra, Machop, Growlithe early; Scyther, Tangela
-- mid; Dratini, Lapras late), and wild levels get a small static bump so
-- catches stay viable against buffed trainers.
--
-- Follows the gallery discipline (see mods/examples/example_balance_tweaks):
-- team and encounter changes are patch + each over the merged view, and
-- every list (a trainer's parties, a zone's slots) is rebuilt in full
-- because lists replace wholesale inside a patch. Party slots stay
-- schema-strict {level, species}; the curated movesets ride the engine's
-- trainer.party hook instead, whose returned slots may carry a `moves`
-- list that the battle builder honors over the legacy boss-move tables.
-- The AI rides battle.enemy_action (src/battle/BattleState.lua
-- enemyAction) and returns entries from the enemy's own curMoves list --
-- the exact shape vanilla TrainerAI.chooseMove returns -- falling through
-- to the vanilla action for item/switch turns, Struggle, and multi-turn
-- locks.
--
-- Polish checklist: no bare error()/assert() in callbacks; every failure
-- path logs a warning that names a remediation and degrades to vanilla.

-- Tuning knobs. Keep these at the top so the whole difficulty curve is
-- auditable at a glance.
local PARTY_SIZE       = 6   -- every trainer fields a full team
local LEVEL_BONUS      = 3   -- flat, static level increase for every trainer Pokemon
local WILD_LEVEL_BONUS = 2   -- flat, static level increase for wild encounters
local RARE_SLOT_COUNT  = 3   -- rare slots per zone replaced with fresh species
local SET_MIN_LEVEL    = 25  -- curated sets only apply at/above this level, so
                             -- endgame TM sets never appear in the first hour
local LEVEL_CAP        = 100

-- Classic RBY competitive sets, keyed by species id. Any species not
-- listed keeps its vanilla trainer moves. Move ids use the pokered
-- constants; unknown ids are resolved through MOVE_ALIASES or dropped
-- with a warning rather than crashing the load.
local KAIZO_SETS = {
  ALAKAZAM   = { "PSYCHIC", "RECOVER", "THUNDER_WAVE", "SEISMIC_TOSS" },
  ARCANINE   = { "FIRE_BLAST", "BODY_SLAM", "HYPER_BEAM", "REFLECT" },
  ARTICUNO   = { "BLIZZARD", "ICE_BEAM", "REFLECT", "AGILITY" },
  BLASTOISE  = { "SURF", "BLIZZARD", "EARTHQUAKE", "BODY_SLAM" },
  CHANSEY    = { "ICE_BEAM", "THUNDERBOLT", "THUNDER_WAVE", "SOFTBOILED" },
  CHARIZARD  = { "FIRE_BLAST", "EARTHQUAKE", "SWORDS_DANCE", "HYPER_BEAM" },
  CLOYSTER   = { "BLIZZARD", "CLAMP", "HYPER_BEAM", "EXPLOSION" },
  DEWGONG    = { "BLIZZARD", "SURF", "BODY_SLAM", "REST" },
  DODRIO     = { "DRILL_PECK", "BODY_SLAM", "HYPER_BEAM", "AGILITY" },
  DRAGONITE  = { "WRAP", "AGILITY", "HYPER_BEAM", "BLIZZARD" },
  DUGTRIO    = { "EARTHQUAKE", "ROCK_SLIDE", "SLASH", "SUBSTITUTE" },
  ELECTABUZZ = { "THUNDERBOLT", "PSYCHIC", "THUNDER_WAVE", "SEISMIC_TOSS" },
  EXEGGUTOR  = { "PSYCHIC", "SLEEP_POWDER", "STUN_SPORE", "EXPLOSION" },
  FEAROW     = { "DRILL_PECK", "HYPER_BEAM", "BODY_SLAM", "AGILITY" },
  FLAREON    = { "FIRE_BLAST", "BODY_SLAM", "HYPER_BEAM", "FIRE_SPIN" },
  GENGAR     = { "HYPNOSIS", "PSYCHIC", "THUNDERBOLT", "EXPLOSION" },
  GOLDUCK    = { "AMNESIA", "SURF", "BLIZZARD", "REST" },
  GOLEM      = { "EARTHQUAKE", "ROCK_SLIDE", "BODY_SLAM", "EXPLOSION" },
  GYARADOS   = { "HYDRO_PUMP", "THUNDERBOLT", "BLIZZARD", "BODY_SLAM" },
  HAUNTER    = { "HYPNOSIS", "PSYCHIC", "THUNDERBOLT", "NIGHT_SHADE" },
  HYPNO      = { "PSYCHIC", "HYPNOSIS", "THUNDER_WAVE", "REST" },
  JOLTEON    = { "THUNDERBOLT", "THUNDER_WAVE", "PIN_MISSILE", "BODY_SLAM" },
  JYNX       = { "LOVELY_KISS", "BLIZZARD", "PSYCHIC", "REST" },
  KADABRA    = { "PSYCHIC", "RECOVER", "THUNDER_WAVE", "SEISMIC_TOSS" },
  KANGASKHAN = { "BODY_SLAM", "HYPER_BEAM", "EARTHQUAKE", "SURF" },
  LAPRAS     = { "BLIZZARD", "THUNDERBOLT", "BODY_SLAM", "CONFUSE_RAY" },
  MACHAMP    = { "SUBMISSION", "EARTHQUAKE", "BODY_SLAM", "ROCK_SLIDE" },
  MAGMAR     = { "FIRE_BLAST", "PSYCHIC", "BODY_SLAM", "CONFUSE_RAY" },
  MEW        = { "PSYCHIC", "SWORDS_DANCE", "THUNDER_WAVE", "SOFTBOILED" },
  MEWTWO     = { "PSYCHIC", "AMNESIA", "RECOVER", "BLIZZARD" },
  MOLTRES    = { "FIRE_BLAST", "HYPER_BEAM", "FIRE_SPIN", "AGILITY" },
  MUK        = { "SLUDGE", "BODY_SLAM", "EXPLOSION", "THUNDERBOLT" },
  NIDOKING   = { "EARTHQUAKE", "THUNDERBOLT", "BLIZZARD", "BODY_SLAM" },
  NIDOQUEEN  = { "EARTHQUAKE", "THUNDERBOLT", "BLIZZARD", "BODY_SLAM" },
  NINETALES  = { "FIRE_BLAST", "BODY_SLAM", "CONFUSE_RAY", "FIRE_SPIN" },
  PERSIAN    = { "SLASH", "HYPER_BEAM", "BUBBLEBEAM", "THUNDERBOLT" },
  PINSIR     = { "SWORDS_DANCE", "HYPER_BEAM", "BODY_SLAM", "SUBMISSION" },
  POLIWRATH  = { "AMNESIA", "SURF", "BLIZZARD", "HYPNOSIS" },
  PRIMEAPE   = { "SUBMISSION", "BODY_SLAM", "ROCK_SLIDE", "THUNDERBOLT" },
  RAICHU     = { "THUNDERBOLT", "THUNDER_WAVE", "SURF", "BODY_SLAM" },
  RAPIDASH   = { "FIRE_BLAST", "BODY_SLAM", "HYPER_BEAM", "FIRE_SPIN" },
  RHYDON     = { "EARTHQUAKE", "ROCK_SLIDE", "BODY_SLAM", "SUBSTITUTE" },
  SANDSLASH  = { "EARTHQUAKE", "ROCK_SLIDE", "BODY_SLAM", "SWORDS_DANCE" },
  SCYTHER    = { "SWORDS_DANCE", "SLASH", "HYPER_BEAM", "AGILITY" },
  SLOWBRO    = { "AMNESIA", "PSYCHIC", "THUNDER_WAVE", "REST" },
  SNORLAX    = { "BODY_SLAM", "REFLECT", "EARTHQUAKE", "REST" },
  STARMIE    = { "PSYCHIC", "BLIZZARD", "THUNDER_WAVE", "RECOVER" },
  TAUROS     = { "BODY_SLAM", "HYPER_BEAM", "EARTHQUAKE", "BLIZZARD" },
  TENTACRUEL = { "SURF", "BLIZZARD", "WRAP", "HYPER_BEAM" },
  VAPOREON   = { "SURF", "BLIZZARD", "BODY_SLAM", "REST" },
  VENUSAUR   = { "RAZOR_LEAF", "SLEEP_POWDER", "SWORDS_DANCE", "BODY_SLAM" },
  VICTREEBEL = { "RAZOR_LEAF", "SLEEP_POWDER", "STUN_SPORE", "WRAP" },
  WEEZING    = { "SLUDGE", "THUNDERBOLT", "FIRE_BLAST", "EXPLOSION" },
  ZAPDOS     = { "THUNDERBOLT", "DRILL_PECK", "THUNDER_WAVE", "AGILITY" },
}

-- Engines may name a few moves differently than pokered; try each
-- alias in order before giving up on a move.
local MOVE_ALIASES = {
  PSYCHIC    = { "PSYCHIC", "PSYCHIC_M" },
  SOFTBOILED = { "SOFTBOILED", "SOFT_BOILED" },
  BUBBLEBEAM = { "BUBBLEBEAM", "BUBBLE_BEAM" },
}

-- Padding themes, keyed by trainer class: the registry id with its OPP_
-- prefix and trailing numbering stripped (OPP_RIVAL1 -> RIVAL). `pool` is
-- the type-flavored bench a class would plausibly carry; `ace` is the one
-- surprise closer. Unknown classes fall back to GENERIC_THEME. Class ids
-- follow tools/rom_manifest.json's trainers order.
local CLASS_THEMES = {
  YOUNGSTER     = { pool = { "RATTATA", "SPEAROW", "EKANS", "SANDSHREW", "NIDORAN_M" }, ace = "RATICATE" },
  BUG_CATCHER   = { pool = { "CATERPIE", "WEEDLE", "METAPOD", "KAKUNA", "BUTTERFREE", "BEEDRILL" }, ace = "SCYTHER" },
  LASS          = { pool = { "PIDGEY", "NIDORAN_F", "ODDISH", "BELLSPROUT", "MEOWTH" }, ace = "CLEFAIRY" },
  JR_TRAINER_M  = { pool = { "SPEAROW", "RATICATE", "SANDSHREW", "MANKEY", "NIDORAN_M" }, ace = "NIDORINO" },
  JR_TRAINER_F  = { pool = { "PIDGEY", "ODDISH", "BELLSPROUT", "MEOWTH", "PIKACHU" }, ace = "PIDGEOTTO" },
  SAILOR        = { pool = { "POLIWAG", "SHELLDER", "HORSEA", "TENTACOOL", "MACHOP" }, ace = "POLIWRATH" },
  HIKER         = { pool = { "GEODUDE", "GRAVELER", "ONIX", "MACHOP", "SANDSLASH" }, ace = "GOLEM" },
  FISHER        = { pool = { "MAGIKARP", "POLIWAG", "GOLDEEN", "HORSEA", "TENTACOOL" }, ace = "GYARADOS" },
  SWIMMER       = { pool = { "TENTACOOL", "HORSEA", "SHELLDER", "STARYU", "GOLDEEN" }, ace = "SEADRA" },
  BIKER         = { pool = { "KOFFING", "GRIMER", "EKANS", "MANKEY", "MACHOP" }, ace = "WEEZING" },
  CUE_BALL      = { pool = { "MANKEY", "MACHOP", "PRIMEAPE", "KOFFING", "GRIMER" }, ace = "MACHOKE" },
  BURGLAR       = { pool = { "GROWLITHE", "VULPIX", "PONYTA", "CHARMANDER", "MAGMAR" }, ace = "NINETALES" },
  ENGINEER      = { pool = { "MAGNEMITE", "VOLTORB", "PIKACHU", "GRIMER" }, ace = "MAGNETON" },
  GAMBLER       = { pool = { "GROWLITHE", "VULPIX", "PONYTA", "VOLTORB", "MEOWTH" }, ace = "RAPIDASH" },
  BEAUTY        = { pool = { "ODDISH", "BELLSPROUT", "GOLDEEN", "MEOWTH", "PIDGEOTTO" }, ace = "WIGGLYTUFF" },
  PSYCHIC_TR    = { pool = { "ABRA", "KADABRA", "DROWZEE", "SLOWPOKE", "MR_MIME" }, ace = "HYPNO" },
  ROCKER        = { pool = { "VOLTORB", "MAGNEMITE", "PIKACHU" }, ace = "ELECTABUZZ" },
  JUGGLER       = { pool = { "DROWZEE", "ABRA", "KADABRA", "MR_MIME", "VOLTORB" }, ace = "HYPNO" },
  TAMER         = { pool = { "SANDSLASH", "ARBOK", "RHYHORN", "PERSIAN", "PRIMEAPE" }, ace = "RHYDON" },
  BIRD_KEEPER   = { pool = { "PIDGEOTTO", "SPEAROW", "FEAROW", "DODUO", "FARFETCHD" }, ace = "DODRIO" },
  BLACKBELT     = { pool = { "MACHOP", "MACHOKE", "MANKEY", "PRIMEAPE", "HITMONCHAN" }, ace = "HITMONLEE" },
  ROCKET        = { pool = { "ZUBAT", "EKANS", "SANDSHREW", "KOFFING", "GRIMER", "DROWZEE" }, ace = "ARBOK" },
  SCIENTIST     = { pool = { "MAGNEMITE", "VOLTORB", "KOFFING", "GRIMER", "ABRA" }, ace = "PORYGON" },
  POKEMANIAC    = { pool = { "SLOWPOKE", "RHYHORN", "CUBONE", "LICKITUNG", "CHARMELEON" }, ace = "KANGASKHAN" },
  SUPER_NERD    = { pool = { "MAGNEMITE", "VOLTORB", "KOFFING", "GRIMER", "VULPIX" }, ace = "ELECTRODE" },
  CHANNELER     = { pool = { "GASTLY", "HAUNTER" }, ace = "GENGAR" },
  GENTLEMAN     = { pool = { "GROWLITHE", "PONYTA", "PIKACHU", "NIDORAN_M", "MEOWTH" }, ace = "PERSIAN" },
  COOLTRAINER_M = { pool = { "PIDGEOTTO", "GROWLITHE", "EXEGGCUTE", "RHYHORN", "KADABRA" }, ace = "NIDOKING" },
  COOLTRAINER_F = { pool = { "PIDGEOTTO", "VULPIX", "GLOOM", "SEEL", "KADABRA" }, ace = "NIDOQUEEN" },
  RIVAL         = { pool = { "PIDGEOTTO", "RATICATE", "KADABRA", "GROWLITHE", "EXEGGCUTE" }, ace = "GYARADOS" },
  -- Gym leaders and the Elite Four pad within their own type.
  BROCK         = { pool = { "GEODUDE", "GRAVELER", "RHYHORN", "SANDSHREW", "ONIX" }, ace = "GOLEM" },
  MISTY         = { pool = { "GOLDEEN", "SHELLDER", "HORSEA", "POLIWAG", "SEEL" }, ace = "GYARADOS" },
  LT_SURGE      = { pool = { "VOLTORB", "PIKACHU", "MAGNEMITE", "MAGNETON", "ELECTRODE" }, ace = "ELECTABUZZ" },
  ERIKA         = { pool = { "ODDISH", "GLOOM", "BELLSPROUT", "WEEPINBELL", "EXEGGCUTE" }, ace = "EXEGGUTOR" },
  KOGA          = { pool = { "GRIMER", "KOFFING", "ZUBAT", "GOLBAT", "TENTACOOL" }, ace = "MUK" },
  SABRINA       = { pool = { "ABRA", "KADABRA", "DROWZEE", "HYPNO", "MR_MIME" }, ace = "JYNX" },
  BLAINE        = { pool = { "GROWLITHE", "VULPIX", "PONYTA", "NINETALES", "MAGMAR" }, ace = "ARCANINE" },
  GIOVANNI      = { pool = { "SANDSLASH", "DUGTRIO", "RHYHORN", "NIDORINO", "PERSIAN" }, ace = "NIDOKING" },
  LORELEI       = { pool = { "DEWGONG", "CLOYSTER", "SEADRA", "GOLDUCK", "SEEL" }, ace = "ARTICUNO" },
  BRUNO         = { pool = { "MACHOP", "MACHOKE", "HITMONLEE", "HITMONCHAN", "ONIX" }, ace = "MACHAMP" },
  AGATHA        = { pool = { "GASTLY", "HAUNTER", "GOLBAT", "ARBOK" }, ace = "GENGAR" },
  LANCE         = { pool = { "DRATINI", "DRAGONAIR", "GYARADOS", "AERODACTYL" }, ace = "DRAGONITE" },
}

-- Trainer-staple normal types for classes without a theme of their own.
local GENERIC_THEME = {
  pool = { "RATICATE", "FEAROW", "PRIMEAPE", "PERSIAN", "TAUROS" },
  ace  = "KANGASKHAN",
}

-- Wild-encounter variety pools, picked by the zone's strongest slot level
-- so what you can catch keeps pace with what you are fighting. Land and
-- water zones draw from separate pools; a species already native to the
-- zone is never duplicated.
local LAND_TIERS = {
  { max = 10,  pool = { "ABRA", "MACHOP", "GROWLITHE", "VULPIX", "SANDSHREW", "PIKACHU" } },
  { max = 20,  pool = { "MAGNEMITE", "GASTLY", "CUBONE", "PONYTA", "GRIMER", "EEVEE" } },
  { max = 30,  pool = { "SCYTHER", "PINSIR", "LICKITUNG", "TANGELA", "KANGASKHAN", "ELECTABUZZ", "MAGMAR" } },
  { max = 999, pool = { "DRATINI", "LAPRAS", "AERODACTYL", "PORYGON", "HITMONLEE", "HITMONCHAN" } },
}
local WATER_TIERS = {
  { max = 20,  pool = { "PSYDUCK", "SLOWPOKE", "POLIWAG", "HORSEA" } },
  { max = 999, pool = { "STARYU", "SHELLDER", "SEADRA", "LAPRAS", "DRATINI" } },
}

-- Move roles the AI reasons about beyond raw damage, keyed by the move's
-- effect id from the merged moves registry (src/battle/MoveEffects.lua),
-- so retyped or brand-new mod moves classify themselves. Effectiveness
-- itself reads the merged type chart at battle time.
local SETUP_EFFECTS = {
  ATTACK_UP2_EFFECT = true, DEFENSE_UP2_EFFECT = true,
  SPEED_UP2_EFFECT = true, SPECIAL_UP2_EFFECT = true,
  REFLECT_EFFECT = true, LIGHT_SCREEN_EFFECT = true,
}
-- SPECIAL_DAMAGE_EFFECT moves score by the damage they actually deal
-- (their registry power would bury them); ids not listed here deal
-- level-worth damage (Seismic Toss, Night Shade, Psywave).
local FIXED_AMOUNTS = { DRAGON_RAGE = 40, SONICBOOM = 20 }

local function bumpedLevel(level)
  local out = level + LEVEL_BONUS
  if out > LEVEL_CAP then out = LEVEL_CAP end
  return out
end

local function copyMember(member)
  local copy = {}
  for k, v in pairs(member) do copy[k] = v end
  return copy
end

-- Deterministic per-trainer offset so different rosters of the same class
-- pick different benches, without randomness that would break replays.
local function hashId(id)
  local h = 0
  for i = 1, #id do h = (h * 31 + id:byte(i)) % 16777216 end
  return h
end

local function themeFor(id)
  local key = tostring(id):upper()
  key = key:gsub("^OPP_", "")
  key = key:gsub("%d+$", "")
  return CLASS_THEMES[key] or GENERIC_THEME
end

-- The rival's single-Pokemon rosters are the Oak's-lab battles (pokered
-- parties.asm: RIVAL1 parties 1-3, one starter each; Yellow's lone Eevee).
-- They stay completely vanilla: six Pokemon in Oak's lab makes no sense.
local function isFirstRivalBattle(id, party)
  return #party == 1 and tostring(id):upper():find("RIVAL", 1, true) ~= nil
end

return function(mod)
  local trainers = mod.content.trainers
  if not trainers then
    mod.log:warn("trainers registry unavailable on this engine; "
      .. "kaizo changes skipped -- update the engine or lower manifest api")
    return
  end

  -- Resolve each set's move names against the merged moves registry once,
  -- so a bad id is a single load-time warning instead of a battle crash.
  local moves = mod.content.moves
  local resolvedSets, dropped = {}, {}
  for species, set in pairs(KAIZO_SETS) do
    local resolved = {}
    for _, name in ipairs(set) do
      local found
      for _, candidate in ipairs(MOVE_ALIASES[name] or { name }) do
        if moves and moves:get(candidate) then found = candidate; break end
      end
      if found then
        resolved[#resolved + 1] = found
      elseif not dropped[name] then
        dropped[name] = true
        mod.log:warn("move %s not in the moves registry; dropped from kaizo "
          .. "sets -- check the id against the registry reference", name)
      end
    end
    if #resolved > 0 then resolvedSets[species] = resolved end
  end

  local pokemonReg = mod.content.pokemon
  local function inRegistry(sp)
    return sp ~= nil and pokemonReg ~= nil and pokemonReg:get(sp) ~= nil
  end

  -- -------------------------------------------------------------------
  -- 1. Trainer parties. A trainer record holds a `parties` LIST -- one
  --    roster per fight the class covers -- and party slots are schema-
  --    strict {level, species}, so this pass is levels + padding only;
  --    movesets ride the trainer.party hook below.
  -- -------------------------------------------------------------------
  local buffed, skippedRival = 0, 0
  for id, trainer in trainers:each() do
    local parties = trainer.parties
    if type(parties) == "table" and #parties > 0 then
      local theme = themeFor(id)
      local newParties, changed = {}, false
      for pi, party in ipairs(parties) do
        if type(party) ~= "table" or #party == 0 then
          newParties[pi] = party
        elseif isFirstRivalBattle(id, party) then
          newParties[pi] = party
          skippedRival = skippedRival + 1
        else
          changed = true

          -- Levels: a flat, static bump for every slot.
          local newParty, used, maxLevel = {}, {}, 0
          for i, slot in ipairs(party) do
            local level = slot.level
            if type(level) == "number" then
              level = bumpedLevel(level)
              if level > maxLevel then maxLevel = level end
            end
            newParty[i] = { level = level, species = slot.species }
            if slot.species then used[slot.species] = true end
          end

          -- Fill to six with varied species from the class's own bench,
          -- at levels just under the team's strongest, closed out by one
          -- surprise ace a notch above it.
          if #newParty < PARTY_SIZE and maxLevel > 0 then
            local pool = theme.pool
            local start = hashId(tostring(id) .. "#" .. pi) % #pool
            local offset = 0
            local benchLevel = math.max(2, maxLevel - 1)
            while #newParty < PARTY_SIZE - 1 and offset < #pool * 2 do
              local sp = pool[(start + offset) % #pool + 1]
              offset = offset + 1
              if inRegistry(sp) and (not used[sp] or offset > #pool) then
                used[sp] = true
                newParty[#newParty + 1] = { level = benchLevel, species = sp }
              end
            end

            if #newParty < PARTY_SIZE then
              local ace
              if inRegistry(theme.ace) and not used[theme.ace] then
                ace = theme.ace
              else
                for i = 1, #pool do
                  local sp = pool[(start + offset + i) % #pool + 1]
                  if inRegistry(sp) then ace = sp; break end
                end
              end
              if ace then
                newParty[#newParty + 1] =
                  { level = math.min(LEVEL_CAP, maxLevel + 1), species = ace }
              else
                mod.log:warn("no padding species for trainer %s exist in the "
                  .. "pokemon registry; roster %d left at %d -- check "
                  .. "CLASS_THEMES ids against the registry reference",
                  tostring(id), pi, #newParty)
              end
            end
          end
          newParties[pi] = newParty
        end
      end
      if changed then
        trainers:patch(id, { parties = newParties })
        buffed = buffed + 1
      end
    end
  end
  mod.log:info("kaizo: %d trainer classes buffed "
    .. "(%d first-rival rosters left vanilla)", buffed, skippedRival)

  -- -------------------------------------------------------------------
  -- 2. Competitive movesets, via the trainer.party hook: the battle
  --    builder honors a slot's own `moves` list over the legacy boss-
  --    move tables (BattleState.newTrainer), and the hook is the seam
  --    that carries it past the schema-strict registry slots. Sets are
  --    level-gated so endgame TMs never show up on early-route teams,
  --    and a slot that already carries moves (another mod's) is kept.
  -- -------------------------------------------------------------------
  mod.hooks:wrap("trainer.party", function(nextParty, oppClass, partyIndex, party)
    local out = nextParty(oppClass, partyIndex, party) or party
    if type(out) ~= "table" then return out end
    local rewritten, any = {}, false
    for i, slot in ipairs(out) do
      local set = type(slot) == "table" and slot.moves == nil
        and resolvedSets[slot.species] or nil
      if set and (tonumber(slot.level) or 0) >= SET_MIN_LEVEL then
        local copy = copyMember(slot)
        local list = {}
        for k, mv in ipairs(set) do list[k] = mv end
        copy.moves = list
        rewritten[i] = copy
        any = true
      else
        rewritten[i] = slot
      end
    end
    if not any then return out end
    return rewritten
  end)

  -- -------------------------------------------------------------------
  -- 3. Competitive trainer AI. battle.enemy_action is the engine's
  --    whole-AI choke point (BattleState:enemyAction): vanilla picks
  --    first, then the move choice is rewritten when the battle reads
  --    cleanly. Item/switch turns ({special=...}), Struggle, and multi-
  --    turn locks (recharge/charge/thrash/Rage/trap/Bide) pass through
  --    untouched, so a schema drift degrades to vanilla AI, never a
  --    crash. The pick is returned as an entry from the enemy's own
  --    curMoves list -- the same shape TrainerAI.chooseMove returns --
  --    so PP accounting and Disable keep working.
  -- -------------------------------------------------------------------

  -- Gen 1 effectiveness from the merged type chart: each matchup row
  -- applies once, even when both defender types match it (TypeChart.rows),
  -- and rows carry x10 multipliers.
  local function effectiveness(data, moveType, defTypes)
    if not moveType or type(defTypes) ~= "table" then return 1 end
    local chart = data and data.type_chart
    local matchups = chart and chart.matchups
    if type(matchups) ~= "table" then return 1 end
    local mult = 1
    for _, row in ipairs(matchups) do
      if row.attacker == moveType
         and (row.defender == defTypes[1] or row.defender == defTypes[2]) then
        mult = mult * (row.multiplier / 10)
      end
    end
    return mult
  end

  mod.hooks:wrap("battle.enemy_action", function(nextAction, battle)
    local action = nextAction(battle)
    -- Only trainer battles get the sharper brain; wilds stay wild.
    if type(battle) ~= "table" or battle.kind ~= "trainer"
       or not battle.trainer then
      return action
    end
    -- Class item/switch turns and Struggle stay exactly as vanilla chose.
    if type(action) ~= "table" or action.special ~= nil
       or action.struggle or type(action.id) ~= "string" then
      return action
    end
    local e, p = battle.enemy, battle.player
    if not (e and p and e.mon and p.mon and type(e.curMoves) == "table") then
      return action
    end
    -- Locked into a multi-turn move: the vanilla pick is forced, keep it.
    if e.mustRecharge or e.charging or e.rageMove or e.bideTurns
       or (e.thrashTurns or 0) > 0 or (e.trappingTurns or 0) > 0 then
      return action
    end

    local data = battle.data
    local moveDefs = data and data.moves
    if type(moveDefs) ~= "table" then return action end
    -- Gen 1 AI never reads enemy PP unless the ruleset depletes it
    -- (TrainerAI.chooseMove); mirror that so a pick is always legal.
    local unlimited = battle.ruleset and battle.ruleset.enemyUnlimitedPP
    local myTypes, theirTypes = e.curTypes or {}, p.curTypes or {}
    local myMax = e.mon.stats and e.mon.stats.hp or 0
    local theirMax = p.mon.stats and p.mon.stats.hp or 0
    local myHp = myMax > 0 and (e.mon.hp or myMax) / myMax or 1
    local theirHp = theirMax > 0 and (p.mon.hp or theirMax) / theirMax or 1
    local theirStatused = p.mon.status ~= nil
    local myLevel = tonumber(e.mon.level) or 50

    -- Score every usable move: damage is power x effectiveness x STAB;
    -- status, healing, setup and Explosion get situational scores so the
    -- AI uses them in smart spots instead of at random. When nothing
    -- scores, vanilla's pick stands.
    local best, bestScore
    for i, mv in ipairs(e.curMoves) do
      if e.disabledSlot ~= i and (unlimited or (mv.pp or 0) > 0) then
        local def = moveDefs[mv.id]
        if def then
          local score = 0
          local eff = effectiveness(data, def.type, theirTypes)
          local effect = def.effect
          if effect == "EXPLODE_EFFECT" then
            -- save the nuke until this mon is nearly done for
            score = (myHp <= 0.34 and eff > 0)
              and (def.power or 170) * eff or 5
          elseif effect == "SPECIAL_DAMAGE_EFFECT" then
            -- fixed damage: score what it actually deals; RBY still
            -- applies type immunity to it
            if eff > 0 then
              score = FIXED_AMOUNTS[mv.id] or myLevel
              if theirHp <= 0.25 then score = score * 1.5 end
            end
          elseif effect == "OHKO_EFFECT" then
            score = 8 -- fails against faster foes in Gen 1; rarely right
          elseif (def.power or 0) > 0 then
            if eff > 0 then
              local stab = 1
              for _, t in ipairs(myTypes) do
                if t == def.type then stab = 1.5; break end
              end
              score = def.power * eff * stab
              -- finishing pressure: prefer the kill when the player is low
              if theirHp <= 0.25 then score = score * 1.5 end
            end
          elseif effect == "SLEEP_EFFECT" then
            score = (not theirStatused) and 140 or 0
          elseif effect == "PARALYZE_EFFECT" then
            -- Thunder Wave respects type immunity in Gen 1
            score = (not theirStatused and eff > 0) and 100 or 0
          elseif effect == "HEAL_EFFECT" then
            score = (myHp <= 0.4) and 160 or 0
          elseif SETUP_EFFECTS[effect] then
            -- set up on a statused target or while comfortably healthy
            score = (myHp >= 0.75 and theirStatused) and 90
              or (myHp >= 0.9 and 55) or 0
          else
            score = 20 -- unknown utility move: usable, rarely optimal
          end
          if score > 0 and (not bestScore or score > bestScore) then
            best, bestScore = mv, score
          end
        end
      end
    end
    return best or action
  end)
  mod.log:info("kaizo: competitive trainer AI armed (battle.enemy_action)")

  -- -------------------------------------------------------------------
  -- 4. Wild encounters: variety keeps pace with difficulty. An area
  --    record carries `grass` and `water` zones of {rate, slots}; every
  --    slot gets a small static level bump, and each zone's rare tail
  --    slots are replaced with fresh species from the tier pool matching
  --    the zone's strength, so the player can build a team that answers
  --    the buffed trainers. Encounter rates are left untouched.
  -- -------------------------------------------------------------------
  local encounters = mod.content.encounters
  if not encounters then
    mod.log:warn("encounters registry unavailable on this engine; "
      .. "wild variety pass skipped -- update the engine or lower manifest api")
    return
  end

  local areas, freshened = 0, 0
  for id, area in encounters:each() do
    local patchArea = {}
    local touched = false
    for _, zoneName in ipairs({ "grass", "water" }) do
      local zone = area[zoneName]
      if type(zone) == "table" and type(zone.slots) == "table" and #zone.slots > 0 then
        -- Copy every slot, bumping its level; note what already lives here.
        local newSlots, present, maxLevel = {}, {}, 0
        for i, slot in ipairs(zone.slots) do
          local level = slot.level
          if type(level) == "number" then
            level = math.min(LEVEL_CAP, level + WILD_LEVEL_BONUS)
            if level > maxLevel then maxLevel = level end
          end
          newSlots[i] = { level = level, species = slot.species }
          if slot.species then present[slot.species] = true end
        end

        -- Swap the rare tail slots for fresh species. Common slots keep
        -- the area's identity; the rares become the reason to explore.
        if maxLevel > 0 then
          local tiers = zoneName == "water" and WATER_TIERS or LAND_TIERS
          local pool
          for _, tier in ipairs(tiers) do
            if maxLevel <= tier.max then pool = tier.pool; break end
          end
          local replaceCount = #newSlots >= 6 and RARE_SLOT_COUNT or 1
          local slotIndex = #newSlots - replaceCount + 1
          local start, offset = hashId(tostring(id) .. zoneName) % #pool, 0
          while slotIndex <= #newSlots and offset < #pool do
            local sp = pool[(start + offset) % #pool + 1]
            offset = offset + 1
            if not present[sp] and inRegistry(sp) then
              newSlots[slotIndex] = { level = newSlots[slotIndex].level, species = sp }
              present[sp] = true
              freshened = freshened + 1
              slotIndex = slotIndex + 1
            end
          end
        end

        patchArea[zoneName] = { slots = newSlots }
        touched = true
      end
    end
    if touched then
      encounters:patch(id, patchArea)
      areas = areas + 1
    end
  end
  mod.log:info("kaizo: refreshed %d encounter areas (%d rare slots now carry "
    .. "new species)", areas, freshened)
end

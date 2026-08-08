# Changelog

All notable changes to this mod are documented here. Format follows
[Keep a Changelog](https://keepachangelog.com/), versions follow semver.

## 0.8.0 - 2026-08-08

### Added

- An **ALLGEN KAIZO** entry in the in-game OPTIONS screen with the mod's
  first option: **BATTLE: STATIC / SCALING**. Static (the default) keeps
  trainer levels exactly as authored (+3 kaizo bump). Scaling makes every
  trainer roster track the player's strongest Pokémon: each slot maps by
  rank into the 90%-110% band -- the trainer's weakest at 90% of your
  best, their ace at 110% -- recomputed live at battle start. The choice
  persists in the options file (not per save) and also renders in the mod
  manager's per-mod options screen. The Oak's-lab rival fight stays
  vanilla in both modes.

## 0.7.3 - 2026-08-08

### Changed

- Early-route monotony fixed: every encounter zone now offers **ten
  distinct species**. Vanilla tables repeat two or three species across
  the whole table (Route 1 is Pidgey/Rattata in all ten slots); now a
  species keeps only its FIRST -- most common -- slot, and every repeat
  becomes a fresh, level-appropriate pick from the zone's strength band,
  mixing all generations. Slot odds are positional, so the route's
  headline encounters stay exactly as common as vanilla, levels are
  preserved per slot, and picks hash per map so neighboring routes
  diverge. Rare-tail swaps and legendary dens are unchanged.

## 0.7.2 - 2026-08-08

### Changed

- Public naming finished: the GitHub repo is now
  `AyeBathingApe/gen1recomp-allgen-kaizo` (old links redirect), releases
  are titled "Gen1 Recomp Allgen Kaizo X.Y.Z", and the download is
  `gen1-recomp-allgen-kaizo-<version>.zip`. The mod id stays `gen1_kaizo`
  so installs, saves, and launcher auto-updates keep working (the updater
  falls back to the release's zip when the id-named asset is absent).

## 0.7.1 - 2026-08-08

### Changed

- Project renamed to **Gen1 Recomp Allgen Kaizo**. README rewritten:
  fuller synopsis, all features in bullet form, a competitive Battle
  Tower on the roadmap, and a development section crediting the Pokemon
  RBGenesis fangame (data and art) and the Gen1Recomp project (engine
  and mod system). mod.card refreshed to match the current feature set.

## 0.7.0 - 2026-08-08

### Added

- Mega evolution, Gen 1 style: 43 mega forms from RBGenesis
  (pokemonforms.txt) register as standalone species with their mega
  stats, types, art, and dex entries (dex 866+). They never appear in
  wild encounters, legendary dens, or regular trainer benches.
- The MEGA STONE: a one-per-save item found after defeating Giovanni at
  Silph Co. (his "You ruined our plans!" speech hands it over). With the
  stone in the bag, a mon with a mega form gains a MEGA option in the
  party submenu; species with two megas (Charizard, Mewtwo's stand-ins
  X/Y) ask which form first. Using it consumes the stone and runs the
  engine's forced stone-evolution sequence -- permanent, dex-marked, and
  learnset-aware. Backing out of the X/Y menu keeps the stone.
- Surprise megas on late bosses: Sabrina, Lorelei, Agatha, Lance, the
  champion rival, and gym-fight Giovanni each field exactly one mega --
  preferring a mon of theirs that naturally has one (Agatha's Gengar,
  Lance's Gyarados), falling back to a deterministic pick for the slot
  beside the ace.

### Notes

- Mega Mewtwo X/Y, Mega Tyranitar, and Mega Gallade are skipped: the fan
  pack ships no battler art for them.

## 0.6.0 - 2026-08-08

### Changed

- The original 151 now use the RBGenesis fan-made battler art too (front
  and back, full color), so the whole dex shares one aesthetic instead of
  mixing vanilla Game Boy art with the imported style. The art was
  already in the data pack -- the mod now patches it onto the vanilla
  records alongside the Genesis balance. Disabling the mod still restores
  vanilla art exactly.

## 0.5.0 - 2026-08-07

### Fixed

- Genesis battler sprites drew at their modern source size (112px fronts,
  96px backs) and dwarfed the vanilla art on the dex page, in battle, and
  everywhere else that draws pics natively. The converter now crops each
  battler to its opaque content and fits it to Gen 1 dimensions on disk
  (fronts <=56px for the 7x7-tile buffer at 1x, backs <=32px for the
  battle's 2x draw), nearest-neighbor so the pixel art stays crisp. The
  per-species battle-scale hints are gone -- native sizes are now right
  at the engine's default scales.
- Dex entries for new species showed "Data unknown.": `dexEntry.text` is
  an id looked up in the text registry, not raw prose. The converter now
  wraps each Pokedex entry to the page's 18x6 line budget and emits a
  gen/text.lua pack the mod registers at load.
- Dex height/weight now print in the vanilla imperial style (HT/WT); the
  weight field previously stored pounds where the page expects tenths of
  a pound, so it would have printed at a tenth of the real value.

## 0.4.2 - 2026-08-07

### Fixed

- Load failure on real game data (`pokemon already registered: BULBASAUR`):
  vanilla species whose engine id matches the PBS spelling -- nearly all
  151 -- were misclassified as new and re-registered, which the registry
  rejects against base data. Detection now probes the registry directly,
  so vanilla species are patched in place (Genesis balance, vanilla art)
  on every engine build. The dev fixture dataset has no Kanto species, so
  the suite never hit the path; a seeded-base-species regression test now
  covers it.

## 0.4.1 - 2026-08-06

### Changed

- README rewritten for the Genesis feature set: the ported roster (dex,
  types, moves, evolutions), starter generations, legendary dens, release
  install instructions, and data-pack regeneration steps.

## 0.4.0 - 2026-08-06

### Added

- Starter generations: touching the first ball in Oak's lab opens a menu
  asking which region's trio (Kanto through Alola; Galar's trio lacks
  battler art) fills the three balls. Each ball keeps its element --
  grass in Bulbasaur's ball, fire in Charmander's, water in Squirtle's --
  so the rival still counter-picks the Gen 1 elemental answer to your
  choice and his rosters stay coherent for the whole run. The pick is
  remembered per save file.
- Legendary dens: legendaries and mythicals (standalone species with
  legendary catch rates or plainly overpowered stat totals -- 57 of them)
  are pulled out of the wild tiers and trainer benches and instead haunt
  one rare slot in each late-game grass zone (zone strength 25+), hashed
  per map, sitting 7 levels above the local ceiling with their real
  (brutal) catch rates. Mewtwo, the birds, and Mew keep their vanilla
  static encounters.

### Fixed

- The Pokedex now pages through the entire Genesis dex: `dexSize` is
  widened to the highest registered dex number (865) instead of stopping
  at 151.
- Wild tier bands rebalanced for folded stat totals (Special = averaged
  SpA/SpD); the top band previously held only 10 species, starving
  late-game zones of variety.
- Trainer bench strength cap clamped so very high-level benches can't
  reach past the wild-tier ceiling.

## 0.3.0 - 2026-08-06

### Added

- Genesis integration: wild rare slots and trainer benches now draw from
  the full Genesis dex. Each zone's rare tail (now 4 slots) mixes the
  classic tier pools with every newcomer in the zone's strength band,
  hashed per map so the new species spread across the whole region; each
  trainer's bench offers up to 3 type-matched Genesis species capped by
  bench level, so classes keep their flavor while fielding the new dex.
- Move effect inference: each Essentials function code is matched against
  the vanilla moves the engine already carries (by damage shape and
  proc-chance bucket), and new moves inherit the winning effect -- Spore
  sleeps like Sleep Powder, Dark Pulse flinches like Bite, and multi-hit/
  fixed-damage/semi-invulnerable shapes travel with it. Roughly 240 of
  594 new moves gain real Gen 1 effects; the rest are Gen 2+ mechanics
  with no Gen 1 equivalent and stay plain damage.
- Evolution mapping: stone evolutions map to the five Gen 1 stones
  (nearest-stone approximations for newer stones), conditional level-ups
  keep their level, and happiness/held-item/location methods become
  fixed level-ups (30/38/32) so every chain stays completable. Only
  Nincada's Shedinja split remains unported. Stone rows fall back to
  level-ups on engines whose items registry lacks the stone.

### Fixed

- Trainer padding and wild swaps now recognize the expanded registry, so
  parties reliably reach six and rare slots always find a fresh species.

## 0.2.0 - 2026-08-06

### Added

- Genesis roster: the mod becomes Gen 1 Kaizo Genesis. A generated
  RBGenesis data pack (gen/, produced by tools/pbs_convert.py from
  Pokemon Essentials PBS data, with fan-made battler art) registers the
  modern type chart (DARK,
  STEEL, FAIRY, SHADOW plus 61 updated matchup rows), 759 moves, and an
  expanded dex of 800+ species with SpA/SpD folded into the Gen 1
  special stat. Vanilla species and moves keep their engine ids: moves
  alias by name and keep vanilla battle effects; vanilla species are
  patched in place with Genesis stats, types, and learnsets while
  keeping vanilla art. Without the data pack the mod degrades cleanly
  to classic kaizo.
- tools/pbs_convert.py: PBS-to-registry converter (slicing, sprite
  probing/copying, special-fold strategies) and tools/check_gen.lua:
  output validation against the engine's real registry schemas.

### Known gaps (next phases)

- New moves carry placeholder effects (plain damage); status/secondary
  effects land with the effect-mapping phase.
- New species are registered but not yet woven into encounter pools or
  trainer themes; item/happiness/trade-item evolutions deferred.

## 0.1.0 - 2026-08-05

### Added

- Trainer levels raised by a flat, static +3 (capped at 100), applied to
  every roster in each trainer class's parties list.
- Trainer parties padded to 6 with varied species themed to the trainer's
  class, closed by one surprise ace one level above the old strongest.
- Competitive RBY movesets for ~55 species, carried by the trainer.party
  hook (registry party slots are schema-strict) and gated to level 25+ so
  endgame TM sets never appear on early-route trainers.
- The first rival battle is exempt and stays vanilla (one starter).
- Each encounter zone's rare slots (grass and water) replaced with fresh
  progression-tier species, never duplicating the zone's natives.
- Wild levels raised by a flat, static +2 (capped at 100).
- Competitive trainer AI via the battle.enemy_action hook: merged-type-chart
  damage scoring with STAB, immunity avoidance, effect-classified move
  roles (fixed damage scored by real damage, status spreading, low-HP
  healing, situational setup, Explosion held until near-KO), with vanilla
  fallback for item/switch turns and multi-turn locks.

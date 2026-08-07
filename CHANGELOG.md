# Changelog

All notable changes to this mod are documented here. Format follows
[Keep a Changelog](https://keepachangelog.com/), versions follow semver.

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

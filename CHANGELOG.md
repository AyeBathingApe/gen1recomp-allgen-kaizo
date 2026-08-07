# Changelog

All notable changes to this mod are documented here. Format follows
[Keep a Changelog](https://keepachangelog.com/), versions follow semver.

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

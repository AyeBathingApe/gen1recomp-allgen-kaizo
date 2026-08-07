# Gen 1 Kaizo Genesis

A kaizo-style overhaul for [Gen1Recomp](https://github.com/bryanthaboi/gen1recomp) on a dramatically expanded dex: every trainer fields a themed party of six with competitive movesets and an AI that exploits your weaknesses, wild encounters widen with 800+ ported RBGenesis species (modern types, moves, and evolutions included), legendaries hide in late-game dens — and Oak now asks which region's starter trio you want in the three balls.

Try it:

```sh
# from your gen1recomp checkout, with this folder copied to mods/gen1_kaizo
python3 tools/modkit.py validate mods/gen1_kaizo --base imported
python3 tools/modkit.py lint mods/gen1_kaizo
love .
```

## Install (players)

1. Grab `gen1_kaizo-<version>.zip` from the [latest release](https://github.com/AyeBathingApe/gen1recomp-kaizo/releases/latest) (or copy this folder) into the game's `mods/` directory as `gen1_kaizo`.
2. Launch the game and press **F10** (or Options → mod manager) to confirm it is enabled.
3. Disabling the mod in the manager restores vanilla exactly. The manifest's `github` field lets the launcher offer updates automatically.

## What it changes

### The Genesis roster

| Area | Change |
|---|---|
| Dex | **832 new species** ported from Pokémon RBGenesis register alongside the vanilla 151 — the Pokédex pages through all 865 dex entries, with fan-made battler art for every newcomer |
| Types & moves | The modern type chart (Dark, Steel, Fairy, and a split Psychic) and **759 ported moves**; new moves inherit battle effects inferred from the vanilla moves that share their Essentials function code (Spore sleeps like Sleep Powder, Dark Pulse flinches like Bite) |
| Stats | Modern SpA/SpD are folded into Gen 1's single Special (averaged), so every newcomer fits the engine's battle math |
| Evolutions | Full chains ported: level-ups as-is, the five Gen 1 stones mapped directly, modern methods approximated (happiness → level 30, trades → trade, newer stones → the closest Gen 1 stone) so every line is completable |
| Starters | At the first ball in Oak's lab, a menu asks **which region's trio (Kanto–Alola) fills the three balls**. Each ball keeps its element — grass in Bulbasaur's ball, fire in Charmander's, water in Squirtle's — so the rival still counter-picks the Gen 1 starter that beats yours and his campaign roster stays coherent |
| Legendary dens | Legendaries and mythicals (57 of them) never appear in regular pools or on trainers; instead each late-game zone hides **one** in its rarest grass slot, 7 levels above the local ceiling, with its real (brutal) catch rate. Mewtwo, the birds, and Mew keep their vanilla static encounters |

### The kaizo layer

| Area | Change |
|---|---|
| Levels | A flat, static **+3** on every trainer Pokémon — no scaling, a challenge, not a wall |
| Party size | Padded to 6 with **varied species themed to the trainer's class** (Bug Catchers bring bugs, Hikers bring rock/ground, gym leaders pad within their type), drawing type-matched Genesis newcomers capped to the bench's strength |
| Ace | Each padded party closes with one surprise ace (Bug Catcher → Scyther, Fisherman → Gyarados, Lance → second Dragonite…) one level above the team's old strongest |
| Movesets | ~55 species get a classic RBY competitive set (Tauros: Body Slam / Hyper Beam / Earthquake / Blizzard, Chansey: Ice Beam / Thunderbolt / Thunder Wave / Soft-Boiled, ...) — **only from level 25 up**, so endgame TM sets never appear on early-route trainers; Genesis bench species carry their natural learnset moves |
| Trainer AI | Wraps the engine's `battle.enemy_action` hook: picks the strongest move by **type effectiveness × STAB**, never clicks into an immunity, scores fixed-damage moves (Seismic Toss, Night Shade) by what they actually deal, spreads sleep/paralysis onto healthy targets, heals below 40% HP, sets up (Amnesia / Swords Dance / Agility) when safe, and saves Explosion for when it's nearly down. Prefers the finisher when you're low |
| First rival battle | **Left completely vanilla** — one starter in Oak's lab, as it should be |
| Wild variety | Each zone's four rare slots are replaced with fresh species mixing the classic progression tiers (Abra / Growlithe early, Dratini / Lapras late) with every Genesis newcomer in the zone's strength band, hashed per map so the new dex spreads across the whole region |
| Wild levels | A flat, static **+2** so fresh catches are viable against buffed trainers |

Items and the economy are untouched. Bench picks, rare-slot picks, and den
legendaries are deterministic per trainer and per area, so two Youngsters on
the same route still field different teams and every area keeps a stable,
plannable pool. The AI only rewrites *move choice* in trainer battles —
switching, item use, and wild Pokémon behavior stay vanilla, and any battle
state the mod cannot read confidently falls back to the vanilla decision.

Vanilla species are rebalanced with `patch` over the merged registry view
and new content registers additively, so other mods editing the same records
keep their own fields. The mod wraps three engine seams: `trainer.party`
carries the curated movesets and Genesis benches (registry party slots are
schema-strict `{level, species}`, but the battle builder honors a `moves`
list on hook-returned slots), `battle.enemy_action` carries the competitive
AI, and `script.command` carries the starter generation menu (armed only
between following Oak into the lab and taking a starter; everything else
passes through untouched). The Genesis data pack in [gen/](gen/) is
generated from RBGenesis PBS text by
[tools/pbs_convert.py](tools/pbs_convert.py) — fan-made data and art, no
ROM-derived bytes.

Tuning knobs, the per-class padding pools, the wild-encounter tier pools,
the starter-generation table, and the moveset table live at the top of
[main.lua](main.lua).

## Roadmap

- Per-player difficulty options via `options_schema`
- Curated competitive sets for standout Genesis species
- Galar starters once battler art exists for the trio

## Development

- Docs: the [modding wiki](https://github.com/bryanthaboi/gen1recomp/wiki) — start with Concepts → Registries, then the Cookbook.
- Contribution rules and polish checklist: `CONTRIBUTING-mods.md` in the engine repo.
- Tests in `tests/` load the mod through the headless loader against the
  engine's fixture dataset; run from the engine repo root with the mod
  copied to `mods/gen1_kaizo` (`luajit mods/gen1_kaizo/tests/test_kaizo.lua`,
  or the whole T4 tier via `luajit tests/run_modkit.lua`, which discovers
  every `mods/<id>/tests` directory). `.modkitignore` keeps them out of the
  packed archive.
- Regenerate the Genesis data pack with
  `python3 mods/gen1_kaizo/tools/pbs_convert.py --pbs <RBGenesis PBS dir> --out mods/gen1_kaizo/gen --battlers <Battlers dir> --copy-sprites`,
  then check it with `luajit mods/gen1_kaizo/tools/check_gen.lua mods/gen1_kaizo/gen`.
- Package for distribution with `python3 tools/modkit.py pack mods/gen1_kaizo`.

> Note: only the GitHub repo and the project Discord are official sources for
> Gen1Recomp. The site `gen1recomp.com` is disavowed by the maintainers — do not
> download mods or builds from it.

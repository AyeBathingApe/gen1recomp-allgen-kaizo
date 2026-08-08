# Gen1 Recomp Allgen Kaizo

What if Pokémon Red never stopped growing? **Gen1 Recomp Allgen Kaizo** rebuilds the original Kanto campaign into a brutal, modern monster-collector without ever leaving the Game Boy: nine hundred–odd species spanning every generation live inside Gen 1's engine, battles run on the modern type chart, and the whole region fights back. Pick your starter trio from any region in Oak's lab, chase legendaries hiding in endgame dens, claim the one Mega Stone from Giovanni's fall at Silph Co. — and survive trainers who field full parties of six, run real competitive movesets, and think before they click. Hard, fair, deterministic, and fully uninstallable: turn the mod off and vanilla Red is exactly where you left it.

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

## Features

### The all-gen roster

- **832 new species** from Pokémon RBGenesis join the original 151 — the Pokédex pages through all 908 entries with kind, height/weight, and real flavor text
- **One aesthetic**: the classic 151 wear the same fan-made battler art as the newcomers, front and back, fitted to Gen 1 sprite dimensions
- **Modern type chart** — Dark, Steel, Fairy, and the physical/special Psychic split — merged into Gen 1 battle math
- **759 ported moves**; new moves inherit battle effects inferred from vanilla moves sharing their Essentials function code (Spore sleeps like Sleep Powder, Dark Pulse flinches like Bite)
- Modern SpA/SpD **folded into Gen 1's single Special stat**, so every newcomer plays by the engine's rules
- **Complete evolution chains**: level-ups as-is, the five Gen 1 stones mapped directly, modern methods approximated (happiness → level 30, trades → trade, newer stones → the closest Gen 1 stone)

### Choose your legend

- **Region-select starters**: the first ball in Oak's lab opens a menu — Kanto through Alola — and the chosen trio fills the three balls element-for-element, so the rival still counter-picks the Gen 1 starter that beats yours
- **Legendary dens**: 57 legendaries and mythicals never spawn in regular pools; each late-game zone hides exactly one in its rarest slot, 7 levels overleveled, at its true (brutal) catch rate
- **Mega evolution, Gen 1 style**: 43 mega forms as permanent stone evolutions. Beat Giovanni at Silph Co. for the save's single **MEGA STONE**, then use the party menu's MEGA option — dual-mega species ask **Mega X or Mega Y** first

### The kaizo layer

- Every trainer Pokémon at a flat, static **+3 levels** — no scaling, a challenge, not a wall
- Parties padded to **six themed species** per class (Bug Catchers bring bugs, Hikers bring rock/ground, gym leaders pad in-type), drawing all-gen newcomers capped to bench strength
- Every padded party closes with a **surprise ace** one level above the team's old strongest
- **~55 classic RBY competitive movesets** on trainer teams, gated to level 25+ so endgame TM sets never appear on early routes
- **Competitive trainer AI**: strongest move by type effectiveness × STAB, never into an immunity, real math on fixed-damage moves, status onto healthy targets, heals under 40%, sets up when safe, saves Explosion for the end
- **Surprise boss megas**: Sabrina, Lorelei, Agatha, Lance, the champion rival, and gym-fight Giovanni each field exactly one mega-evolved Pokémon
- **Wild pools that keep pace**: each zone's four rare slots mix classic progression tiers with every newcomer in the zone's strength band, hashed per map; wild levels at a flat **+2** so fresh catches stay viable
- The **first rival battle stays completely vanilla** — one starter in Oak's lab, as it should be
- Items and the economy untouched; every bench pick, rare slot, and den is **deterministic**, so runs are plannable and routes stay distinct

Items and the economy are untouched. Bench picks, rare-slot picks, and den
legendaries are deterministic per trainer and per area, so two Youngsters on
the same route still field different teams and every area keeps a stable,
plannable pool. The AI only rewrites *move choice* in trainer battles —
switching, item use, and wild Pokémon behavior stay vanilla, and any battle
state the mod cannot read confidently falls back to the vanilla decision.

Vanilla species are rebalanced with `patch` over the merged registry view
and new content registers additively, so other mods editing the same records
keep their own fields. The mod wraps four engine seams: `trainer.party`
carries the curated movesets, all-gen benches, and boss megas,
`battle.enemy_action` carries the competitive AI, `script.command` carries
the starter generation menu and the Mega Stone gift, and `ui.party.submenu`
carries the MEGA option. The data pack in [gen/](gen/) is generated from
RBGenesis PBS text by [tools/pbs_convert.py](tools/pbs_convert.py) —
fan-made data and art, no ROM-derived bytes.

Tuning knobs, the per-class padding pools, the wild-encounter tier pools,
the starter-generation table, the boss-mega list, and the moveset table
live at the top of [main.lua](main.lua).

## Roadmap

- **Competitive Battle Tower**: a post-game gauntlet of streak-based fights
  against generated trainers running full competitive movesets on the
  all-gen roster — level-capped tiers (50 / 70 / open), rental-draft and
  bring-your-own rules, escalating AI aggression per streak, boss trainers
  with megas and legendaries at milestone floors, and streak records kept
  on the save file
- Per-player difficulty options via `options_schema`
- Curated competitive sets for standout all-gen species
- Galar starters once battler art exists for the trio
- Party-menu icons themed to match the fan art

## Development

This project stands on two other projects:

- **[Gen1Recomp](https://github.com/bryanthaboi/gen1recomp)** — the engine.
  A faithful Lua/LÖVE reimplementation of Pokémon Red/Blue whose mod system
  (data registries, runtime hooks, sanctioned UI surface) makes an overhaul
  of this size possible without touching a byte of ROM. Development against
  its registries, hook seams, and modkit tooling shaped every feature here.
- **Pokémon RBGenesis** — the fangame whose PBS data and fan-made battler
  art supply the entire expanded roster: species, stats, learnsets,
  evolutions, mega forms, Pokédex text, and every sprite for the 908-entry
  dex. All of it is fan-created content; nothing is ripped from official
  games.

Workflow:

- Docs: the [modding wiki](https://github.com/bryanthaboi/gen1recomp/wiki) — start with Concepts → Registries, then the Cookbook.
- Contribution rules and polish checklist: `CONTRIBUTING-mods.md` in the engine repo.
- Tests in `tests/` load the mod through the headless loader against the
  engine's fixture dataset; run from the engine repo root with the mod
  copied to `mods/gen1_kaizo` (`luajit mods/gen1_kaizo/tests/test_kaizo.lua`,
  or the whole T4 tier via `luajit tests/run_modkit.lua`, which discovers
  every `mods/<id>/tests` directory). `.modkitignore` keeps them out of the
  packed archive.
- Regenerate the data pack with
  `python3 mods/gen1_kaizo/tools/pbs_convert.py --pbs <RBGenesis PBS dir> --out mods/gen1_kaizo/gen --battlers <Battlers dir> --copy-sprites`,
  then check it with `luajit mods/gen1_kaizo/tools/check_gen.lua mods/gen1_kaizo/gen`.
- Package for distribution with `python3 tools/modkit.py pack mods/gen1_kaizo`.

> Note: only the GitHub repo and the project Discord are official sources for
> Gen1Recomp. The site `gen1recomp.com` is disavowed by the maintainers — do not
> download mods or builds from it.

#!/usr/bin/env python3
"""PBS -> Gen1Recomp registry converter.

Parses Pokemon Essentials PBS plain-text data (types.txt, moves.txt,
pokemon.txt) and emits generated Lua data modules shaped exactly like the
engine's registry schemas (src/mods/Schemas.lua):

  gen/types.lua    new type records + type-chart diff vs the Gen 1 chart
  gen/moves.lua    move records (effect mapping deferred where unknown)
  gen/species.lua  pokemon records (SpA/SpD folded into Gen 1 `special`)
  gen/REPORT.txt   every approximation, drop, and deferred mapping

Usage:
  py tools/pbs_convert.py --pbs "<PBS dir>" [--out gen] [--dex 1-24]
     [--special-fold avg|max|spatk] [--battlers "<Graphics\\Battlers dir>"]

Validate the output against the real engine schemas with
tools/check_gen.lua (run under luajit from the engine repo root).
"""

import argparse
import csv
import io
import os
import re
import shutil
import struct
import sys
from collections import OrderedDict

# ---------------------------------------------------------------- constants

GEN1_TYPES = [
    "NORMAL", "FIGHTING", "FLYING", "POISON", "GROUND", "ROCK", "BUG",
    "GHOST", "FIRE", "WATER", "GRASS", "ELECTRIC", "PSYCHIC", "ICE", "DRAGON",
]

# canonical Gen 1 chart (pokered TypeEffects), x10 multipliers, used only to
# diff the PBS chart into patch/neutralize rows; PBS is authoritative
GEN1_CHART = {}
for _row in (
    "WATER>FIRE 20", "FIRE>GRASS 20", "FIRE>ICE 20", "GRASS>WATER 20",
    "ELECTRIC>WATER 20", "WATER>ROCK 20", "GROUND>FLYING 0",
    "WATER>WATER 5", "FIRE>FIRE 5", "ELECTRIC>ELECTRIC 5", "ICE>ICE 5",
    "GRASS>GRASS 5", "PSYCHIC>PSYCHIC 5", "FIRE>WATER 5", "GRASS>FIRE 5",
    "WATER>GRASS 5", "ELECTRIC>GRASS 5", "NORMAL>ROCK 5", "NORMAL>GHOST 0",
    "GHOST>GHOST 20", "FIRE>BUG 20", "FIRE>ROCK 5", "WATER>GROUND 20",
    "ELECTRIC>GROUND 0", "ELECTRIC>FLYING 20", "GRASS>GROUND 20",
    "GRASS>BUG 5", "GRASS>POISON 5", "GRASS>ROCK 20", "GRASS>FLYING 5",
    "ICE>WATER 5", "ICE>GRASS 20", "ICE>GROUND 20", "ICE>FLYING 20",
    "ICE>DRAGON 20", "FIGHTING>NORMAL 20", "FIGHTING>POISON 5",
    "FIGHTING>FLYING 5", "FIGHTING>PSYCHIC 5", "FIGHTING>BUG 5",
    "FIGHTING>ROCK 20", "FIGHTING>ICE 20", "FIGHTING>GHOST 0",
    "POISON>GRASS 20", "POISON>POISON 5", "POISON>GROUND 5",
    "POISON>BUG 20", "POISON>ROCK 5", "POISON>GHOST 5", "GROUND>FIRE 20",
    "GROUND>ELECTRIC 20", "GROUND>GRASS 5", "GROUND>BUG 5",
    "GROUND>ROCK 20", "GROUND>POISON 20", "FLYING>ELECTRIC 5",
    "FLYING>FIGHTING 20", "FLYING>BUG 20", "FLYING>GRASS 20",
    "FLYING>ROCK 5", "PSYCHIC>FIGHTING 20", "PSYCHIC>POISON 20",
    "BUG>FIRE 5", "BUG>GRASS 20", "BUG>FIGHTING 5", "BUG>FLYING 5",
    "BUG>PSYCHIC 20", "BUG>GHOST 5", "BUG>POISON 20", "ROCK>FIRE 20",
    "ROCK>FIGHTING 5", "ROCK>GROUND 5", "ROCK>FLYING 20", "ROCK>BUG 20",
    "ROCK>ICE 20", "GHOST>NORMAL 0", "GHOST>PSYCHIC 0", "FIRE>DRAGON 5",
    "WATER>DRAGON 5", "ELECTRIC>DRAGON 5", "GRASS>DRAGON 5",
    "DRAGON>DRAGON 20",
):
    _pair, _mult = _row.rsplit(" ", 1)
    GEN1_CHART[_pair] = int(_mult)

# under the pre-Gen-4 type-based split (the fallback when a move record
# carries no category); every ported move gets an explicit category anyway
SPECIAL_TYPES = {"FIRE", "WATER", "GRASS", "ELECTRIC", "PSYCHIC", "ICE",
                 "DRAGON", "DARK", "FAIRY"}

GROWTH_MAP = {
    "Medium": ("MEDIUM_FAST", None),
    "MediumFast": ("MEDIUM_FAST", None),
    "Parabolic": ("MEDIUM_SLOW", None),
    "MediumSlow": ("MEDIUM_SLOW", None),
    "Fast": ("FAST", None),
    "Slow": ("SLOW", None),
    "Erratic": ("SLIGHTLY_FAST", "no Erratic curve in engine"),
    "Fluctuating": ("SLIGHTLY_SLOW", "no Fluctuating curve in engine"),
}

# Essentials function code -> engine move_effects id, only where the mapping
# is certain; everything else defers to NO_ADDITIONAL_EFFECT and the report
FN_EFFECT_MAP = {
    "000": "NO_ADDITIONAL_EFFECT",
}

TILE = 8
FRONT_TARGET_PX = 56   # native Gen 1 front pic at 1x
BACK_TARGET_PX = 96    # native 48px back pic at the engine's default 2x
VANILLA_DEX_MAX = 151  # dex <= 151 patch the engine's own records at runtime

# ------------------------------------------------------------------ parsing


def read_text(path):
    with open(path, "r", encoding="utf-8-sig", errors="replace") as fh:
        return fh.read()


def parse_sections(path):
    """INI-style PBS file -> list of (section_header, OrderedDict)."""
    sections = []
    header, fields = None, None
    for raw in read_text(path).splitlines():
        if raw.lstrip().startswith("#"):
            continue
        line = raw.rstrip()
        if not line:
            continue
        m = re.match(r"^\[(.+)\]$", line)
        if m:
            header, fields = m.group(1), OrderedDict()
            sections.append((header, fields))
            continue
        if fields is None:
            continue
        if "=" in line:
            key, value = line.split("=", 1)
            fields[key.strip()] = value.strip()
    return sections


def parse_types(path):
    types = []
    for header, f in parse_sections(path):
        internal = f.get("InternalName", f.get("Name", header))
        types.append({
            "id": internal,
            "name": f.get("Name", internal).capitalize(),
            "special": f.get("IsSpecialType", "").lower() == "true"
                       or internal in SPECIAL_TYPES,
            "pseudo": f.get("IsPseudoType", "").lower() == "true",
            "weak": [t for t in f.get("Weaknesses", "").split(",") if t],
            "resist": [t for t in f.get("Resistances", "").split(",") if t],
            "immune": [t for t in f.get("Immunities", "").split(",") if t],
        })
    return types


def parse_moves(path):
    moves = []
    reader = csv.reader(io.StringIO(read_text(path)))
    for row in reader:
        if not row or row[0].lstrip().startswith("#"):
            continue
        if len(row) < 13:
            continue
        moves.append({
            "num": int(row[0]),
            "id": row[1].strip(),
            "name": row[2].strip(),
            "fn": row[3].strip().upper(),
            "power": int(row[4] or 0),
            "type": row[5].strip(),
            "class": row[6].strip(),           # Physical | Special | Status
            "accuracy": int(row[7] or 0),
            "pp": int(row[8] or 0),
            "effectChance": int(row[9] or 0),
            "target": row[10].strip(),
            "priority": int(row[11] or 0),
            "flags": row[12].strip(),
        })
    return moves


def parse_pokemon(path):
    species = []
    for header, f in parse_sections(path):
        try:
            dex = int(header)
        except ValueError:
            continue
        moves = []
        pairs = [p.strip() for p in f.get("Moves", "").split(",") if p.strip()]
        for lvl, mv in zip(pairs[0::2], pairs[1::2]):
            moves.append((int(lvl), mv))
        evolutions = []
        evo = [p.strip() for p in f.get("Evolutions", "").split(",") if p.strip()]
        for i in range(0, len(evo) - 1, 3):
            chunk = evo[i:i + 3]
            if len(chunk) == 3:
                evolutions.append(tuple(chunk))       # (species, method, param)
            elif len(chunk) == 2:
                evolutions.append((chunk[0], chunk[1], ""))
        stats = [int(s) for s in f.get("BaseStats", "0,0,0,0,0,0").split(",")]
        species.append({
            "dex": dex,
            "id": f.get("InternalName", f.get("Name", header)),
            "name": f.get("Name", ""),
            "types": [t for t in (f.get("Type1"), f.get("Type2")) if t],
            "stats": stats,                            # HP,Atk,Def,Spd,SpA,SpD
            "growth": f.get("GrowthRate", "Medium"),
            "baseExp": int(f.get("BaseEXP", 0)),
            "catchRate": int(f.get("Rareness", 45)),
            "moves": moves,
            "evolutions": evolutions,
            "kind": f.get("Kind", ""),
            "pokedex": f.get("Pokedex", ""),
            "heightM": float(f.get("Height", 0) or 0),
            "weightKg": float(f.get("Weight", 0) or 0),
        })
    return species


# --------------------------------------------------------------- conversion


def build_type_output(types, report):
    real = [t for t in types if not t["pseudo"]]
    real_ids = {t["id"] for t in real}
    for t in types:
        if t["pseudo"]:
            report.append("type %s: pseudo type skipped" % t["id"])

    new_types = [t for t in real if t["id"] not in GEN1_TYPES]

    desired = {}                                   # "ATT>DEF" -> x10
    for t in real:
        for att in t["weak"]:
            if att in real_ids:
                desired["%s>%s" % (att, t["id"])] = 20
        for att in t["resist"]:
            if att in real_ids:
                desired["%s>%s" % (att, t["id"])] = 5
        for att in t["immune"]:
            if att in real_ids:
                desired["%s>%s" % (att, t["id"])] = 0

    rows = []                                      # differs from Gen 1 chart
    for pair in sorted(set(desired) | set(GEN1_CHART)):
        want = desired.get(pair, 10)
        have = GEN1_CHART.get(pair, 10)
        if want != have:
            rows.append({"id": pair, "multiplier": want})
    report.append("type chart: %d rows differ from the Gen 1 chart "
                  "(%d total non-neutral in PBS)" % (len(rows), len(desired)))
    return new_types, rows


def build_move_output(moves, real_type_ids, report):
    out, meta = [], []
    deferred_fns = {}
    for mv in sorted(moves, key=lambda m: m["num"]):
        if mv["type"] not in real_type_ids:
            report.append("move %s: type %s not ported, move dropped"
                          % (mv["id"], mv["type"]))
            continue
        effect = FN_EFFECT_MAP.get(mv["fn"])
        if effect is None:
            effect = "NO_ADDITIONAL_EFFECT"
            deferred_fns.setdefault(mv["fn"], []).append(mv["id"])
        rec = OrderedDict()
        rec["id"] = mv["id"]
        rec["name"] = mv["name"]
        rec["type"] = mv["type"]
        rec["power"] = min(mv["power"], 255)
        rec["accuracy"] = max(0, min(mv["accuracy"], 100))
        rec["pp"] = min(mv["pp"], 64)
        rec["effect"] = effect
        rec["category"] = mv["class"].lower()
        if mv["priority"] != 0:
            rec["priority"] = max(-7, min(mv["priority"], 7))
        if "h" in mv["flags"]:
            rec["highCrit"] = True
        out.append(rec)
        meta.append(OrderedDict([("id", mv["id"]), ("fn", mv["fn"]),
                                 ("effectChance", mv["effectChance"]),
                                 ("target", mv["target"])]))
    report.append("moves: %d converted, %d distinct fn codes deferred to "
                  "NO_ADDITIONAL_EFFECT" % (len(out), len(deferred_fns)))
    for fn in sorted(deferred_fns):
        ids = deferred_fns[fn]
        report.append("  fn %s (%d moves): %s%s"
                      % (fn, len(ids), ", ".join(ids[:6]),
                         "..." if len(ids) > 6 else ""))
    return out, meta


def png_size(path):
    with open(path, "rb") as fh:
        head = fh.read(24)
    if len(head) < 24 or head[:8] != b"\x89PNG\r\n\x1a\n":
        return None
    w, h = struct.unpack(">II", head[16:24])
    return w, h


def sprite_fields(dex, battlers, report):
    fields = OrderedDict()
    fields["spriteFront"] = "gen/battlers/%03d.png" % dex
    fields["spriteBack"] = "gen/battlers/%03db.png" % dex
    fields["frontSize"] = 7
    if not battlers:
        return fields
    front = os.path.join(battlers, "%03d.png" % dex)
    back = os.path.join(battlers, "%03db.png" % dex)
    for path, key, target in ((front, "battleScaleFront", FRONT_TARGET_PX),
                              (back, "battleScaleBack", BACK_TARGET_PX)):
        if os.path.exists(path):
            size = png_size(path)
            if size:
                scale = max(0.25, min(4.0, target / max(size)))
                fields[key] = round(scale, 3)
        else:
            report.append("dex %03d: missing battler %s"
                          % (dex, os.path.basename(path)))
    fields["trueColor"] = True
    return fields


def dex_entry(sp):
    total_in = sp["heightM"] * 39.3701
    ft = int(total_in // 12)
    inch = int(round(total_in - ft * 12))
    if inch == 12:
        ft, inch = ft + 1, 0
    e = OrderedDict()
    e["kind"] = sp["kind"] or "???"
    e["heightFt"] = ft
    e["heightIn"] = inch
    e["weight"] = round(sp["weightKg"] * 2.20462, 1)
    e["heightM"] = sp["heightM"]
    e["weightKg"] = sp["weightKg"]
    e["text"] = sp["pokedex"] or "No data."
    return e


def fold_special(spa, spd, mode):
    if mode == "max":
        return max(spa, spd)
    if mode == "spatk":
        return spa
    return int(round((spa + spd) / 2.0))


def has_battlers(dex, battlers):
    return (os.path.exists(os.path.join(battlers, "%03d.png" % dex))
            and os.path.exists(os.path.join(battlers, "%03db.png" % dex)))


def build_species_output(species, move_ids, real_type_ids, opts, report):
    # pass 1: the kept set, so evolution refs only point at emitted records.
    # dex <= VANILLA_DEX_MAX always stays (patches the engine record, no art
    # needed); new species need both battler pics or the engine would crash
    # the first time one appears.
    kept, seen = [], set()
    for sp in sorted(species, key=lambda s: s["dex"]):
        if sp["id"] in seen:
            report.append("species %s: duplicate InternalName, kept first"
                          % sp["id"])
            continue
        seen.add(sp["id"])
        bad_types = [t for t in sp["types"] if t not in real_type_ids]
        if bad_types:
            report.append("species %s: unported type(s) %s, species dropped"
                          % (sp["id"], ",".join(bad_types)))
            continue
        if (opts.battlers and sp["dex"] > VANILLA_DEX_MAX
                and not has_battlers(sp["dex"], opts.battlers)):
            report.append("species %s (dex %d): battler art missing, "
                          "species dropped" % (sp["id"], sp["dex"]))
            continue
        kept.append(sp)
    wanted = {sp["id"] for sp in kept}

    out = []
    deferred_evos = []
    for sp in kept:
        hp, atk, dfn, spd, spa, spd2 = (sp["stats"] + [0] * 6)[:6]
        special = fold_special(spa, spd2, opts.special_fold)

        level1 = [mv for lvl, mv in sp["moves"] if lvl <= 1 and mv in move_ids]
        learn = [(lvl, mv) for lvl, mv in sp["moves"]
                 if lvl > 1 and mv in move_ids]
        dropped = [mv for _, mv in sp["moves"] if mv not in move_ids]
        if dropped:
            report.append("species %s: unknown learnset move(s) dropped: %s"
                          % (sp["id"], ", ".join(sorted(set(dropped)))))
        if not level1 and learn:
            lvl, mv = min(learn, key=lambda p: p[0])
            level1 = [mv]
            report.append("species %s: no level-1 move, hoisted %s (lv %d)"
                          % (sp["id"], mv, lvl))

        evos = []
        for target, method, param in sp["evolutions"]:
            if target not in wanted:
                report.append("species %s: evolution target %s outside "
                              "output set, dropped" % (sp["id"], target))
                continue
            if method == "Level" and param.isdigit():
                evos.append(OrderedDict([("method", "LEVEL"),
                                         ("level", int(param)),
                                         ("species", target)]))
            elif method == "Trade" and not param:
                evos.append(OrderedDict([("method", "TRADE"),
                                         ("species", target)]))
            else:
                deferred_evos.append("%s -> %s via %s(%s)"
                                     % (sp["id"], target, method, param))

        growth, note = GROWTH_MAP.get(sp["growth"], ("MEDIUM_FAST", "unknown"))
        if note:
            report.append("species %s: growth %s -> %s (%s)"
                          % (sp["id"], sp["growth"], growth, note))

        rec = OrderedDict()
        rec["id"] = sp["id"]
        rec["name"] = sp["name"]
        rec["dex"] = sp["dex"]
        rec["types"] = sp["types"]
        rec["baseStats"] = OrderedDict([("hp", hp), ("attack", atk),
                                        ("defense", dfn), ("speed", spd),
                                        ("special", special)])
        rec["catchRate"] = min(sp["catchRate"], 255)
        rec["baseExp"] = min(sp["baseExp"], 255)
        rec["growthRate"] = growth
        rec["level1Moves"] = level1
        rec["learnset"] = [OrderedDict([("level", lvl), ("move", mv)])
                           for lvl, mv in learn]
        rec["evolutions"] = evos
        rec.update(sprite_fields(sp["dex"], opts.battlers, report))
        rec["dexEntry"] = dex_entry(sp)
        out.append(rec)
    if deferred_evos:
        report.append("evolutions deferred (%d): need custom methods/items:"
                      % len(deferred_evos))
        for line in deferred_evos:
            report.append("  " + line)
    return out


# ------------------------------------------------------------ lua emission

LUA_KEY = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")


def lua_repr(value, indent=0):
    pad = "  " * indent
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        if isinstance(value, float) and value == int(value):
            return str(int(value))
        return repr(value)
    if isinstance(value, str):
        return '"%s"' % value.replace("\\", "\\\\").replace('"', '\\"')
    if isinstance(value, dict):
        parts = []
        for k, v in value.items():
            key = k if LUA_KEY.match(k) else '["%s"]' % k
            parts.append("%s  %s = %s" % (pad, key, lua_repr(v, indent + 1)))
        return "{\n%s,\n%s}" % (",\n".join(parts), pad)
    if isinstance(value, (list, tuple)):
        if not value:
            return "{}"
        simple = all(isinstance(v, (str, int, float, bool)) for v in value)
        if simple:
            return "{ %s }" % ", ".join(lua_repr(v) for v in value)
        parts = ["%s  %s" % (pad, lua_repr(v, indent + 1)) for v in value]
        return "{\n%s,\n%s}" % (",\n".join(parts), pad)
    raise TypeError("unsupported: %r" % (value,))


def write_lua(path, banner, table):
    with open(path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("-- generated by tools/pbs_convert.py -- do not edit\n")
        fh.write("-- " + banner + "\n")
        fh.write("return " + lua_repr(table) + "\n")


# ------------------------------------------------------------------- main


def parse_dex_range(text):
    m = re.match(r"^(\d+)-(\d+)$", text or "")
    if not m:
        return None
    return int(m.group(1)), int(m.group(2))


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--pbs", required=True, help="Essentials PBS directory")
    ap.add_argument("--out", default="gen", help="output directory")
    ap.add_argument("--dex", default=None,
                    help="slice, e.g. 1-24 (default: all species)")
    ap.add_argument("--special-fold", default="avg",
                    choices=["avg", "max", "spatk"],
                    help="how SpA/SpD fold into Gen 1 special")
    ap.add_argument("--battlers", default=None,
                    help="Graphics/Battlers dir for sprite size probing")
    ap.add_argument("--copy-sprites", action="store_true",
                    help="copy battler PNGs into <out>/battlers/")
    opts = ap.parse_args()

    report = ["pbs_convert report", "=" * 60]

    types = parse_types(os.path.join(opts.pbs, "types.txt"))
    moves = parse_moves(os.path.join(opts.pbs, "moves.txt"))
    species = parse_pokemon(os.path.join(opts.pbs, "pokemon.txt"))
    report.append("parsed: %d types, %d moves, %d species"
                  % (len(types), len(moves), len(species)))

    dex_range = parse_dex_range(opts.dex)
    if dex_range:
        lo, hi = dex_range
        species = [sp for sp in species if lo <= sp["dex"] <= hi]
        report.append("slice: dex %d-%d -> %d species" % (lo, hi, len(species)))

    real_type_ids = {t["id"] for t in types if not t["pseudo"]}
    new_types, chart_rows = build_type_output(types, report)
    move_recs, move_meta = build_move_output(moves, real_type_ids, report)
    move_ids = {m["id"] for m in move_recs}
    species_recs = build_species_output(species, move_ids, real_type_ids,
                                        opts, report)
    report.append("species: %d converted (special fold: %s)"
                  % (len(species_recs), opts.special_fold))

    os.makedirs(opts.out, exist_ok=True)
    write_lua(os.path.join(opts.out, "types.lua"),
              "new types + type-chart rows differing from the Gen 1 chart",
              OrderedDict([
                  ("types", [OrderedDict([
                      ("id", t["id"]), ("name", t["name"]),
                      ("category", "special" if t["special"] else "physical"),
                  ]) for t in new_types]),
                  ("matchups", chart_rows),
              ]))
    write_lua(os.path.join(opts.out, "moves.lua"),
              "move records; meta carries the Essentials fn codes",
              OrderedDict([("moves", move_recs), ("meta", move_meta)]))
    write_lua(os.path.join(opts.out, "species.lua"),
              "pokemon records; SpA/SpD folded into Gen 1 special",
              OrderedDict([("species", species_recs)]))

    if opts.copy_sprites and opts.battlers:
        dst = os.path.join(opts.out, "battlers")
        os.makedirs(dst, exist_ok=True)
        copied = 0
        for rec in species_recs:
            for suffix in ("%03d.png" % rec["dex"], "%03db.png" % rec["dex"]):
                src = os.path.join(opts.battlers, suffix)
                if os.path.exists(src):
                    shutil.copyfile(src, os.path.join(dst, suffix))
                    copied += 1
        report.append("sprites: copied %d battler pics to %s" % (copied, dst))

    report_path = os.path.join(opts.out, "REPORT.txt")
    with open(report_path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(report) + "\n")
    print("wrote %s: %d types, %d chart rows, %d moves, %d species"
          % (opts.out, len(new_types), len(chart_rows), len(move_recs),
             len(species_recs)))
    print("report: " + report_path)


if __name__ == "__main__":
    sys.exit(main())

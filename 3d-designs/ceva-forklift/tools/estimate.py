#!/usr/bin/env python3
"""Time / material / cost estimate for the CEVA forklift order.

Slicer numbers come from full production plates sliced with PrusaSlicer 2.7
using an H2C-like profile (tools/h2c_like.ini). Colour-change overhead is
counted from the geometry: every layer is sectioned and the colours present
on it are recorded, then the minimum number of nozzle switches (fixed nozzle
<-> Vortek) and Vortek hotend swaps is counted for one plate.

Edit the PARAMETERS block and run:  python3 tools/estimate.py
Needs: trimesh, numpy (pip install trimesh numpy networkx).
"""
import os
import numpy as np
import trimesh

HERE = os.path.dirname(os.path.abspath(__file__))
STL = os.path.join(HERE, '..', 'stl')

# ------------------------------------------------------------------ PARAMETERS
QTY = 200
SPARE = 0.05                # extra sets printed for rejects / assembly damage
SLICER_MARGIN = 1.10        # real H2C time vs. slicer estimate
T_NOZZLE_SWITCH = 15        # s, fixed nozzle <-> Vortek nozzle, incl. prime tower
T_VORTEK_SWAP = 25          # s, Vortek hotend swap (~18 s) + prime tower
PRIME_G_PER_CHANGE = 0.12   # g, prime tower / flush per change
T_PLATE_CHANGE_MIN = 10     # min of printer idle per plate (unload, wipe, restart)

FILAMENT_AED_PER_KG = 100   # Bambu PLA Basic/Matte in UAE, approx.
MACHINE_AED_PER_H = 3.0     # depreciation + maintenance + power (direct cost)
LABOUR_AED_PER_H = 50
CONSUMABLES_AED = 0.5       # CA glue, IPA, gloves per set
PACK_AED = 4.0              # individual box + bubble wrap per set

# Per-plate results from the slicer (copies, hours, grams, layer height)
PLATES = {
    #  key      copies  hours          grams   lh    fixed-nozzle colour, colours
    'body':   dict(n=16,  h=10 + 52/60, g=342.8, lh=0.20, fixed='white',
                   parts={'white': 'body_white', 'black': 'body_black', 'red': 'body_red'}),
    # white carton shown; the black carton swaps white<->black/navy, same counts
    'load':   dict(n=42,  h=15 + 40/60, g=425.0, lh=0.16, fixed='white',
                   parts={'white': 'load_box', 'wood': 'load_pallet', 'navy': 'load_logo', 'red': 'load_accent'}),
    'mast':   dict(n=40,  h=17 + 28/60, g=355.4, lh=0.20, fixed='black',
                   parts={'black': 'mast_black'}),
    'wheelF': dict(n=100, h=9 + 32/60,  g=195.8, lh=0.20, fixed='black',
                   parts={'black': 'wheelF_black', 'white': 'wheelF_white'}),
    'wheelR': dict(n=100, h=7 + 4/60,   g=131.9, lh=0.20, fixed='black',
                   parts={'black': 'wheelR_black', 'white': 'wheelR_white'}),
}
PER_SET = {'body': 1, 'load': 1, 'mast': 1, 'wheelF': 2, 'wheelR': 2}
DENSITY = 1.26  # g/cm3

LABOUR_MIN_PER_SET = {       # minutes of hands-on work per forklift
    'cleanup / inspection': 1.0,
    'wheels (4x CA glue + press)': 1.5,
    'mast into body + load onto forks': 1.0,
    'final QC': 0.5,
    'packing': 1.0,
}
# ---------------------------------------------------------------------------


def layer_colours(parts, lh):
    meshes = {c: trimesh.load(os.path.join(STL, f + '.stl')) for c, f in parts.items()}
    zmax = max(m.bounds[1][2] for m in meshes.values())
    layers = []
    z = lh / 2
    while z < zmax:
        present = set()
        for c, m in meshes.items():
            if m.bounds[0][2] <= z <= m.bounds[1][2]:
                sec = m.section(plane_origin=[0, 0, z], plane_normal=[0, 0, 1])
                if sec is not None and len(sec.entities):
                    present.add(c)
        layers.append(present)
        z += lh
    return layers


def count_changes(layers, fixed):
    """Greedy minimum colour changes; end each layer on a colour used next."""
    switches = swaps = 0
    cur = None
    for i, s in enumerate(layers):
        if not s:
            continue
        order = sorted(s, key=lambda c: 0 if c == cur else 1)
        nxt = layers[i + 1] if i + 1 < len(layers) else set()
        # put a colour that is also on the next layer at the end
        tail = [c for c in order[1:] if c in nxt]
        if tail:
            order.remove(tail[0]); order.append(tail[0])
        for c in order:
            if cur is not None and c != cur:
                if c == fixed or cur == fixed:
                    switches += 1
                else:
                    swaps += 1
            cur = c
    return switches, swaps


def main():
    sets = QTY * (1 + SPARE)
    rows = []
    tot_h = tot_g = 0.0
    plates_total = 0
    grams_by_colour = {}
    print(f'Order: {QTY} pcs (+{SPARE:.0%} spare = {sets:.0f} sets)\n')
    print(f'{"part":8s} {"/plate":>6s} {"plates":>6s} {"switch":>6s} {"swap":>5s} '
          f'{"min/pc":>7s} {"g/pc":>6s}')
    for key, p in PLATES.items():
        layers = layer_colours(p['parts'], p['lh'])
        sw, vs = count_changes(layers, p['fixed'])
        change_h = (sw * T_NOZZLE_SWITCH + vs * T_VORTEK_SWAP) / 3600
        plate_h = p['h'] * SLICER_MARGIN + change_h + T_PLATE_CHANGE_MIN / 60
        plate_g = p['g'] + (sw + vs) * PRIME_G_PER_CHANGE
        pieces = sets * PER_SET[key]
        plates = int(np.ceil(pieces / p['n']))
        plates_total += plates
        h = plates * plate_h
        g = pieces * plate_g / p['n']
        tot_h += h
        tot_g += g
        # colour split: inlay colours by solid volume, the rest is the main colour
        vols = {c: trimesh.load(os.path.join(STL, f + '.stl')).volume / 1000 for c, f in p['parts'].items()}
        main = max(vols, key=vols.get)
        piece_g = plate_g / p['n']
        minor = {c: v * DENSITY for c, v in vols.items() if c != main}
        split = {main: piece_g - sum(minor.values()), **minor}
        for c, gg in split.items():
            grams_by_colour[c] = grams_by_colour.get(c, 0) + gg * pieces
        print(f'{key:8s} {p["n"]:6d} {plates:6d} {sw:6d} {vs:5d} '
              f'{plate_h * 60 / p["n"]:7.1f} {piece_g:6.1f}')
        rows.append((key, plates, plate_h))

    per_set_h = tot_h / sets
    print(f'\nPrinter time total: {tot_h:.0f} h  ({per_set_h * 60:.0f} min per set), {plates_total} plates')
    for n in (1, 2, 3, 4):
        print(f'  calendar days of printing on {n} printer(s) @22 h/day: {tot_h / n / 22:.1f}')
    print(f'Filament total: {tot_g / 1000:.1f} kg')
    for c, g in sorted(grams_by_colour.items(), key=lambda x: -x[1]):
        print(f'  {c:6s} {g / 1000:5.2f} kg  -> buy {int(np.ceil(g / 1000 * 1.1))} x 1 kg')

    labour_h = QTY * sum(LABOUR_MIN_PER_SET.values()) / 60 + plates_total * 5 / 60
    cost = {
        'filament': tot_g / 1000 * FILAMENT_AED_PER_KG,
        'machine time': tot_h * MACHINE_AED_PER_H,
        'labour': labour_h * LABOUR_AED_PER_H,
        'consumables': QTY * CONSUMABLES_AED,
        'packaging': QTY * PACK_AED,
    }
    print(f'\nLabour: {labour_h:.0f} h')
    print('Direct cost (AED):')
    for k, v in cost.items():
        print(f'  {k:14s} {v:8.0f}   ({v / QTY:5.2f} / pc)')
    total = sum(cost.values())
    print(f'  {"TOTAL":14s} {total:8.0f}   ({total / QTY:5.2f} / pc)')


if __name__ == '__main__':
    main()

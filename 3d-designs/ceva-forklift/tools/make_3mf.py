#!/usr/bin/env python3
"""Pack the per-colour STLs into Bambu Studio 3MF projects.

Each forklift component becomes ONE object made of several parts, and every
part already has its filament slot assigned (Metadata/model_settings.config),
so Bambu Studio opens it ready for multi-colour printing:

    slot 1 White   slot 2 Black   slot 3 Red   slot 4 Kraft   slot 5 Navy

Only geometry + part/filament assignment is stored; printer, process and
filament presets are chosen in Bambu Studio (H2C, 0.4 nozzle, PLA).

Usage: python3 tools/make_3mf.py      (after tools/export_stl.sh)
"""
import os
import uuid
import zipfile
import numpy as np
import trimesh

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, '..')
STL = os.path.join(ROOT, 'stl')
OUT = os.path.join(ROOT, '3mf')

SLOT = {'white': 1, 'black': 2, 'red': 3, 'kraft': 4, 'navy': 5}

COMPONENTS = {
    'body':   [('body_white', 'white'), ('body_black', 'black'), ('body_red', 'red')],
    'load':   [('load_kraft', 'kraft'), ('load_navy', 'navy'), ('load_red', 'red')],
    'mast':   [('mast_black', 'black')],
    'wheelF': [('wheelF_black', 'black'), ('wheelF_white', 'white')],
    'wheelR': [('wheelR_black', 'black'), ('wheelR_white', 'white')],
}

# (file name, [(component, x, y), ...]) - positions are bed coordinates (mm)
JOBS = [
    ('ceva_forklift_SAMPLE_full_kit', [('body', 95, 105), ('load', 95, 200), ('mast', 200, 105),
                                       ('wheelF', 180, 190), ('wheelF', 210, 190),
                                       ('wheelR', 180, 220), ('wheelR', 210, 220)]),
    ('ceva_forklift_1_body',   [('body', 160, 160)]),
    ('ceva_forklift_2_load',   [('load', 160, 160)]),
    ('ceva_forklift_3_mast',   [('mast', 160, 160)]),
    ('ceva_forklift_4_wheels', [('wheelF', 145, 145), ('wheelF', 175, 145),
                                ('wheelR', 145, 175), ('wheelR', 175, 175)]),
]

NS = 'http://schemas.microsoft.com/3dmanufacturing/core/2015/02'
NS_P = 'http://schemas.microsoft.com/3dmanufacturing/production/2015/06'


def mesh_xml(m, obj_id, name):
    v = '\n'.join(f'     <vertex x="{x:.4f}" y="{y:.4f}" z="{z:.4f}"/>' for x, y, z in m.vertices)
    t = '\n'.join(f'     <triangle v1="{a}" v2="{b}" v3="{c}"/>' for a, b, c in m.faces)
    return (f'  <object id="{obj_id}" p:UUID="{uuid.uuid4()}" type="model" name="{name}">\n'
            f'   <mesh>\n    <vertices>\n{v}\n    </vertices>\n'
            f'    <triangles>\n{t}\n    </triangles>\n   </mesh>\n  </object>\n')


def load_component(comp):
    parts = [(f, c, trimesh.load(os.path.join(STL, f + '.stl'))) for f, c in COMPONENTS[comp]]
    allv = np.vstack([m.vertices for _, _, m in parts])
    lo, hi = allv.min(0), allv.max(0)
    shift = np.array([-(lo[0] + hi[0]) / 2, -(lo[1] + hi[1]) / 2, -lo[2]])
    for _, _, m in parts:
        m.apply_translation(shift)
    return parts


def build(job, placements):
    files = {}
    rels = []
    res = []
    items = []
    cfg = ['<?xml version="1.0" encoding="UTF-8"?>', '<config>']
    next_top = 1000
    next_sub = 1        # sub-object ids are unique across the whole package
    for n, (comp, x, y) in enumerate(placements, start=1):
        parts = load_component(comp)
        path = f'/3D/Objects/object_{n}.model'
        sub = [f'<?xml version="1.0" encoding="UTF-8"?>\n'
               f'<model unit="millimeter" xml:lang="en-US" xmlns="{NS}" xmlns:p="{NS_P}" requiredextensions="p">\n'
               f' <resources>\n']
        comps = []
        top_id = next_top + n
        cfg.append(f'  <object id="{top_id}">')
        cfg.append(f'    <metadata key="name" value="{comp}_{n}"/>')
        cfg.append(f'    <metadata key="extruder" value="{SLOT[parts[0][1]]}"/>')
        for fname, colour, m in parts:
            pid = next_sub
            next_sub += 1
            sub.append(mesh_xml(m, pid, fname))
            comps.append(f'    <component p:path="{path}" objectid="{pid}" p:UUID="{uuid.uuid4()}" '
                         f'transform="1 0 0 0 1 0 0 0 1 0 0 0"/>')
            cfg.append(f'    <part id="{pid}" subtype="normal_part">')
            cfg.append(f'      <metadata key="name" value="{fname} ({colour})"/>')
            cfg.append('      <metadata key="matrix" value="1 0 0 0 0 1 0 0 0 0 1 0 0 0 0 1"/>')
            cfg.append(f'      <metadata key="extruder" value="{SLOT[colour]}"/>')
            cfg.append('    </part>')
        cfg.append('  </object>')
        sub.append(' </resources>\n <build/>\n</model>\n')
        files[path.lstrip('/')] = ''.join(sub)
        rels.append(path)
        res.append(f'  <object id="{top_id}" p:UUID="{uuid.uuid4()}" type="model" name="{comp}_{n}">\n'
                   f'   <components>\n' + '\n'.join(comps) + '\n   </components>\n  </object>\n')
        items.append(f'  <item objectid="{top_id}" p:UUID="{uuid.uuid4()}" '
                     f'transform="1 0 0 0 1 0 0 0 1 {x} {y} 0" printable="1"/>')
    cfg.append('</config>\n')

    main = (f'<?xml version="1.0" encoding="UTF-8"?>\n'
            f'<model unit="millimeter" xml:lang="en-US" xmlns="{NS}" xmlns:p="{NS_P}" requiredextensions="p">\n'
            f' <metadata name="Title">{job}</metadata>\n'
            f' <metadata name="Designer">live3d.ae</metadata>\n'
            f' <metadata name="Description">CEVA promo forklift. Filament slots: 1 White, 2 Black, 3 Red, 4 Kraft, 5 Navy</metadata>\n'
            f' <resources>\n' + ''.join(res) + ' </resources>\n'
            f' <build p:UUID="{uuid.uuid4()}">\n' + '\n'.join(items) + '\n </build>\n</model>\n')
    content_types = ('<?xml version="1.0" encoding="UTF-8"?>\n'
                     '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">\n'
                     ' <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>\n'
                     ' <Default Extension="model" ContentType="application/vnd.ms-package.3dmanufacturing-3dmodel+xml"/>\n'
                     ' <Default Extension="config" ContentType="text/xml"/>\n'
                     '</Types>\n')
    root_rels = ('<?xml version="1.0" encoding="UTF-8"?>\n'
                 '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\n'
                 ' <Relationship Target="/3D/3dmodel.model" Id="rel-1" '
                 'Type="http://schemas.microsoft.com/3dmanufacturing/2013/01/3dmodel"/>\n'
                 '</Relationships>\n')
    model_rels = ('<?xml version="1.0" encoding="UTF-8"?>\n'
                  '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\n' +
                  ''.join(f' <Relationship Target="{p}" Id="rel-{i}" '
                          f'Type="http://schemas.microsoft.com/3dmanufacturing/2013/01/3dmodel"/>\n'
                          for i, p in enumerate(rels, start=1)) +
                  '</Relationships>\n')

    os.makedirs(OUT, exist_ok=True)
    out = os.path.join(OUT, job + '.3mf')
    with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED) as z:
        z.writestr('[Content_Types].xml', content_types)
        z.writestr('_rels/.rels', root_rels)
        z.writestr('3D/3dmodel.model', main)
        z.writestr('3D/_rels/3dmodel.model.rels', model_rels)
        for p, s in files.items():
            z.writestr(p, s)
        z.writestr('Metadata/model_settings.config', '\n'.join(cfg))
    print(f'{out}: {len(placements)} objects, {os.path.getsize(out) / 1024:.0f} KB')


if __name__ == '__main__':
    for job, placements in JOBS:
        build(job, placements)

import json
import math
import plistlib
import struct
import sys
from pathlib import Path

directory = Path(sys.argv[1])
manifest = json.loads((directory / 'scene.json').read_text())
assert manifest['bundleID'] == 'com.chiimagnus.RoamerTestApp'
assert manifest['pid'] > 0 and manifest['debuggerDetached']
assert manifest['source'].startswith('Apple libViewDebuggerSupport')
assert not manifest['capturesAreAtomic']
oracle = json.loads(Path(sys.argv[2]).read_text())
assert oracle['open'] and oracle['session'], 'fixture space must be open'
assert oracle['units'] == 'meters' and oracle['matrixLayout'] == 'column-major'
assert len(oracle['entities']) == 5, 'fixture must contain exactly five entities'
assert {entity['name'] for entity in oracle['entities']} == {
    'RoamerSceneOrigin', 'RotatedParent', 'DraggableCube', 'OccludingCube', 'ReferencePlane'
}, 'incomplete fixture oracle'
expected = {entity['id']: entity for entity in oracle['entities']}
assert len(expected) == 5, 'duplicate fixture entity IDs'
matched = set()

def matrix(properties):
    values = {prop['name']: prop['value']['associatedValue'] for prop in properties['elements']}
    rotation = values['rotation']
    rotation_x, rotation_y, rotation_z, rotation_w = rotation
    scale = values['scale']
    translation = values['translation']
    return [
        [(1-2*(rotation_y**2+rotation_z**2))*scale[0], 2*(rotation_x*rotation_y+rotation_z*rotation_w)*scale[0], 2*(rotation_x*rotation_z-rotation_y*rotation_w)*scale[0], 0],
        [2*(rotation_x*rotation_y-rotation_z*rotation_w)*scale[1], (1-2*(rotation_x**2+rotation_z**2))*scale[1], 2*(rotation_y*rotation_z+rotation_x*rotation_w)*scale[1], 0],
        [2*(rotation_x*rotation_z+rotation_y*rotation_w)*scale[2], 2*(rotation_y*rotation_z-rotation_x*rotation_w)*scale[2], (1-2*(rotation_x**2+rotation_y**2))*scale[2], 0],
        translation + [1],
    ]

def compare(actual, wanted):
    assert len(actual) == len(wanted)
    for left, right in zip(actual, wanted):
        if isinstance(left, list):compare(left, right)
        else:assert math.isclose(left, right, abs_tol=1e-5), (left, right)

def visit(entity, parent_matrix):
    components = {component['name']: component for component in entity['components']['elements']}
    local = matrix(components['Transform']['properties'])
    world = [[sum(parent_matrix[inner][row]*local[column][inner] for inner in range(4)) for row in range(4)] for column in range(4)]
    identity = str(entity['id']['id'])
    if identity in expected:
        wanted = expected[identity]
        matched.add(identity)
        assert entity['name'] == wanted['name']
        compare(local, wanted['localTransformColumns'])
        compare(world, wanted['worldTransformColumns'])
        if 'ModelComponent' in components:
            properties = components['ModelComponent']['properties']['elements']
            mesh = next(prop['value']['associatedValue'] for prop in properties if prop['name']=='mesh')
            bounds = next(prop['value']['associatedValue'] for prop in mesh['value']['elements'] if prop['name']=='bounds')
            points = {prop['name']:prop['value']['associatedValue'] for prop in bounds['value']['elements']}
            compare(points['min'],wanted['localBounds']['min'])
            compare(points['max'],wanted['localBounds']['max'])
        print(entity['name'], 'native transform/bounds match oracle', world[3][:3])
    for child in entity.get('children',{}).get('elements',[]):visit(child,world)

identity = [[float(column==row) for row in range(4)] for column in range(4)]
for capture in manifest['scenes']:
    assert capture['units'] == 'meters' and capture['sourceVersion'] == '2.0'
    native = plistlib.loads((directory / capture['nativeCapturePath']).read_bytes())
    configuration = plistlib.loads(native['internals']['sceneConfiguration'])
    assert configuration['bundleID'] == manifest['bundleID']
    scene = plistlib.loads(native['internals']['sceneDebugRepresentation'])
    for entity in scene['entities']['elements']:visit(entity,identity)
    for entity in capture['entities']:
        wanted = expected.get(entity['id'])
        if wanted is None:
            continue
        assert entity['name'] == wanted['name']
        compare(entity['localTransformColumns'], wanted['localTransformColumns'])
        compare(entity['referenceTransformColumns'], wanted['worldTransformColumns'])
        if wanted['parent'] is not None:
            assert entity['parentID'] == wanted['parent']
        if 'localBounds' in wanted:
            compare(entity['localModelBounds']['min'], wanted['localBounds']['min'])
            compare(entity['localModelBounds']['max'], wanted['localBounds']['max'])
        else:
            assert entity.get('localModelBounds') is None
assert matched == set(expected), (matched,set(expected))
published = {entity['id'] for capture in manifest['scenes'] for entity in capture['entities']}
assert set(expected) <= published
assert len(manifest['layouts']) == len(manifest['scenes'])
for layout in manifest['layouts']:
    assert len(layout['views']) == 4
    assert {view['projection'] for view in layout['views']} == {'overview', 'top', 'front', 'side'}
    assert len({view['pixelsPerMeter'] for view in layout['views'] if view['projection'] != 'overview'}) == 1
    assert layout['axisLengthMeters'] == 0.12
    for view in layout['views']:
        image = (directory / view['path']).read_bytes()
        assert image[:8] == b'\x89PNG\r\n\x1a\n'
        assert struct.unpack('>II', image[16:24]) == (view['width'], view['height'])
assert (directory / manifest['screenshot']['path']).is_file()
print('Native raw/published geometry and four layout PNGs PASS; 5 independent oracle entities matched')

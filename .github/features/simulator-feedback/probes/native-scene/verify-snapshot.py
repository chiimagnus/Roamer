import itertools
import json
import math
import plistlib
import sys
from pathlib import Path

native = plistlib.loads(Path(sys.argv[1]).read_bytes())
configuration = plistlib.loads(native['internals']['sceneConfiguration'])
assert configuration['bundleID'] == 'com.chiimagnus.RoamerTestApp'
scene = plistlib.loads(native['internals']['sceneDebugRepresentation'])
oracle = json.loads(Path(sys.argv[2]).read_text())
expected = {entity['id']: entity for entity in oracle['entities']}
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
for entity in scene['entities']['elements']:visit(entity,identity)
assert matched == set(expected), (matched,set(expected))
print('Native geometry PASS; 5 oracle entities matched; source is Apple debug capture, not fixture JSON')

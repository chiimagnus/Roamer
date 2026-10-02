import json
import math
import sys
from pathlib import Path

evidence = Path(sys.argv[1])
snapshots = {
    phase: json.loads((evidence / f"spatial-{phase}.json").read_text())
    for phase in ["before", "click", "drag", "closed", "reopened"]
}

for snapshot in snapshots.values():
    assert snapshot["units"] == "meters"
    assert snapshot["matrixLayout"] == "column-major"
    entities = {entity["name"]: entity for entity in snapshot["entities"]}
    parent = entities["RotatedParent"]["sceneTransformColumns"]
    cube = entities["DraggableCube"]
    local = cube["localTransformColumns"]
    actual = cube["sceneTransformColumns"]
    for column in range(4):
        for row in range(4):
            expected = sum(parent[inner][row] * local[column][inner] for inner in range(4))
            assert math.isclose(actual[column][row], expected, abs_tol=1e-5)
    assert cube["parent"] == entities["RotatedParent"]["id"]
    assert cube["accessible"] and not entities["OccludingCube"]["accessible"]
    bounds = entities["ReferencePlane"]["localBounds"]
    assert bounds["min"][1] == bounds["max"][1] == 0
    assert not math.isclose(parent[0][2], 0, abs_tol=1e-5)

before, click, drag = [snapshots[phase] for phase in ["before", "click", "drag"]]
assert before["session"] == click["session"] == drag["session"]
assert click["clicks"] == before["clicks"] + 1
assert drag["clicks"] == click["clicks"]
assert drag["dragEvents"] > click["dragEvents"]
assert drag["dragEnds"] == click["dragEnds"] + 1
by_phase = {
    phase: {entity["name"]: entity for entity in snapshots[phase]["entities"]}
    for phase in ["before", "click", "drag"]
}
delta = [
    by_phase["click"]["DraggableCube"]["sceneTransformColumns"][3][axis]
    - by_phase["before"]["DraggableCube"]["sceneTransformColumns"][3][axis]
    for axis in range(3)
]
for actual, expected in zip(delta, [0.1 * math.cos(math.pi / 6), 0, -0.05]):
    assert math.isclose(actual, expected, abs_tol=1e-5)
assert by_phase["drag"]["DraggableCube"]["sceneTransformColumns"] != by_phase["click"]["DraggableCube"]["sceneTransformColumns"]
for name in ["RotatedParent", "OccludingCube", "ReferencePlane"]:
    assert by_phase["before"][name]["sceneTransformColumns"] == by_phase["click"][name]["sceneTransformColumns"] == by_phase["drag"][name]["sceneTransformColumns"]
assert not snapshots["closed"]["open"]
assert snapshots["reopened"]["open"]
assert snapshots["reopened"]["session"] != snapshots["closed"]["session"]
assert all(snapshots["reopened"][counter] == 0 for counter in ["clicks", "dragEvents", "dragEnds"])
print("Spatial fixture: parent transforms, plane, accessibility, click, drag and reopen PASS")

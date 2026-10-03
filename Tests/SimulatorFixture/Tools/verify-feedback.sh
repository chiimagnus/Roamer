#!/bin/bash
set -euo pipefail

if [[ $# != 1 || -z "$1" ]]; then
    echo "用法: bash Tests/SimulatorFixture/Tools/verify-feedback.sh <new-evidence-dir>" >&2
    exit 1
fi
tools_dir="$(cd "$(dirname "$0")" && pwd)"
repo_dir="$(cd "$tools_dir/../../.." && pwd)"
roamer="$repo_dir/.build/release/roamer"
bundle="com.chiimagnus.RoamerTestApp"
[[ -x "$roamer" ]] || { echo "请先构建 release CLI" >&2; exit 1; }
evidence="$1"
mkdir -m 700 -- "$evidence"

observe() {
    "$roamer" observe "$bundle" "$evidence/$1-observe"
    python3 -I - "$evidence/$1-observe/observation.json" <<'PY'
import json, sys
from pathlib import Path
manifest = json.loads(Path(sys.argv[1]).read_text())
assert manifest['accessibility']['status'] == 'available', manifest['accessibility']
assert manifest['bundleID'] == 'com.chiimagnus.RoamerTestApp'
PY
}

observe before
device_id="$(python3 -I -c 'import json,sys; print(json.load(open(sys.argv[1]))["deviceUDID"])' "$evidence/before-observe/observation.json")"
container="$(xcrun simctl get_app_container "$device_id" "$bundle" data)"

oracle() {
    python3 -I - "$container/Documents/spatial.json" "$evidence" "$1" <<'PY'
import json, sys, time
from pathlib import Path
source, evidence, phase = Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3]
previous_phase = {'click': 'before', 'drag': 'click', 'closed': 'drag', 'reopened': 'closed'}.get(phase)
previous = json.loads((evidence / ('spatial-' + previous_phase + '.json')).read_text()) if previous_phase else None
deadline = time.monotonic() + 10
while time.monotonic() < deadline:
    try:
        data = source.read_bytes()
        current = json.loads(data)
        if phase == 'before':
            ready = current['open'] and bool(current['session'])
        elif phase == 'reopened':
            ready = current['open'] and current['session'] != previous['session'] and all(current[key] == 0 for key in ['clicks', 'dragEvents', 'dragEnds'])
        else:
            assert current['session'] == previous['session'], 'App/session changed; stopped without replay'
            if phase == 'click':
                ready = current['clicks'] == previous['clicks'] + 1 and current['dragEnds'] == previous['dragEnds']
            elif phase == 'drag':
                ready = current['clicks'] == previous['clicks'] and current['dragEvents'] > previous['dragEvents'] and current['dragEnds'] == previous['dragEnds'] + 1
            else:
                ready = not current['open']
        if ready:
            (evidence / ('spatial-' + phase + '.json')).write_bytes(data)
            break
    except (OSError, ValueError):
        pass
    time.sleep(0.1)
else:
    raise RuntimeError(phase + ': no expected App result within 10s; no automatic action replay')
PY
}

scene() {
    "$roamer" scene "$bundle" "$evidence/$1-scene"
    python3 -I "$tools_dir/verify-scene.py" "$evidence/$1-scene" "$evidence/spatial-$1.json"
}

debug_observe() {
    local phase="$1"
    local before="$evidence/$phase-debug-oracle-before.json"
    local after="$evidence/$phase-debug-oracle-after.json"
    cp "$container/Documents/spatial.json" "$before"
    "$roamer" observe "$bundle" "$evidence/$phase-debug-observe" --debug
    cp "$container/Documents/spatial.json" "$after"
    cmp "$before" "$after"
    "$roamer" observe "$bundle" "$evidence/$phase-debug-restored-observe"
    python3 -I - \
        "$evidence/$phase-debug-observe/observation.json" \
        "$evidence/$phase-debug-restored-observe/observation.json" <<'PY'
import json, sys
from pathlib import Path
debug = json.loads(Path(sys.argv[1]).read_text())
plain = json.loads(Path(sys.argv[2]).read_text())
overlay = debug['debugOverlay']
assert debug['pid'] == plain['pid']
assert debug['deviceUDID'] == plain['deviceUDID']
assert overlay['source'] == 'RealitySimulationServices.RSSDebugService'
assert overlay['options'] == ['entity_axis', 'entity_bounds']
assert overlay['restored'] is True
assert 'GPU completion' in overlay['renderFence'] and 'display frame' in overlay['renderFence']
assert plain.get('debugOverlay') is None
print('Formal observe --debug -> native fence -> restore PASS; inspect debug screenshot for platform XYZ/Bounds')
PY
}

coordinates() {
    echo "请查看最新画面: $evidence/$1-observe/screenshot.png" >&2
    read -r -p "$2（Simulator 像素，不是宿主屏幕；空输入/EOF 退出）: " -a points
    [[ ${#points[@]} == "$3" ]] || { echo "坐标数量错误，停止而不发送动作" >&2; exit 1; }
}

oracle before
debug_observe before
scene before
coordinates before "蓝色实体 click x y" 2
"$roamer" click "${points[@]}"
oracle click
observe click
scene click
coordinates click "蓝色实体 drag from-x from-y to-x to-y" 4
"$roamer" drag "${points[@]}" 700
oracle drag
observe drag
scene drag
coordinates drag "Close space 按钮 x y" 2
"$roamer" click "${points[@]}"
oracle closed
observe closed
coordinates closed "Open space 按钮 x y" 2
"$roamer" click "${points[@]}"
oracle reopened
observe reopened
scene reopened
python3 -I "$tools_dir/verify-spatial.py" "$evidence"
python3 -I - "$evidence" <<'PY'
import json, sys
from pathlib import Path
evidence = Path(sys.argv[1])
observations = [json.loads((evidence / (phase + '-observe/observation.json')).read_text()) for phase in ['before', 'click', 'drag', 'closed', 'reopened']]
assert len({item['pid'] for item in observations}) == 1, 'App restarted during feedback sequence'
assert len({item['deviceUDID'] for item in observations}) == 1
for phase in ['before', 'click', 'drag', 'reopened']:
    scene = json.loads((evidence / (phase + '-scene/scene.json')).read_text())
    assert scene['pid'] == observations[0]['pid'] and scene['deviceUDID'] == observations[0]['deviceUDID']
print('Formal observe -> click/drag -> scene -> close/reopen feedback PASS')
PY

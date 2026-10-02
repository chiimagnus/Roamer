import os
from pathlib import Path
import lldb

interpreter = lldb.debugger.GetCommandInterpreter()
owned = False
try:
    result = lldb.SBCommandReturnObject()
    interpreter.HandleCommand(f"process attach --pid {int(os.environ['ROAMER_PROBE_PID'])}", result)
    print(result.GetOutput() or "", result.GetError() or "", flush=True)
    if not result.Succeeded():
        raise RuntimeError("attach refused; no existing session is detached")
    owned = True
    for command in Path(os.environ['ROAMER_PROBE_COMMANDS']).read_text().splitlines():
        if not command.strip():
            continue
        result = lldb.SBCommandReturnObject()
        interpreter.HandleCommand(command, result)
        print("COMMAND", command, "\n", result.GetOutput() or "", result.GetError() or "", flush=True)
        if not result.Succeeded():
            raise RuntimeError("probe command failed")
finally:
    if owned:
        error = lldb.debugger.GetSelectedTarget().GetProcess().Detach()
        print("OWNED DETACH", error, flush=True)
        if error.Fail():
            raise RuntimeError("owned debugger cleanup failed")
print("PROBE COMPLETE", flush=True)

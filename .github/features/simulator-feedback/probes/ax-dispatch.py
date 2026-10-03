import lldb
import re
import struct

target = lldb.debugger.GetSelectedTarget()
process = target.GetProcess()
error = lldb.SBError()
base = 0x1e5916520
table = (0x1e5916514 & ~0xfff) - 30 * 4096 + 0x974
offsets = struct.unpack('<11i', process.ReadMemory(table, 44, error))
if error.Fail():
    raise RuntimeError(error)
for request_type, offset in enumerate(offsets, start=1):
    instructions = target.ReadInstructions(target.ResolveLoadAddress(base + offset), 3)
    branch = instructions.GetInstructionAtIndex(2)
    assert branch.GetMnemonic(target) == 'bl', str(branch)
    stub = int(branch.GetOperands(target).split()[0], 16)
    print('TYPE', request_type, 'dispatch', hex(base + offset), 'stub', hex(stub))
    stub_instructions = target.ReadInstructions(target.ResolveLoadAddress(stub), 4)
    page_delta = int(stub_instructions.GetInstructionAtIndex(0).GetOperands(target).split(', ')[1])
    page_offset = int(stub_instructions.GetInstructionAtIndex(1).GetOperands(target).split('#')[1], 16)
    selector_address = (stub & ~0xfff) + page_delta * 4096 + page_offset
    print('SELECTOR', process.ReadCStringFromMemory(selector_address, 200, error))
    for instruction in stub_instructions:
        print(instruction.GetAddress(), instruction.GetMnemonic(target), instruction.GetOperands(target), instruction.GetComment(target))

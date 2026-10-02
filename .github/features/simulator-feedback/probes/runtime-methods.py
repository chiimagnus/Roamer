import ctypes
import subprocess
import sys
from pathlib import Path

runtime = ctypes.CDLL('/usr/lib/libobjc.A.dylib')
runtime.objc_getClass.argtypes = [ctypes.c_char_p]
runtime.objc_getClass.restype = ctypes.c_void_p
runtime.object_getClass.argtypes = [ctypes.c_void_p]
runtime.object_getClass.restype = ctypes.c_void_p
runtime.class_copyMethodList.argtypes = [ctypes.c_void_p, ctypes.POINTER(ctypes.c_uint)]
runtime.class_copyMethodList.restype = ctypes.POINTER(ctypes.c_void_p)
runtime.method_getName.argtypes = [ctypes.c_void_p]
runtime.method_getName.restype = ctypes.c_void_p
runtime.sel_getName.argtypes = [ctypes.c_void_p]
runtime.sel_getName.restype = ctypes.c_char_p
runtime.method_getTypeEncoding.argtypes = [ctypes.c_void_p]
runtime.method_getTypeEncoding.restype = ctypes.c_char_p
libc = ctypes.CDLL(None)
libc.free.argtypes = [ctypes.c_void_p]

developer = Path(subprocess.check_output(['xcode-select', '-p'], text=True).strip())
for name in ['CoreSimulator', 'SimulatorKit', 'DebugHierarchyFoundation']:
    path = (Path('/Library/Developer/PrivateFrameworks') if name == 'CoreSimulator'
            else developer.parent / 'SharedFrameworks') / f'{name}.framework' / name
    ctypes.CDLL(str(path), mode=ctypes.RTLD_GLOBAL)

if 'SimVirtualHeadsetRemoteService' in sys.argv[1:]:
    plugin = developer / 'Platforms/XROS.platform/Library/Developer/CoreSimulator/Profiles/UserInterface/XROS.simdeviceui/Contents/MacOS/XROS'
    ctypes.CDLL(str(plugin), mode=ctypes.RTLD_GLOBAL)

for name in sys.argv[1:]:
    native_class = runtime.objc_getClass(name.encode())
    print(name, 'found' if native_class else 'absent')
    if not native_class:
        continue
    for kind, target in [('instance', native_class), ('class', runtime.object_getClass(native_class))]:
        count = ctypes.c_uint()
        methods = runtime.class_copyMethodList(target, ctypes.byref(count))
        for index in range(count.value):
            method = methods[index]
            print(kind, runtime.sel_getName(runtime.method_getName(method)).decode(),
                  runtime.method_getTypeEncoding(method).decode())
        libc.free(methods)

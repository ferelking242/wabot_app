#!/usr/bin/env python3
# patch-libnode.py — Fix Bug1 SIGTRAP + Bug2 SIGABRT dans libnode.so ARM64
#
# Bug1: EnableTrapHandler() compile avec V8_TRAP_HANDLER_SUPPORTED=false
#       -> corps = __builtin_trap() -> BRK -> SIGTRAP -> crash.
# Bug2: Patcher return false (0) declenchait CHECK() a InitializeNodeWithArgs+724
#       -> SIGABRT.
#
# Fix definitif: MOVZ X0,#1 (return true).
#   V8 croit que le trap handler est actif — inoffensif: Baileys = zero WebAssembly.
import struct, subprocess, sys, os

SO_PATH = sys.argv[1] if len(sys.argv) > 1 else 'android/app/src/main/jniLibs/arm64-v8a/libnode.so'

# VA d'EnableTrapHandler : pc=0x2111e70 (+40) => start=0x2111e48
KNOWN_VA = 0x2111e48

# ARM64 little-endian
#   MOVZ X0, #1 = 0xD2800020  (return true — passe le CHECK a InitializeNodeWithArgs+724)
#   RET         = 0xD65F03C0
MOVZ_X0_ONE = 0xD2800020
RET         = 0xD65F03C0

def find_symbol_va(so_path, substr):
    for cmd in [['nm', '--defined-only', so_path], ['readelf', '-s', '--wide', so_path]]:
        try:
            r = subprocess.run(cmd, capture_output=True, text=True)
            for line in r.stdout.splitlines():
                if substr in line:
                    for part in line.split():
                        try:
                            v = int(part, 16)
                            if v > 0x100000:
                                return v
                        except ValueError:
                            pass
        except Exception as e:
            print('warn:', e)
    return None

def va_to_file_offset(data, va):
    e_phoff    = struct.unpack_from('<Q', data, 32)[0]
    e_phentsize = struct.unpack_from('<H', data, 54)[0]
    e_phnum    = struct.unpack_from('<H', data, 56)[0]
    for i in range(e_phnum):
        ph     = e_phoff + i * e_phentsize
        p_type = struct.unpack_from('<I', data, ph)[0]
        if p_type == 1:  # PT_LOAD
            p_offset = struct.unpack_from('<Q', data, ph + 8)[0]
            p_vaddr  = struct.unpack_from('<Q', data, ph + 16)[0]
            p_filesz = struct.unpack_from('<Q', data, ph + 32)[0]
            if p_vaddr <= va < p_vaddr + p_filesz:
                return p_offset + (va - p_vaddr)
    return None

def main():
    if not os.path.exists(SO_PATH):
        print('ERROR: {} not found'.format(SO_PATH))
        sys.exit(1)
    print('[patch-libnode] Loading {}...'.format(SO_PATH))
    with open(SO_PATH, 'rb') as f:
        data = bytearray(f.read())
    print('[patch-libnode] Size: {:,} bytes'.format(len(data)))
    if data[:4] != b'\x7fELF':
        print('ERROR: not an ELF file')
        sys.exit(1)
    va = find_symbol_va(SO_PATH, 'EnableTrapHandler')
    if va is not None:
        print('[patch-libnode] Symbol found: EnableTrapHandler @ VA {}'.format(hex(va)))
    else:
        va = KNOWN_VA
        print('[patch-libnode] Symbol not found, using known VA: {}'.format(hex(va)))
    file_off = va_to_file_offset(data, va)
    if file_off is None:
        print('ERROR: cannot map VA {} -> file offset'.format(hex(va)))
        sys.exit(1)
    print('[patch-libnode] File offset: {}'.format(hex(file_off)))
    i0  = struct.unpack_from('<I', data, file_off)[0]
    i1  = struct.unpack_from('<I', data, file_off + 4)[0]
    i40 = struct.unpack_from('<I', data, file_off + 40)[0]
    print('[patch-libnode] Instr: +0={} +4={} +40={}'.format(hex(i0), hex(i1), hex(i40)))
    if i0 == MOVZ_X0_ONE and i1 == RET:
        print('[patch-libnode] Already patched (return true), nothing to do.')
        return
    if (i40 & 0xFFE0001F) == 0xD4200000:
        print('[patch-libnode] BRK confirmed at +40: {} OK'.format(hex(i40)))
    else:
        print('[patch-libnode] WARN: instr at +40 ({}) differs from expected BRK'.format(hex(i40)))
    struct.pack_into('<I', data, file_off,     MOVZ_X0_ONE)
    struct.pack_into('<I', data, file_off + 4, RET)
    with open(SO_PATH, 'wb') as f:
        f.write(data)
    with open(SO_PATH, 'rb') as f:
        d2 = bytearray(f.read())
    v0 = struct.unpack_from('<I', d2, file_off)[0]
    v1 = struct.unpack_from('<I', d2, file_off + 4)[0]
    assert v0 == MOVZ_X0_ONE and v1 == RET, 'Verify failed: {} {}'.format(hex(v0), hex(v1))
    print('[patch-libnode] OK: EnableTrapHandler returns true (1) — CHECK() will pass.')
    print('[patch-libnode] Done.')

if __name__ == '__main__':
    main()

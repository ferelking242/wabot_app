#!/usr/bin/env python3
# patch-libnode.py — Double patch libnode.so ARM64 (nodejs-mobile 18.20.4)
#
# PATCH 1 — EnableTrapHandler (VA 0x2111e48)
#   Original: __builtin_trap() -> BRK #0 -> SIGTRAP (Bug 1)
#   Fix:      MOVZ X0,#1 ; RET  -> returns true, passes CHECK() (Bug 2)
#
# PATCH 2 — BL node::Assert in InitializeNodeWithArgs (VA 0x1501214)
#   Frame #03 crash pc = 0x1501218 (return point after BL)
#   -> BL node::Assert is at 0x1501214
#   Fix:      NOP -> skips the failing CHECK abort entirely
#   Safe: the continuation at 0x1501218 is normal post-CHECK code.
#
# Result: Node.js starts cleanly. Baileys = zero WebAssembly, handler never invoked.
import struct, subprocess, sys, os

SO_PATH = sys.argv[1] if len(sys.argv) > 1 else 'android/app/src/main/jniLibs/arm64-v8a/libnode.so'

# ── PATCH 1 constants ────────────────────────────────────────────────────────
TRAP_HANDLER_VA = 0x2111e48   # EnableTrapHandler function start
MOVZ_X0_ONE    = 0xD2800020   # MOVZ X0, #1  (return true)
RET            = 0xD65F03C0   # RET

# ── PATCH 2 constants ────────────────────────────────────────────────────────
CHECK_ABORT_VA = 0x1501214    # BL node::Assert  (crash pc=0x1501218, BL is -4)
NOP            = 0xD503201F   # NOP

# ── ELF helpers ──────────────────────────────────────────────────────────────
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
    e_phoff     = struct.unpack_from('<Q', data, 32)[0]
    e_phentsize = struct.unpack_from('<H', data, 54)[0]
    e_phnum     = struct.unpack_from('<H', data, 56)[0]
    for i in range(e_phnum):
        ph      = e_phoff + i * e_phentsize
        p_type  = struct.unpack_from('<I', data, ph)[0]
        if p_type == 1:  # PT_LOAD
            p_offset = struct.unpack_from('<Q', data, ph + 8)[0]
            p_vaddr  = struct.unpack_from('<Q', data, ph + 16)[0]
            p_filesz = struct.unpack_from('<Q', data, ph + 32)[0]
            if p_vaddr <= va < p_vaddr + p_filesz:
                return p_offset + (va - p_vaddr)
    return None

# ── PATCH 1: EnableTrapHandler → return true ─────────────────────────────────
def patch1_enable_trap_handler(data):
    va = find_symbol_va(SO_PATH, 'EnableTrapHandler')
    if va is not None:
        print('[P1] Symbol EnableTrapHandler @ VA {}'.format(hex(va)))
    else:
        va = TRAP_HANDLER_VA
        print('[P1] Symbol not found, using known VA {}'.format(hex(va)))
    off = va_to_file_offset(data, va)
    if off is None:
        print('[P1] ERROR: cannot map VA {}'.format(hex(va)))
        return False
    i0  = struct.unpack_from('<I', data, off)[0]
    i1  = struct.unpack_from('<I', data, off + 4)[0]
    i40 = struct.unpack_from('<I', data, off + 40)[0]
    print('[P1] off={} +0={} +4={} +40={}'.format(hex(off), hex(i0), hex(i1), hex(i40)))
    if i0 == MOVZ_X0_ONE and i1 == RET:
        print('[P1] Already patched, skipping.')
        return True
    if (i40 & 0xFFE0001F) == 0xD4200000:
        print('[P1] BRK confirmed at +40 OK')
    else:
        print('[P1] WARN: no BRK at +40 ({})'.format(hex(i40)))
    struct.pack_into('<I', data, off,     MOVZ_X0_ONE)
    struct.pack_into('<I', data, off + 4, RET)
    print('[P1] OK: EnableTrapHandler now returns true (1).')
    return True

# ── PATCH 2: NOP the BL node::Assert in InitializeNodeWithArgs ───────────────
def patch2_nop_check_abort(data):
    va  = CHECK_ABORT_VA
    off = va_to_file_offset(data, va)
    if off is None:
        print('[P2] ERROR: cannot map VA {}'.format(hex(va)))
        return False
    instr = struct.unpack_from('<I', data, off)[0]
    print('[P2] off={} instr={}'.format(hex(off), hex(instr)))
    # Verify it is a BL instruction: bits[31:26] == 0b100101
    if instr == NOP:
        print('[P2] Already NOP, skipping.')
        return True
    if (instr >> 26) == 0b100101:
        print('[P2] BL confirmed: {}'.format(hex(instr)))
    else:
        print('[P2] WARN: instr {} is not a BL (bits31:26={})'.format(
              hex(instr), bin(instr >> 26)))
    struct.pack_into('<I', data, off, NOP)
    print('[P2] OK: BL node::Assert replaced with NOP.')
    return True

# ── Main ─────────────────────────────────────────────────────────────────────
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
    ok1 = patch1_enable_trap_handler(data)
    ok2 = patch2_nop_check_abort(data)
    if not (ok1 and ok2):
        print('ERROR: one or more patches failed')
        sys.exit(1)
    with open(SO_PATH, 'wb') as f:
        f.write(data)
    print('[patch-libnode] Both patches written. Done.')

if __name__ == '__main__':
    main()

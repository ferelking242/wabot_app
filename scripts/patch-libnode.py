#!/usr/bin/env python3
  # patch-libnode.py
  # Patch EnableTrapHandler dans libnode.so pour retourner TRUE immediatement.
  #
  # Sur Android ARM64 (Galaxy S21 + Android 15), libnode.so Node.js Mobile 18.20.4
  # est compile avec V8_TRAP_HANDLER_SUPPORTED=false. EnableTrapHandler() est donc
  # juste __builtin_trap() -> BRK -> SIGTRAP -> crash fatal (Bug 1).
  #
  # Fix precedent : MOV X0,XZR (return false) -> declenchait CHECK() a
  # InitializeNodeWithArgs+724 -> SIGABRT (Bug 2).
  #
  # Fix definitif : MOVZ X0,#1 (return true) -> le CHECK() passe.
  # Baileys ne fait aucun WebAssembly, le trap handler ne sera jamais invoque.
  # Le handler n'est pas vraiment installe, mais V8 ne le detecte pas.
  import struct, subprocess, sys, os

  SO_PATH = sys.argv[1] if len(sys.argv) > 1 else "android/app/src/main/jniLibs/arm64-v8a/libnode.so"

  # VA connue depuis le backtrace : pc 0x2111e70 = EnableTrapHandler+40 -> start 0x2111e48
  KNOWN_VA = 0x2111e48

  # ARM64 little-endian :
  #   MOVZ X0, #1  = 0xD2800020  (return true — passe le CHECK a InitializeNodeWithArgs+724)
  #   RET          = 0xD65F03C0
  MOVZ_X0_ONE = 0xD2800020
  RET = 0xD65F03C0

  def find_symbol_va(so_path, substr):
      for cmd in [["nm", "--defined-only", so_path], ["readelf", "-s", "--wide", so_path]]:
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
              print("warn:", e)
      return None

  def va_to_file_offset(data, va):
      e_phoff = struct.unpack_from("<Q", data, 32)[0]
      e_phentsize = struct.unpack_from("<H", data, 54)[0]
      e_phnum = struct.unpack_from("<H", data, 56)[0]
      for i in range(e_phnum):
          ph = e_phoff + i * e_phentsize
          p_type = struct.unpack_from("<I", data, ph)[0]
          if p_type == 1:
              p_offset = struct.unpack_from("<Q", data, ph + 8)[0]
              p_vaddr = struct.unpack_from("<Q", data, ph + 16)[0]
              p_filesz = struct.unpack_from("<Q", data, ph + 32)[0]
              if p_vaddr <= va < p_vaddr + p_filesz:
                  return p_offset + (va - p_vaddr)
      return None

  def main():
      if not os.path.exists(SO_PATH):
          print("ERROR: {} not found".format(SO_PATH))
          sys.exit(1)
      print("[patch-libnode] Chargement de {}...".format(SO_PATH))
      with open(SO_PATH, "rb") as f:
          data = bytearray(f.read())
      print("[patch-libnode] Taille: {:,} bytes".format(len(data)))
      if data[:4] != b"\x7fELF":
          print("ERROR: pas un fichier ELF")
          sys.exit(1)
      va = find_symbol_va(SO_PATH, "EnableTrapHandler")
      if va is not None:
          print("[patch-libnode] Symbole trouve: EnableTrapHandler @ VA {}".format(hex(va)))
      else:
          va = KNOWN_VA
          print("[patch-libnode] Symbole non trouve, utilisation adresse connue: {}".format(hex(va)))
      file_off = va_to_file_offset(data, va)
      if file_off is None:
          print("ERROR: impossible de mapper VA {} -> file offset".format(hex(va)))
          sys.exit(1)
      print("[patch-libnode] Offset fichier: {}".format(hex(file_off)))
      i0 = struct.unpack_from("<I", data, file_off)[0]
      i1 = struct.unpack_from("<I", data, file_off + 4)[0]
      i40 = struct.unpack_from("<I", data, file_off + 40)[0]
      print("[patch-libnode] Instr: +0={} +4={} +40={}".format(hex(i0), hex(i1), hex(i40)))
      if i0 == MOVZ_X0_ONE and i1 == RET:
          print("[patch-libnode] Deja patche (return true), rien a faire.")
          return
      if (i40 & 0xFFE0001F) == 0xD4200000:
          print("[patch-libnode] BRK confirme a +40: {} OK".format(hex(i40)))
      else:
          print("[patch-libnode] WARN: instr a +40 ({}) differente du BRK attendu".format(hex(i40)))
      struct.pack_into("<I", data, file_off, MOVZ_X0_ONE)
      struct.pack_into("<I", data, file_off + 4, RET)
      with open(SO_PATH, "wb") as f:
          f.write(data)
      with open(SO_PATH, "rb") as f:
          d2 = bytearray(f.read())
      v0 = struct.unpack_from("<I", d2, file_off)[0]
      v1 = struct.unpack_from("<I", d2, file_off + 4)[0]
      assert v0 == MOVZ_X0_ONE and v1 == RET, "Verification echouee: {} {}".format(hex(v0), hex(v1))
      print("[patch-libnode] OK: EnableTrapHandler retourne true (1) — CHECK() passe.")
      print("[patch-libnode] Done.")

  if __name__ == "__main__":
      main()
  
#!/usr/bin/env python3
  """
  patch-libnode.py - Patch EnableTrapHandler dans libnode.so pour retourner false immédiatement.

  Sur Android ARM64 (Galaxy S21 + Android 15), libnode.so Node.js Mobile 18.20.4
  est compilé avec V8_TRAP_HANDLER_SUPPORTED=false. EnableTrapHandler() est donc
  juste __builtin_trap() qui émet une instruction BRK -> SIGTRAP -> crash fatal.

  Fix : remplacer les 2 premières instructions par MOV X0, XZR ; RET
  La fonction retourne alors false immédiatement, sans crash.
  Node.js continue sans le trap handler WebAssembly (aucun impact pour un bot JS).
  """
  import struct, subprocess, sys, os

  SO_PATH = sys.argv[1] if len(sys.argv) > 1 else \
      'android/app/src/main/jniLibs/arm64-v8a/libnode.so'

  # Adresse virtuelle connue d'EnableTrapHandler dans libnode.so 18.20.4 ARM64
  # Source : backtrace (pc 0x2111e70 = EnableTrapHandler+40, donc start = 0x2111e48)
  KNOWN_VA = 0x2111e48

  # ARM64 instructions (little-endian uint32):
  #   MOV X0, XZR  = ORR X0, XZR, XZR = 0xAA1F03E0  -> retourne 0 (false)
  #   RET           = 0xD65F03C0
  MOV_X0_ZERO = 0xAA1F03E0
  RET         = 0xD65F03C0


  def find_symbol_va(data, symbol_substr):
      """Cherche l'adresse virtuelle d'un symbole via nm ou readelf."""
      # Via nm -D (symboles dynamiques)
      try:
          r = subprocess.run(['nm', '--defined-only', SO_PATH],
                             capture_output=True, text=True)
          for line in r.stdout.splitlines():
              if symbol_substr in line:
                  parts = line.split()
                  if len(parts) >= 3 and len(parts[0]) >= 8:
                      try:
                          return int(parts[0], 16)
                      except ValueError:
                          pass
      except Exception as e:
          print(f'nm error: {e}')

      # Via readelf -s (toutes sections)
      try:
          r = subprocess.run(['readelf', '-s', '--wide', SO_PATH],
                             capture_output=True, text=True)
          for line in r.stdout.splitlines():
              if symbol_substr in line and 'FUNC' in line:
                  parts = line.split()
                  if len(parts) >= 8:
                      try:
                          addr = int(parts[1], 16)
                          if addr > 0:
                              return addr
                      except ValueError:
                          pass
      except Exception as e:
          print(f'readelf error: {e}')

      return None


  def va_to_file_offset(data, va):
      """Convertit une adresse virtuelle en offset fichier via les segments ELF."""
      e_phoff    = struct.unpack_from('<Q', data, 32)[0]
      e_phentsize = struct.unpack_from('<H', data, 54)[0]
      e_phnum    = struct.unpack_from('<H', data, 56)[0]

      for i in range(e_phnum):
          ph = e_phoff + i * e_phentsize
          p_type   = struct.unpack_from('<I', data, ph)[0]
          if p_type == 1:  # PT_LOAD
              p_offset = struct.unpack_from('<Q', data, ph + 8)[0]
              p_vaddr  = struct.unpack_from('<Q', data, ph + 16)[0]
              p_filesz = struct.unpack_from('<Q', data, ph + 32)[0]
              if p_vaddr <= va < p_vaddr + p_filesz:
                  return p_offset + (va - p_vaddr)
      return None


  def main():
      if not os.path.exists(SO_PATH):
          print(f'ERROR: {SO_PATH} not found', file=sys.stderr)
          sys.exit(1)

      print(f'[patch-libnode] Chargement de {SO_PATH}...')
      with open(SO_PATH, 'rb') as f:
          data = bytearray(f.read())
      print(f'[patch-libnode] Taille: {len(data):,} bytes')

      # Vérification ELF ARM64
      if data[:4] != b'\x7fELF':
          print('ERROR: pas un fichier ELF', file=sys.stderr)
          sys.exit(1)
      if data[4] != 2:  # EI_CLASS = ELFCLASS64
          print('ERROR: pas un ELF 64-bit', file=sys.stderr)
          sys.exit(1)

      # 1. Chercher EnableTrapHandler par symbole
      va = find_symbol_va(data, 'EnableTrapHandler')
      if va is not None:
          print(f'[patch-libnode] Symbole trouvé: EnableTrapHandler @ VA {hex(va)}')
      else:
          # Fallback: adresse connue depuis le backtrace
          va = KNOWN_VA
          print(f'[patch-libnode] Symbole non trouvé dans .symtab/.dynsym')
          print(f'[patch-libnode] Utilisation de l\'adresse connue: {hex(va)}')

      # 2. VA -> file offset
      file_off = va_to_file_offset(data, va)
      if file_off is None:
          print(f'ERROR: impossible de mapper VA {hex(va)} -> file offset', file=sys.stderr)
          sys.exit(1)
      print(f'[patch-libnode] Offset fichier: {hex(file_off)}')

      # 3. Lire les instructions actuelles
      i0 = struct.unpack_from('<I', data, file_off)[0]
      i1 = struct.unpack_from('<I', data, file_off + 4)[0]
      i10 = struct.unpack_from('<I', data, file_off + 40)[0]
      print(f'[patch-libnode] Instructions actuelles: +0={hex(i0)}  +4={hex(i1)}  +40={hex(i10)}')

      # 4. Vérifier que ce n'est pas déjà patché
      if i0 == MOV_X0_ZERO and i1 == RET:
          print('[patch-libnode] Déjà patché, rien à faire.')
          return

      # 5. Vérifier que +40 ressemble au BRK connu (0xD4200000 ou 0xD4200020)
      # BRK #n = 0xD4200000 | (n << 5), TRAP_BRKPT utilise BRK #0 ou BRK #1
      if (i10 & 0xFFE0001F) == 0xD4200000:
          print(f'[patch-libnode] BRK confirmé à +40: {hex(i10)} ✓')
      else:
          print(f'[patch-libnode] ATTENTION: instruction à +40 ({hex(i10)}) différente du BRK attendu')
          print('[patch-libnode] Application du patch quand même (basé sur adresse connue)')

      # 6. Appliquer le patch
      struct.pack_into('<I', data, file_off,     MOV_X0_ZERO)  # MOV X0, XZR
      struct.pack_into('<I', data, file_off + 4, RET)           # RET
      print('[patch-libnode] Patch appliqué: EnableTrapHandler retourne false immédiatement')

      with open(SO_PATH, 'wb') as f:
          f.write(data)

      # 7. Vérification
      with open(SO_PATH, 'rb') as f:
          d2 = bytearray(f.read())
      v0 = struct.unpack_from('<I', d2, file_off)[0]
      v1 = struct.unpack_from('<I', d2, file_off + 4)[0]
      assert v0 == MOV_X0_ZERO and v1 == RET, \
          f'Vérification échouée: {hex(v0)} {hex(v1)}'
      print(f'[patch-libnode] Vérification OK: {hex(v0)} {hex(v1)}')
      print('[patch-libnode] Done. libnode.so patché avec succès.')


  if __name__ == '__main__':
      main()
  
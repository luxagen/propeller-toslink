DAT

pattern byte %00111110,%00001010,%00001010,%00001010,%00000010,%00000000,%00111110,%00100000,%00100000,%00100000,%00100000,%00000000,%00100010,%00111110,%00100010,%00000000,%00111110,%00101010,%00101010,%00101010,%00010100,%00000000,%00111110,%00101010,%00101010,%00101010,%00010100,%00000000,%00111110,%00100000,%00100000,%00100000,%00100000,%00000000,%00111110,%00101010,%00101010,%00101010,%00100010,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000

pub Main | idx
  dira[16..23] := $FF

  repeat
    repeat idx from 0 to 45
      outa[23..16] := %10000000|pattern[idx]
      waitcnt(20000+cnt)
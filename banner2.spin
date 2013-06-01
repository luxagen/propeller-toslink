DAT

pattern
        byte %01111111
        byte %00001001
        byte %00001001
        byte %00001001
        byte %00000001
        byte %00000000
        byte %01111111
        byte %01000000
        byte %01000000
        byte %01000000
        byte %01000000
        byte %00000000
        byte %01000001
        byte %01111111
        byte %01000001
        byte %00000000
        byte %01111111
        byte %01001001
        byte %01001001
        byte %01001001
        byte %00110110
        byte %00000000
        byte %01111111
        byte %01001001
        byte %01001001
        byte %01001001
        byte %00110110
        byte %00000000
        byte %01111111
        byte %01000000
        byte %01000000
        byte %01000000
        byte %01000000
        byte %00000000
        byte %01111111
        byte %01001001
        byte %01001001
        byte %01001001
        byte %01000001
        byte %00000000
        byte %00000000
        byte %00000000
        byte %00000000
        byte %00000000
        byte %00000000
        byte %00000000

pub Main | idx
  dira[16..23] := $FF

  repeat
    repeat idx from 0 to 45
      outa[23..16] := %10000000|pattern[idx]
      waitcnt(20000+cnt)
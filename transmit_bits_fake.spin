CON
  ADV_MASK = 1

PUB init(symbol_rate,pin)
  dira[16..23] := $FF
  dira &= !ADV_MASK

PUB send(data)
  send2(data)
  send2(data>>8)
  send2(data>>16)
  send2(data>>24)
  
PUB send2(data)
  outa[16..23] := data
  waitpeq(0,ADV_MASK,0)
  waitpeq(ADV_MASK,ADV_MASK,0)
'  waitcnt(clkfreq+cnt)
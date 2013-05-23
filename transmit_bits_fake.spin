CON

VAR
  long interval
  long int_inv

PUB init(symbol_rate,pin)
  interval := CLKFREQ/1
  int_inv := interval/256
  dira[16..23] := $FF

PUB send(data)
  send2(data)
  send2(data>>8)
  send2(data>>16)
  send2(data>>24)
  
PUB send2(data)
  outa[23..16] := !data
  waitcnt(int_inv+cnt)
  outa[23..16] := data
  waitcnt(interval-int_inv+cnt)

CON
  preamble_b=%00010111
  preamble_m=%01000111
  preamble_w=%00100111

VAR
  long interval
  long int_inv
  long subframes[2]
  long oc_stack[128] ' TUNE THIS DOWN

DAT
        frame  long -1

PRI init(symbol_rate,pin)
  interval := CLKFREQ/16
  int_inv := interval/256
  dira[16..23] := $FF

PRI send(data)
  send2(data)
  send2(data>>8)
  send2(data>>16)
  send2(data>>24)
  
PRI send2(data)
  outa[23..16] := !data
  waitcnt(int_inv+cnt)
  outa[23..16] := data
  waitcnt(interval-int_inv+cnt)

{
PRI loop(array,length) | counter,temp
  counter := 0
  repeat
    send(get_preamble|long[array][counter++])
    send(long[array][counter++])
    counter//=length
}

PUB write(subframeA,subframeB)
  subframes[0] := subframeA
  subframes[1] := subframeB

PRI _outcog(carrier_rate,pin) | tempA,tempB
  init(carrier_rate,pin)
  repeat
    tempA := subframes[0]
    tempB := subframes[1]
    send(get_preamble|tempA)
    send(tempB)

PUB start(carrier_rate,pin)
  cognew(_outcog(carrier_rate,pin),@oc_stack)

PRI get_preamble
  ++frame

  ifnot frame//384
    return preamble_b
  elseif frame&1
    return preamble_w
  else
    return preamble_m


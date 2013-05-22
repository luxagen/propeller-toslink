VAR
  long Stack[9]

PUB Start(Pin,Delay,Count)
  cognew(Toggle(Pin,Delay,Count),@Stack)

PUB Toggle(Pin,Delay,Count)
  dira[Pin]~~
  repeat Count
    !outa[Pin]
    waitcnt(Delay + cnt)
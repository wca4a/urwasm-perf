::  +hot-test: the ways a kept-alive instance could go stale, each checked
::
::    +hot-test %gent
::
::  uses bench/rustmod.wasm, whose `tick` counts calls: the n-th call on an
::  instance answers n. every line is [what got expected]; the last word says
::  whether all of them agree.
::
/+  wasm-lib=wasm-lia
:-  %say
|=  $:  [now=@da eny=@uvJ bec=beak]
        [hint=@tas ~]
        ~
    ==
:-  %noun
=/  wasm  wasm-lib
=/  arr  (arrows:wasm vase)
=/  bin=octs
  .^(octs %cx /(scot %p p.bec)/[q.bec]/(scot %da now)/bench/rustmod/wasm)
=/  imp=(import:lia-sur:wasm vase)  [*vase ~]
=/  sed0=seed:lia-sur:wasm  [bin (return:runnable:wasm ~) ~ imp]
=/  call
  |=  [sed=seed:lia-sur:wasm fn=@t]
  ^-  [@ seed:lia-sur:wasm]
  =/  scr
    =/  m  runnable:wasm
    ^-  form:m
    =,  arr
    ;<  out=(list @)  try:m  (call fn ~)
    (return:m ~[noun+out])
  =^  res  sed  (run:wasm &+scr sed hint)
  =/  yil  -.res
  ?>  ?=([%0 [[%noun *] ~]] yil)
  [;;(@ -.+.i.p.yil) sed]
=|  out=(list [@t @ @])
::  1. plain sequence: the instance is picked up again call after call
=^  a1  sed0  (call sed0 'tick')
=/  s1  sed0
=^  a2  s1  (call s1 'tick')
=^  a3  s1  (call s1 'tick')
=^  a4  s1  (call s1 'tick')
=^  a5  s1  (call s1 'tick')
=.  out  :*  ['sequence 5' a5 5]  ['sequence 4' a4 4]  ['sequence 1' a1 1]  out  ==
=/  s5  s1
::  2. a call succeeds, then the computation around it crashes: its effect
::     must be gone, and the next call must continue from before it
=/  r2  (mule |.(=+((call s5 'tick') ?>(=(0 1) -.-))))
=.  out  [['crash after a call is caught' ?:(?=(%| -.r2) 1 0) 1] out]
=^  a6  s1  (call s5 'tick')
=.  out  [['after rollback' a6 6] out]
=/  s6  s1
::  3. the call itself fails halfway: the instance has already counted a
::     tick when the script crashes, and nothing is saved
=/  half
  =/  m  runnable:wasm
  ^-  form:m
  =,  arr
  ;<  out=(list @)  try:m  (call 'tick' ~)
  ?>  =(0 1)
  (return:m ~[noun+out])
=/  r3  (mule |.((run:wasm &+half s6 hint)))
=.  out  [['failed call is caught' ?:(?=(%| -.r3) 1 0) 1] out]
=^  a7  s1  (call s6 'tick')
=.  out  [['after failed call' a7 7] out]
=/  s7  s1
::  4. go back to an older point and branch from it, then return to the newer
=/  sb  s5
=^  b6  sb  (call sb 'tick')
=^  a8  s1  (call s7 'tick')
=.  out  :*  ['branch from an old point' b6 6]  ['newest point unaffected' a8 8]  out  ==
::  5. more instances than are kept alive, taken in turn
=/  many=(list [n=@ sed=seed:lia-sur:wasm])
  %+  turn  (gulf 1 12)
  |=  j=@
  =/  s  sed0
  =/  k  0
  |-
  ?:  =(k j)  [+(j) s]
  =^  *  s  (call s 'tick')
  $(k +(k))
=/  rounds  0
|-
?:  =(rounds 3)
  =/  bad  (skip out |=([@t g=@ e=@] =(g e)))
  [(flop out) ?~(bad %all-agree %mismatch)]
=^  got=(list [@t @ @])  many
  =|  got=(list [@t @ @])
  =|  nex=(list [n=@ sed=seed:lia-sur:wasm])
  |-
  ?~  many  [got (flop nex)]
  =^  v  sed.i.many  (call sed.i.many 'tick')
  $(many t.many, got [['instance in rotation' v +(n.i.many)] got], nex [[+(n.i.many) sed.i.many] nex])
$(rounds +(rounds), out (weld got out))

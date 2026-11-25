::  +bench: time n stateful urwasm calls
::
::    +bench %p1-f0 100 %gent 'nop' ~
::    +bench %p1-f0 1 %gent 'spin' ~[1.000.000]
::
/+  wasm-lib=wasm-lia
:-  %say
|=  $:  [now=@da eny=@uvJ bec=beak]
        [name=@ta n=@ud hint=@tas fn=@t args=(list @) ~]
        ~
    ==
:-  %noun
=/  wasm  wasm-lib
=/  arr  (arrows:wasm vase)
=/  bin=octs
  .^(octs %cx /(scot %p p.bec)/[q.bec]/(scot %da now)/bench/[name]/wasm)
=/  imp=(import:lia-sur:wasm vase)  [*vase ~]
=/  sed=seed:lia-sur:wasm  [bin (return:runnable:wasm ~) ~ imp]
=/  scr
  =/  m  runnable:wasm
  ^-  form:m
  =,  arr
  ;<  out=(list @)  try:m  (call fn args)
  (return:m ~[noun+out])
=/  i  0
=/  last=*  ~
~>  %bout
|-
?:  =(i n)  [i last]
=^  res  sed  (run:wasm &+scr sed hint)
$(i +(i), last -.res)

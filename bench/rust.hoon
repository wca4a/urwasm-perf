::  +rust: run a sequence of calls against one stateful urwasm instance
::
::    +rust %rustmod %gent ~[['tick' 50 ~] ['fill' 1 ~[20.000]]]
::
::  each step is [function-name repeat-count args]; when an arg list is
::  ~[%i], the loop counter is passed instead (so 'put' gets 0, 1, 2...)
::
/+  wasm-lib=wasm-lia
:-  %say
|=  $:  [now=@da eny=@uvJ bec=beak]
        [name=@ta hint=@tas steps=(list [fn=@t n=@ud args=(list @)]) ~]
        ~
    ==
:-  %noun
=/  wasm  wasm-lib
=/  arr  (arrows:wasm vase)
=/  bin=octs
  .^(octs %cx /(scot %p p.bec)/[q.bec]/(scot %da now)/bench/[name]/wasm)
=/  imp=(import:lia-sur:wasm vase)  [*vase ~]
=/  sed=seed:lia-sur:wasm  [bin (return:runnable:wasm ~) ~ imp]
=|  out=(list [@t *])
|-
?~  steps  (flop out)
=/  i  0
=/  last=*  ~
|-
?:  =(i n.i.steps)  ^$(steps t.steps, out [[fn.i.steps last] out])
=/  args=(list @)  ?:(=(args.i.steps ~[%i]) ~[i] args.i.steps)
=/  scr
  =/  m  runnable:wasm
  ^-  form:m
  =,  arr
  ;<  res=(list @)  try:m  (call fn.i.steps args)
  (return:m ~[noun+res])
=^  res  sed  (run:wasm &+scr sed hint)
$(i +(i), last -.res)

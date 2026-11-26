::  +monad: how long does it take just to BUILD script steps, without running any wasm?
::    +monad 10.000 %call    build (call-1 'response' ~) n times
::    +monad 10.000 %bind    build one whole `;<` step n times
::    +monad 10.000 %none    the empty loop, for comparison
/+  wasm-lib=wasm-lia
:-  %say
|=  $:  [now=@da eny=@uvJ bec=beak]
        [n=@ud mode=@tas ~]
        ~
    ==
:-  %noun
=/  wasm  wasm-lib
=/  arr  (arrows:wasm vase)
=/  m  runnable:wasm
=/  i  0
=/  last=*  ~
|-
?:  =(i n)  [i (mug last)]
?+    mode  !!
    %none  $(i +(i), last i)
    %bunt
  =/  f  *m-sat:arr
  $(i +(i), last -.f)
    %gate
  =/  f  |=(sat=m-sat:arr sat)
  $(i +(i), last -.f)
    %ret
  =/  f  (return:m ~)
  $(i +(i), last -.f)
    %raw
  =/  f  =,(arr (call 'response' ~))
  $(i +(i), last -.f)
    %rawb
  =/  f
    ^-  form:m
    =,  arr
    ;<  a=(list @)  try:m  (call 'response' ~)
    (return:m ~[noun+a])
  $(i +(i), last -.f)
    %mem
  =/  f  =,(arr (memread 0 16))
  $(i +(i), last -.f)
    %call
  =/  f  =,(arr (call-1 'response' ~))
  $(i +(i), last -.f)
    %bind
  =/  f
    ^-  form:m
    =,  arr
    ;<  a=@  try:m  (call-1 'response' ~)
    (return:m ~[noun+a])
  $(i +(i), last -.f)
==

::  +steps: which part of a multi-step script costs time?
::    +steps %notes 100 %gent %c1   (modes: c1 c2 c4 w r all lean)
/+  wasm-lib=wasm-lia
:-  %say
|=  $:  [now=@da eny=@uvJ bec=beak]
        [name=@ta n=@ud hint=@tas mode=@tas ~]
        ~
    ==
:-  %noun
=/  wasm  wasm-lib
=/  arr  (arrows:wasm vase)
=/  bin=octs
  .^(octs %cx /(scot %p p.bec)/[q.bec]/(scot %da now)/bench/[name]/wasm)
=/  imp=(import:lia-sur:wasm vase)  [*vase ~]
=/  sed=seed:lia-sur:wasm  [bin (return:runnable:wasm ~) ~ imp]
=/  req=@  '{"op":"stats"}'
=/  len=@  (met 3 req)
::  for %lean: reserve the request buffer once, up front, and remember where it is
=^  ptr=@  sed
  ?.  ?=(%lean mode)  [0 sed]
  =/  ask
    =/  m  runnable:wasm
    ^-  form:m
    =,  arr
    ;<  out=(list @)  try:m  (call 'request' ~[len])
    (return:m ~[noun+out])
  =^  res  sed  (run:wasm &+ask sed hint)
  =/  yil  -.res
  ?>  ?=([%0 [[%noun *] ~]] yil)
  [;;(@ -.+.i.p.yil) sed]
=/  scr
  =/  m  runnable:wasm
  ^-  form:m
  =,  arr
  ?+    mode  !!
      %c1
    ;<  a=@  try:m  (call-1 'response' ~)
    (return:m ~[noun+a])
      %c2
    ;<  a=@  try:m  (call-1 'response' ~)
    ;<  b=@  try:m  (call-1 'response' ~)
    (return:m ~[noun+b])
      %c4
    ;<  a=@  try:m  (call-1 'response' ~)
    ;<  b=@  try:m  (call-1 'response' ~)
    ;<  c=@  try:m  (call-1 'response' ~)
    ;<  d=@  try:m  (call-1 'response' ~)
    (return:m ~[noun+d])
      %w
    ;<  ptr=@  try:m  (call-1 'request' ~[len])
    ;<  ~      try:m  (memwrite ptr len req)
    (return:m ~[noun+ptr])
      %r
    ;<  loc=@     try:m  (call-1 'response' ~)
    ;<  res=octs  try:m  (memread loc 16)
    (return:m ~[octs+res])
      %lean
    ::  the same request as %all in fewer, plainer steps: no `request` call
    ::  (the buffer is already reserved) and `call` in place of `call-1`
    ;<  ~              try:m  (memwrite ptr len req)
    ;<  k=(list @)     try:m  (call 'handle' ~[len])
    ;<  loc=(list @)   try:m  (call 'response' ~)
    ;<  res=octs       try:m  (memread -.loc -.k)
    (return:m ~[octs+res])
      %all
    ;<  ptr=@     try:m  (call-1 'request' ~[len])
    ;<  ~         try:m  (memwrite ptr len req)
    ;<  k=@       try:m  (call-1 'handle' ~[len])
    ;<  loc=@     try:m  (call-1 'response' ~)
    ;<  res=octs  try:m  (memread loc k)
    (return:m ~[octs+res])
  ==
=/  i  0
=/  last=*  ~
|-
?:  =(i n)  [i last]
=^  res  sed  (run:wasm &+scr sed hint)
$(i +(i), last -.res)

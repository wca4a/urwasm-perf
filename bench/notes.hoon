::  +notes: feed a file of JSON requests, one per line, to a Wasm app
::
::    +notes %notes %notes-work %gent
::
::  each request is one stateful urwasm run: reserve a buffer in the app,
::  write the request text into Wasm memory, call the handler, read the
::  response text back out. produces [length first-8-bytes-of-sha256] per
::  response, so the answers can be compared with another Wasm engine.
::
/+  wasm-lib=wasm-lia
:-  %say
|=  $:  [now=@da eny=@uvJ bec=beak]
        [name=@ta work=@ta hint=@tas ~]
        ~
    ==
:-  %noun
=/  wasm  wasm-lib
=/  arr  (arrows:wasm vase)
=/  pax=path  /(scot %p p.bec)/[q.bec]/(scot %da now)/bench
=/  bin=octs  .^(octs %cx (weld pax /[name]/wasm))
=/  reqs=wain  .^(wain %cx (weld pax /[work]/txt))
=/  imp=(import:lia-sur:wasm vase)  [*vase ~]
=/  sed=seed:lia-sur:wasm  [bin (return:runnable:wasm ~) ~ imp]
=|  out=(list [@ud @ud])
|-
?~  reqs  (flop out)
?:  =('' i.reqs)  $(reqs t.reqs)
=/  len=@  (met 3 i.reqs)
=/  req=@  i.reqs
=/  scr
  =/  m  runnable:wasm
  ^-  form:m
  =,  arr
  ;<  ptr=@     try:m  (call-1 'request' ~[len])
  ;<  ~         try:m  (memwrite ptr len req)
  ;<  n=@       try:m  (call-1 'handle' ~[len])
  ;<  loc=@     try:m  (call-1 'response' ~)
  ;<  res=octs  try:m  (memread loc n)
  (return:m ~[octs+res])
=^  res  sed
  ~>  %bout
  (run:wasm &+scr sed hint)
=/  yil  -.res
?>  ?=([%0 [[%octs *] ~]] yil)
=/  o=octs  +.i.p.yil
$(reqs t.reqs, out [[p.o (end [6 1] (shay p.o q.o))] out])

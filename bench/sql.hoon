::  +sql: feed a file of SQL requests, one per line, to SQLite running in urwasm
::
::    +sql %sqlapp %sql-work %gent
::
::  each request is one stateful urwasm run: write the SQL into Wasm memory,
::  call the handler, read the JSON response back. when SQLite asks for the
::  time or for random bits the run stops and hands the question back here;
::  we answer it and the run carries on from where it stopped. produces
::  [length first-8-bytes-of-sha256] per response.
::
/+  wasm-lib=wasm-lia
=/  lv  lia-value:lia-sur:wasm-lib
=/  cw  coin-wasm:wasm-sur:wasm-lib
=/  script  script:lia-sur:wasm-lib
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
=/  imp=(import:lia-sur:wasm vase)
  :-  *vase
  =/  m  (script (list cw) vase)
  %-  malt
  :~  :-  'env'^'ship_now'
      |=  args=(pole cw)
      ^-  form:m
      =,  arr
      ;<  res=(list lv)  try:m  (call-ext %now ~)
      (return:m ;;((list cw) res))
    ::
      :-  'env'^'ship_entropy'
      |=  args=(pole cw)
      ^-  form:m
      =,  arr
      ;<  res=(list lv)  try:m  (call-ext %entropy ~)
      (return:m ;;((list cw) res))
  ==
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
  =/  r=[[yield:runnable:wasm vase] seed:lia-sur:wasm]  (run:wasm &+scr sed hint)
  |-
  =/  yil  -<.r
  ?.  ?=(%1 -.yil)  r
  =/  val=(list lv)
    ?+  name.yil  !!
      %now      ~[i64+1.795.608.000.000]
      %entropy  ~[i64+0x1234.5678.9abc.def0]
    ==
  $(r (run:wasm |+val +.r hint))
=/  yil  -.res
?>  ?=([%0 [[%octs *] ~]] yil)
=/  o=octs  +.i.p.yil
$(reqs t.reqs, out [[p.o (end [6 1] (shay p.o q.o))] out])

::  %sql: SQLite (bench/sqlapp.wasm) running in urwasm, served over HTTP
::
::    GET  /sql         the web page (bench/sql-ui.html)
::    POST /sql/api     SQL text in, JSON out
::    POST /sql/reset   throw the database away and start over
::
::  every request is one stateful urwasm run against the same instance.
::  when SQLite asks for the time or for random bits, the run stops and
::  hands the question to this agent, which answers from the ship's own
::  clock and entropy and lets the run carry on.
::
/+  default-agent, wasm-lib=wasm-lia
=/  lv  lia-value:lia-sur:wasm-lib
=/  cw  coin-wasm:wasm-sur:wasm-lib
=/  script  script:lia-sur:wasm-lib
|%
+$  card  card:agent:gall
+$  seed  seed:lia-sur:wasm-lib
+$  state-0  [%0 sed=(unit seed)]
++  new-seed
  |=  =bowl:gall
  ^-  seed
  =/  arr  (arrows:wasm-lib vase)
  =/  bin=octs
    .^(octs %cx /(scot %p our.bowl)/[q.byk.bowl]/(scot %da now.bowl)/bench/sqlapp/wasm)
  =/  imp=(import:lia-sur:wasm-lib vase)
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
  [bin (return:runnable:wasm-lib ~) ~ imp]
::
++  ask
  |=  [sed=seed body=octs now=@da eny=@uvJ]
  ^-  [octs seed]
  =/  wasm  wasm-lib
  =/  arr  (arrows:wasm vase)
  =/  len=@  p.body
  =/  req=@  q.body
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
  =/  r=[[yield:runnable:wasm vase] seed]  (run:wasm &+scr sed %gent)
  |-
  =/  yil  -<.r
  ?:  ?=(%1 -.yil)
    =/  val=(list lv)
      ?+  name.yil  !!
        %now      ~[i64+(div (sub now ~1970.1.1) (div ~s1 1.000))]
        %entropy  ~[i64+(end [6 1] eny)]
      ==
    $(r (run:wasm |+val +.r %gent))
  ?>  ?=([%0 [[%octs *] ~]] yil)
  =/  o=octs  +.i.p.yil
  [o +.r]
::
++  give
  |=  [eyre-id=@ta status=@ud type=@t data=octs]
  ^-  (list card)
  =/  paths=(list path)  [/http-response/[eyre-id]]~
  :~  [%give %fact paths %http-response-header !>(`response-header:http`[status ['content-type' type]~])]
      [%give %fact paths %http-response-data !>(`(unit octs)`[~ data])]
      [%give %kick paths ~]
  ==
--
=|  state-0
=*  state  -
^-  agent:gall
|_  =bowl:gall
+*  this  .
    def   ~(. (default-agent this %|) bowl)
++  on-init
  ^-  (quip card _this)
  :_  this(sed `(new-seed bowl))
  [%pass /eyre %arvo %e %connect [~ /sql] %sql]~
++  on-save  !>(state)
++  on-load
  |=  old=vase
  ^-  (quip card _this)
  =/  was  (mole |.(!<(state-0 old)))
  ?:  &(?=(^ was) ?=(^ sed.u.was))  [~ this(state u.was)]
  [~ this(sed `(new-seed bowl))]
++  on-poke
  |=  [=mark =vase]
  ^-  (quip card _this)
  ?.  ?=(%handle-http-request mark)  (on-poke:def mark vase)
  =+  !<([eyre-id=@ta req=inbound-request:eyre] vase)
  =/  url=@t  url.request.req
  ?:  ?=(%'GET' method.request.req)
    =/  page=@t
      .^(@t %cx /(scot %p our.bowl)/[q.byk.bowl]/(scot %da now.bowl)/bench/sql-ui/html)
    [(give eyre-id 200 'text/html; charset=utf-8' (as-octs:mimes:html page)) this]
  ?:  =('/sql/reset' url)
    :_  this(sed `(new-seed bowl))
    (give eyre-id 200 'application/json' (as-octs:mimes:html '{"ok":true}'))
  =/  body=octs  (fall body.request.req [0 0])
  =/  out  (ask (need sed) body now.bowl eny.bowl)
  [(give eyre-id 200 'application/json' -.out) this(sed `+.out)]
++  on-watch
  |=  =path
  ^-  (quip card _this)
  ?:  ?=([%http-response *] path)  `this
  (on-watch:def path)
++  on-leave  on-leave:def
++  on-peek   on-peek:def
++  on-agent  on-agent:def
++  on-arvo
  |=  [=wire =sign-arvo]
  ^-  (quip card _this)
  ?:  ?=([%eyre %bound *] sign-arvo)  `this
  (on-arvo:def wire sign-arvo)
++  on-fail   on-fail:def
--

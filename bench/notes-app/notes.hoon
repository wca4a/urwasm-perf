::  %notes: serve the Rust notes backend (bench/notes.wasm) over HTTP
::
::    GET  /notes         the web page (bench/notes-ui.html)
::    POST /notes/api     one JSON request in, one JSON response out
::    POST /notes/reset   throw the notes away and start over
::
::  every request is one stateful urwasm run against the same instance
::
/+  default-agent, wasm-lib=wasm-lia
|%
+$  card  card:agent:gall
+$  seed  seed:lia-sur:wasm-lib
+$  state-0  [%0 sed=(unit seed)]
++  new-seed
  |=  =bowl:gall
  ^-  seed
  =/  bin=octs
    .^(octs %cx /(scot %p our.bowl)/[q.byk.bowl]/(scot %da now.bowl)/bench/notes/wasm)
  =/  imp=(import:lia-sur:wasm-lib vase)  [*vase ~]
  [bin (return:runnable:wasm-lib ~) ~ imp]
::
++  ask
  |=  [sed=seed body=octs]
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
  =^  res  sed  (run:wasm &+scr sed %gent)
  =/  yil  -.res
  ?>  ?=([%0 [[%octs *] ~]] yil)
  =/  o=octs  +.i.p.yil
  [o sed]
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
  [%pass /eyre %arvo %e %connect [~ /notes] %notes]~
++  on-save  !>(~)
++  on-load
  |=  old=vase
  ^-  (quip card _this)
  [~ this(sed `(new-seed bowl))]
++  on-poke
  |=  [=mark =vase]
  ^-  (quip card _this)
  ?.  ?=(%handle-http-request mark)  (on-poke:def mark vase)
  =+  !<([eyre-id=@ta req=inbound-request:eyre] vase)
  =/  url=@t  url.request.req
  ?:  ?=(%'GET' method.request.req)
    =/  page=@t
      .^(@t %cx /(scot %p our.bowl)/[q.byk.bowl]/(scot %da now.bowl)/bench/notes-ui/html)
    [(give eyre-id 200 'text/html; charset=utf-8' (as-octs:mimes:html page)) this]
  ?:  =('/notes/reset' url)
    :_  this(sed `(new-seed bowl))
    (give eyre-id 200 'application/json' (as-octs:mimes:html '{"ok":true}'))
  =/  body=octs  (fall body.request.req [0 0])
  =^  res=octs  sed
    =/  out  (ask (need sed) body)
    [-.out `+.out]
  [(give eyre-id 200 'application/json' res) this]
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

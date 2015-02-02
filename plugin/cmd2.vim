let s:save_cpo = &cpo
set cpo&vim

if exists('g:cmd2_loaded') && g:cmd2_loaded
  finish
endif

let s:cmd2_default_options = {
      \ 'buffer_cursor_hl': cmd2#init#CursorHl(),
      \ 'buffer_cursor_show': 1,
      \ 'cursor_blink': 1,
      \ 'cursor_blinkoff': 250,
      \ 'cursor_blinkon': 400,
      \ 'cursor_blinkwait': 700,
      \ 'cursor_hl': cmd2#init#CursorHl(),
      \ 'cursor_text': '_',
      \ 'max_remap_depth': 20,
      \ 'loop_refresh_rate': 20,
      \ 'preload': 0,
      \ 'snippet_cursor': '≡',
      \ 'snippet_cursor_hl': 'Title',
      \ 'snippet_cursor_replace': '###',
      \ 'timeoutlen': &timeoutlen,
      \ }

if !exists('g:cmd2_options')
  let g:cmd2_options = {
        \ }
endif

" mapping cannot start with number as it will be treated as count
let s:cmd2_default_cmd_mappings = {
      \ 'w': {'command': 'cmd2#commands#Cword', 'type': 'function', 'flags': 'Crv'},
      \ "\<Plug>Cmd2Tab": {'command': "cmd2#commands#TabForward", 'type': 'function'},
      \ "\<Plug>Cmd2STab": {'command': "cmd2#commands#TabBackward", 'type': 'function'},
      \ "\<Tab>": {'command': "\<Plug>Cmd2Tab", 'type': 'remap'},
      \ "\<S-Tab>": {'command': "\<Plug>Cmd2STab", 'type': 'remap'},
      \ }

if !exists('g:cmd2_cmd_mappings')
  let g:cmd2_cmd_mappings = {
        \ }
endif

let s:cmd2_default_mappings = {
      \ }

if !exists('g:cmd2_mappings')
  let g:cmd2_mappings = {
        \ }
endif

call cmd2#init#Options(s:cmd2_default_options)
call cmd2#init#CmdMappings(s:cmd2_default_cmd_mappings)

if g:cmd2_preload
  call cmd2#Autoload()
endif

cnoremap <silent> <expr> <Plug>Cmd2 getcmdtype() =~ '\v[?:\/]' ? cmd2#main#Init() . "<C-U><C-C>:call cmd2#main#Run()<CR>" : ""

let g:cmd2_loaded = 1

let &cpo = s:save_cpo
unlet s:save_cpo

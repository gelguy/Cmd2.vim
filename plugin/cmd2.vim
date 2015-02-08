let s:save_cpo = &cpo
set cpo&vim

if exists('g:Cmd2_loaded') && g:Cmd2_loaded
  finish
endif

let s:Cmd2_default_options = {
      \ 'buffer_cursor_hl': cmd2#init#BufferCursorHl(),
      \ 'buffer_cursor_show': 1,
      \ 'cursor_blink': 1,
      \ 'cursor_blinkoff': 250,
      \ 'cursor_blinkon': 400,
      \ 'cursor_blinkwait': 700,
      \ 'cursor_hl': cmd2#init#CursorHl(),
      \ 'cursor_text': '_',
      \ 'max_remap_depth': 20,
      \ 'loop_sleep': 20,
      \ 'preload': 0,
      \ 'snippet_cursor': '≡',
      \ 'snippet_cursor_hl': 'Title',
      \ 'snippet_cursor_replace': '###',
      \ 'timeoutlen': &timeoutlen,
      \ 'menu_selected_hl': 'WildMenu',
      \ 'menu_hl': 'StatusLine',
      \ 'menu_next': '>',
      \ 'menu_previous': '<',
      \ 'menu_more': '…',
      \ '_complete_ignorecase': 0,
      \ '_complete_uniq_ignorecase': 1,
      \ '_complete_pattern': '\k\*',
      \ '_complete_start_pattern': '\<',
      \ '_complete_fuzzy': 1,
      \ '_complete_generate': 'cmd2#ext#complete#GenerateCandidates',
      \ '_complete_next': "\<Tab>",
      \ '_complete_previous': "\<S-Tab>",
      \ '_quicksearch_ignorecase': 0,
      \ '_quicksearch_hl': 'Search',
      \ '_quicksearch_current_hl': 'ErrorMsg',
      \ }

if !exists('g:Cmd2_options')
  let g:Cmd2_options = {
        \ }
endif

" mapping cannot start with number as it will be treated as count
let s:Cmd2_default_cmd_mappings = {
      \ }

if !exists('g:Cmd2_cmd_mappings')
  let g:Cmd2_cmd_mappings = {
        \ }
endif

let s:Cmd2_default_mappings = {
      \ }

if !exists('g:Cmd2_mappings')
  let g:Cmd2_mappings = {
        \ }
endif

call cmd2#init#Options(s:Cmd2_default_options)
call cmd2#init#CmdMappings(s:Cmd2_default_cmd_mappings)

if g:Cmd2_preload
  call cmd2#Autoload()
endif

cnoremap <silent> <expr> <Plug>Cmd2 getcmdtype() =~ '\v[?:\/]' ? cmd2#main#Init() . "<C-E><C-U><C-C>:call cmd2#main#Run()<CR>" : ""

let g:Cmd2_loaded = 1

let &cpo = s:save_cpo
unlet s:save_cpo

let s:save_cpo = &cpo
set cpo&vim

if exists('g:Cmd2_loaded') && g:Cmd2_loaded
  finish
endif

let g:Cmd2_default_options = {
      \ 'buffer_cursor_hl': Cmd2#init#BufferCursorHl(),
      \ 'buffer_cursor_show': 1,
      \ 'cursor_blink': 1,
      \ 'cursor_blinkoff': 250,
      \ 'cursor_blinkon': 400,
      \ 'cursor_blinkwait': 700,
      \ 'cursor_hl': Cmd2#init#CursorHl(),
      \ 'cursor_text': '_',
      \ 'max_remap_depth': 20,
      \ 'loop_sleep': 20,
      \ 'loop_func': 'Cmd2#loop#Init',
      \ 'preload': 0,
      \ 'snippet_cursor': '≡',
      \ 'snippet_cursor_hl': 'Title',
      \ 'snippet_cursor_replace': '###',
      \ 'timeoutlen': &timeoutlen,
      \ 'menu_selected_hl': 'WildMenu',
      \ 'menu_hl': 'StatusLine',
      \ 'menu_next': '>',
      \ 'menu_previous': '<',
      \ 'menu_more': '...',
      \ 'menu_separator': ' ',
      \ 'menu_separator_hl': 'StatusLine',
      \ '_complete_ignorecase': 0,
      \ '_complete_uniq_ignorecase': 0,
      \ '_complete_pattern_func': 'Cmd2#ext#complete#CreatePattern',
      \ '_complete_start_pattern': '\<',
      \ '_complete_middle_pattern': '\k\*',
      \ '_complete_end_pattern': '\k\*',
      \ '_complete_fuzzy': 1,
      \ '_complete_next': "\<Tab>",
      \ '_complete_previous': "\<S-Tab>",
      \ '_complete_exit': "\<Esc>",
      \ '_complete_loading_text': "",
      \ '_complete_loading_hl': "",
      \ '_complete_generate': 'Cmd2#ext#complete#GenerateCandidates',
      \ '_complete_string_pattern': '\v\k*$',
      \ '_complete_get_string': 'Cmd2#ext#complete#GetString',
      \ '_complete_conceal_patterns': {},
      \ '_complete_conceal_func': 'Cmd2#ext#complete#Conceal',
      \ '_complete_incsearch': 0,
      \ '_complete_mru_length': 0,
      \ '_complete_sort_func': 'lexographic',
      \ '_complete_show_original': 1,
      \ '_suggest_suggest_hl': 'Visual',
      \ '_suggest_complete_hl': 'Statement',
      \ '_suggest_show_suggest': 1,
      \ '_suggest_min_length': 0,
      \ '_suggest_space_trigger': 0,
      \ '_suggest_no_trigger': [
          \ '\m^ec\%[ho] ',
          \ '\m^let .*=',
          \ '\m\*\*',
          \ ],
      \ '_suggest_middle_trigger': 0,
      \ '_suggest_jump_complete': 0,
      \ '_suggest_esc_menu': 0,
      \ '_suggest_enter_suggest': 1,
      \ '_suggest_bs_suggest': 0,
      \ '_suggest_enter_search_complete': 0,
      \ '_suggest_tab_longest': 0,
      \ '_suggest_search_profile': 0,
      \ '_suggest_render': 'Cmd2#render#New().WithInsertCursor().WithMenu()',
      \ '_suggest_hlsearch': &hlsearch,
      \ '_suggest_incsearch': &incsearch,
      \ }

if !exists('g:Cmd2_options')
  let g:Cmd2_options = {
        \ }
endif

" mapping cannot start with number as it will be treated as count
let g:Cmd2_default_cmd_mappings = {
      \ }

if !exists('g:Cmd2_cmd_mappings')
  let g:Cmd2_cmd_mappings = {
        \ }
endif

let g:Cmd2_default_mappings = {
      \ }

if !exists('g:Cmd2_mappings')
  let g:Cmd2_mappings = {
        \ }
endif

let g:Cmd2_search_mru = get(g:, 'Cmd2_search_mru', [])
call Cmd2#ext#complete#MakeMRUHash()

call Cmd2#init#Options(g:Cmd2_default_options)
call Cmd2#init#CmdMappings(g:Cmd2_default_cmd_mappings)

if g:Cmd2_preload
  call Cmd2#Autoload()
endif

call Cmd2#module#Register('cmd2', Cmd2#main#Module())
call Cmd2#module#Register('complete', Cmd2#ext#complete#Module())
call Cmd2#module#Register('suggest', Cmd2#ext#suggest#Module())

cmap <Plug>Cmd2 <Plug>(Cmd2)
cnoremap <silent> <expr> <Plug>(Cmd2) getcmdtype() =~ '\v[?:\/]' ? Cmd2#main#Init() . "<C-E><C-U><C-C>:call Cmd2#main#Run()<CR>" : ""
cnoremap <silent> <expr> <Plug>(Cmd2Complete) getcmdtype() =~ '\v[?:\/]' ? Cmd2#main#Init() .
      \ "<C-E><C-U><C-C>:call Cmd2#main#Run('complete')<CR>" : ""
cnoremap <silent> <expr> <Plug>(Cmd2Suggest) getcmdtype() =~ '\v[?:\/]' ? Cmd2#main#Init() .
      \ "<C-E><C-U><C-C>:call Cmd2#main#Run('suggest')<CR>" : ""

nnoremap <silent> <Plug>(Cmd2_hls) :set hls<CR>
nnoremap <silent> <Plug>(Cmd2_nohls) :set nohls<CR>


let g:Cmd2_loaded = 1

let &cpo = s:save_cpo
unlet s:save_cpo

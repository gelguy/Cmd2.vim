let s:save_cpo = &cpo
set cpo&vim

function! Cmd2#util#Autoload()
  " do nothing
endfunction

function! Cmd2#util#GetRelTimeMs(start, end)
  " split to remove leading whitespace
  let reltime = split(reltimestr(reltime(a:start, a:end)))[0]
  " reltimestr format: seconds.microseconds
  " split \D to get microseconds
  " convert to milliseconds
  return split(reltime, '\D')[1] / 1000
endfunction

" hides the cursor so the cursor is hidden when getchar() is called
" saves the old value of &guicursor as g:Cmd2_old_guicursor
" returns the old value
function! Cmd2#util#HideCursor()
  " https://github.com/junegunn/vim-pseudocl/blob/4417db3eb095350594cd6a3e91ec8b78312ef06b/autoload/pseudocl/render.vim#L205
  if exists('&t_ve')
    let s:old_t_ve = &t_ve
    if !empty($CONEMUBUILD)
      set t_ve=[25l
    else
      set t_ve=
    endif
  endif
  if exists('&guicursor')
    let s:Cmd2_old_guicursor = &guicursor
    let hide = Cmd2#util#HideCursorString()
    execute "let &guicursor .= '" . hide . "'"
  endif
endfunction

" creates the string to append to &guicursor
function! Cmd2#util#HideCursorString()
  return ",a:block-None"
endfunction

" resets the value of &guicursor using g:Cmd2_old_guicursor
function! Cmd2#util#ResetGuiCursor()
  if exists('&t_ve') && exists('s:old_t_ve')
    let &t_ve = s:old_t_ve
  endif
  if exists('&guicursor')
    execute "let &guicursor = '" . s:Cmd2_old_guicursor . "'"
  endif
endfunction

" highlights the current cursor position
" has to be called before we enter Cmd2
" as getchar() places the cursor after the current highlight
" for some unknown reason
function! Cmd2#util#BufferCursorHl()
  if !g:Cmd2_buffer_cursor_show
    return
  endif
  call Cmd2#util#ClearBufferCursorHl()
  let curpos = getpos('.')
  let s:Cmd2_buffer_cursor_matchid = matchadd(g:Cmd2_buffer_cursor_hl, '\v%' . curpos[1] . 'l%' . curpos[2] . 'c.')
endfunction

function! Cmd2#util#ClearBufferCursorHl()
  if exists('s:Cmd2_buffer_cursor_matchid') && s:Cmd2_buffer_cursor_matchid >= 0
    call matchdelete(s:Cmd2_buffer_cursor_matchid)
  endif
  let s:Cmd2_buffer_cursor_matchid = -1
endfunction

function! Cmd2#util#HighlightVisual()
  if !exists('s:Cmd2_visual_matchids')
    let s:Cmd2_visual_matchids = []
  endif
  call add(s:Cmd2_visual_matchids, matchadd('Visual', '.\%>''<.*\%<''>..'))
endfunction

function! Cmd2#util#ClearBlinkState()
  let g:Cmd2_blink_state = -1
endfunction

function! Cmd2#util#ClearRemapDepth()
  let g:Cmd2_remap_depth = 0
endfunction

function! Cmd2#util#ClearHighlightVisual()
  if exists('s:Cmd2_visual_matchids')
    while !empty(s:Cmd2_visual_matchids)
      silent! call matchdelete(remove(s:Cmd2_visual_matchids, -1))
    endwhile
  endif
endfunction

" special care must be taken as when Vim enters Command Line from Visual
" and then exits, the cursor is placed at the start of the Visual
" so to restore the cursor the gv command is used
function! Cmd2#util#SaveVisual()
  let vmode = visualmode()
  try
    normal! `<
    let vstart = getpos('.')
  catch /^Vim\%((\a\+)\)\=:E20/
    let vstart = []
  endtry
  try
    normal! `>
    let vend = getpos('.')
  catch /^Vim\%((\a\+)\)\=:E20/
    let vend = []
  endtry
  let selection_save = &selection
  let &selection = 'inclusive'
  execute "normal! gv\<Esc>"
  let vpos = getpos(".")
  let &selection = selection_save
  return [vstart, vend, vpos, vmode]
endfunction

function! Cmd2#util#RestoreVisual(vstart, vend, vpos, vmode)
  if len(a:vstart) && len(a:vend)
    let selection_save = &selection
    let &selection = 'inclusive'
    call setpos(".", a:vstart)
    execute "normal! " . a:vmode
    call setpos(".", a:vend)
    call setpos(".", a:vpos)
    execute "normal! \<Esc>"
    let &selection = selection_save
  endif
endfunction

function! Cmd2#util#FindNode(key, root)
  let current_node = a:root
  let key = a:key
  " split key into multibyte characters
  while !empty(key)
    if key =~ "\<Plug>"
      let char = key[0:2]
      let key = key[3:-1]
    elseif key =~ '\v^[\x80-\xFF]'
      let char = key[0:2]
      let key = key[3:-1]
    else
      let char = key[0]
      let key = key[1:-1]
    endif
    if !Cmd2#tree#NodeHasKey(current_node, char)
      return {}
    else
      let current_node = current_node[char]
    endif
  endwhile
  return current_node
endfunction

function! Cmd2#util#ReselectVisual()
  if g:Cmd2_visual_select
    execute "normal! gv\<Esc>"
  endif
endfunction

function! Cmd2#util#ResetReenter()
  let g:Cmd2_reenter = 0
  let g:Cmd2_reenter_key = ""
endfunction

function! Cmd2#util#SaveCmdHeight()
  let g:Cmd2_old_cmdheight = &cmdheight
endfunction

function! Cmd2#util#ResetCmdHeight()
  let &cmdheight = g:Cmd2_old_cmdheight
endfunction

function! Cmd2#util#SetCmdHeight()
  let menu_height = has_key(g:Cmd2_menu, 'pages') && (len(g:Cmd2_menu.pages) > 0 || g:Cmd2_menu.empty_render)
  call Cmd2#util#SetCmdHeightHelper(menu_height)
endfunction

function! Cmd2#util#SetCmdHeightWithNoMenu()
  call Cmd2#util#SetCmdHeightHelper(0)
endfunction

function! Cmd2#util#SetCmdHeightHelper(menu_height)
  " - 1 to round down, + 1 to include cmd_type, + 1 for extra space to buffer
  let &cmdheight = max([g:Cmd2_old_cmdheight,
        \ (strdisplaywidth(g:Cmd2_pending_cmd[0] . g:Cmd2_temp_output . g:Cmd2_cursor_text . g:Cmd2_pending_cmd[1]) + 1) / &columns
        \ + 1 + a:menu_height])
endfunction

function! Cmd2#util#SaveLaststatus()
  let g:Cmd2_old_laststatus = &laststatus
endfunction

function! Cmd2#util#SetLastStatus()
  if has_key(g:Cmd2_menu, 'pages') && (len(g:Cmd2_menu.pages) > 0 || g:Cmd2_menu.empty_render)
    let &laststatus = 0
  else
    let &laststatus = g:Cmd2_old_laststatus
  endif
endfunction

function! Cmd2#util#ResetLaststatus()
  let &laststatus = g:Cmd2_old_laststatus
endfunction

function! Cmd2#util#SetMore()
  let g:Cmd2_old_more = &more
  set nomore
endfunction

function! Cmd2#util#ResetMore()
  let &more = g:Cmd2_old_more
endfunction

let s:unfeedable = {
      \ "\<C-M>": "\<C-V>\<C-M>",
      \ "\<C-A>": "\<C-V>\<C-A>",
      \ "\<C-[>": "\<C-V>\<C-[>",
      \ "\<C-C>": "\<C-V>\<C-C>",
      \ "\<NL>": "\<C-V>\<NL>",
      \ "\<C-V>": "\<C-V>\<C-V>",
      \ }

function! Cmd2#util#EscapeFeed(keys)
  let result = a:keys
  for key in keys(s:unfeedable)
    let result = substitute(result, key, s:unfeedable[key], 'g')
  endfor
  return result
endfunction

let s:unechoable = {
      \ "\<C-M>": '^M',
      \ "\<NL>": '^@',
      \ "\<C-I>": '^I',
      \ "\<C-V>": '^V',
      \ "\<C-R>": '^R',
      \ }

function! Cmd2#util#EscapeEcho(text)
  let result = a:text
  for key in keys(s:unechoable)
    let result = substitute(result, key, s:unechoable[key], 'g')
  endfor
  return result
endfunction

function! Cmd2#util#IsMenu(string)
  if a:string[0] == '.' || a:string =~ '\m\|'
    return 0
  endif
  let echo = ''
  if a:string =~ '\m\.'
    let cmd = join(split(a:string, '\m\.', 1)[0 : -2], '.')
  else
    let cmd = a:string
  endif
  redir => echo
  try
    execute 'silent menu ' . cmd
  catch
    let echo = ''
  endtry
  redir END
  if len(echo)
    return 1
  endif
  return 0
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo

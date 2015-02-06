let s:save_cpo = &cpo
set cpo&vim

function! cmd2#util#Autoload()
  " do nothing
endfunction

function! cmd2#util#GetRelTimeMs(start, end)
  " split to remove leading whitespace
  let reltime = split(reltimestr(reltime(a:start, a:end)))[0]
  " reltimestr format: seconds.microseconds
  " split \D to get microseconds
  " convert to milliseconds
  return split(reltime, '\D')[1] / 1000
endfunction

" hides the cursor so the cursor is hidden when getchar() is called
" saves the old value of &guicursor as g:cmd2_old_guicursor
" returns the old value
function! cmd2#util#HideCursor()
  " https://github.com/junegunn/vim-pseudocl/blob/4417db3eb095350594cd6a3e91ec8b78312ef06b/autoload/pseudocl/render.vim#L205
  if exists('&t_ve')
    let s:old_t_ve = &t_ve
    set t_ve=
  endif
  if exists('&guicursor')
    let s:cmd2_old_guicursor = &guicursor
    let hide = cmd2#util#HideCursorString()
    execute "let &guicursor .= '" . hide . "'"
  endif
endfunction

" creates the string to append to &guicursor
function! cmd2#util#HideCursorString()
  return ",a:block-None"
endfunction

" resets the value of &guicursor using g:cmd2_old_guicursor
function! cmd2#util#ResetGuiCursor()
  if exists('&t_ve') && exists('s:old_t_ve')
    let &t_ve = s:old_t_ve
  endif
  if exists('&guicursor')
    execute "let &guicursor = '" . s:cmd2_old_guicursor . "'"
  endif
endfunction

" highlights the current cursor position
" has to be called before we enter Cmd2
" as getchar() places the cursor after the current highlight
" for some unknown reason
function! cmd2#util#BufferCursorHl()
  if !g:cmd2_buffer_cursor_show
    return
  endif
  call cmd2#util#ClearBufferCursorHl()
  let curpos = getpos('.')
  let s:cmd2_buffer_cursor_matchid = matchadd(g:cmd2_buffer_cursor_hl, '\v%' . curpos[1] . 'l%' . curpos[2] . 'c.')
endfunction

function! cmd2#util#ClearBufferCursorHl()
  if exists('s:cmd2_buffer_cursor_matchid') && s:cmd2_buffer_cursor_matchid >= 0
    call matchdelete(s:cmd2_buffer_cursor_matchid)
  endif
  let s:cmd2_buffer_cursor_matchid = -1
endfunction

function! cmd2#util#HighlightVisual()
  if !exists('s:cmd2_visual_matchids')
    let s:cmd2_visual_matchids = []
  endif
  call add(s:cmd2_visual_matchids, matchadd('Visual', '.\%>''<.*\%<''>..'))
endfunction

function! cmd2#util#ClearBlinkState()
  let g:cmd2_blink_state = -1
endfunction

function! cmd2#util#ClearRemapDepth()
  let g:cmd2_remap_depth = 0
endfunction

function! cmd2#util#ClearHighlightVisual()
  if exists('s:cmd2_visual_matchids')
    while !empty(s:cmd2_visual_matchids)
      silent! call matchdelete(remove(s:cmd2_visual_matchids, -1))
    endwhile
  endif
endfunction

" special care must be taken as when Vim enters Command Line from Visual
" and then exits, the cursor is placed at the start of the Visual
" so to restore the cursor the gv command is used
function! cmd2#util#SaveVisual()
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

function! cmd2#util#RestoreVisual(vstart, vend, vpos, vmode)
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

function! cmd2#util#FindNode(key, root)
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
    if !cmd2#tree#NodeHasKey(current_node, char)
      return {}
    else
      let current_node = current_node[char]
    endif
  endwhile
  return current_node
endfunction

function! cmd2#util#ReselectVisual()
  if g:cmd2_visual_select
    execute "normal! gv\<Esc>"
  endif
endfunction

function! cmd2#util#ResetReenter()
  let g:cmd2_reenter = 0
  let g:cmd2_reenter_key = ""
endfunction

function! cmd2#util#ResetCursorOffset()
  let g:cmd2_cursor_offset = 0
endfunction

function! cmd2#util#SaveCmdHeight()
  let g:cmd2_old_cmdheight = &cmdheight
endfunction

function! cmd2#util#ResetCmdHeight()
  let &cmdheight = g:cmd2_old_cmdheight
endfunction

function! cmd2#util#SetCmdHeight()
  let menu_height = has_key(g:cmd2_menu, 'pages') && len(g:cmd2_menu.pages)
  " - 1 to round down, + 1 to include cmd_type, + 1 for extra space to buffer
  let &cmdheight = max([g:cmd2_old_cmdheight,
        \ (strdisplaywidth(g:cmd2_pending_cmd[0] . g:cmd2_temp_output . g:cmd2_cursor_text . g:cmd2_pending_cmd[1]) + 1) / &columns
        \ + 1 + menu_height])
endfunction

function! cmd2#util#SaveLaststatus()
  let g:cmd2_old_laststatus = &laststatus
endfunction

function! cmd2#util#SetLastStatus()
  if has_key(g:cmd2_menu, 'pages') && len(g:cmd2_menu.pages) > 0
    let &laststatus = 0
  else
    let &laststatus = g:cmd2_old_laststatus
  endif
endfunction

function! cmd2#util#ResetLaststatus()
  let &laststatus = g:cmd2_old_laststatus
endfunction

function! cmd2#util#SetMore()
  let g:cmd2_old_more = &more
  set nomore
endfunction

function! cmd2#util#ResetMore()
  let &more = g:cmd2_old_more
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo

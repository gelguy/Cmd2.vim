let s:save_cpo = &cpo
set cpo&vim

function! cmd2#main#Autoload()
  " do nothing
endfunction

" to be used with <C-\>e to get current cmdline state
" does the preparation for entering Cmd2 mode
" - saves current cmdline and position
" - modifies the gui cursor
" - does the simulation of visual mode if visual mode is detected
function! cmd2#main#Init()
  let cmd = getcmdline()
  if cmd =~ '\M^''<,''>' ? 1 : 0
    let g:cmd2_visual_select = 1
    call cmd2#util#HighlightVisual()
  else
    let g:cmd2_visual_select = 0
  endif
  let g:cmd2_cursor_pos = getcmdpos()
  let pos = g:cmd2_cursor_pos
  let s:cmd2_cmd_type = getcmdtype()
  let g:cmd2_pending_cmd = [cmd[(pos == 1 ? -1 : 0):(pos > 1 ? pos - 2 : pos - 1)],
        \ cmd[(pos - 1):-1]
        \ ]
  silent! call cmd2#util#HideCursor()
endfunction

function! cmd2#main#Run()
  try
    call cmd2#main#PreRun()
    call cmd2#main#Loop()
  catch /^Vim:Interrupt$/
    let g:cmd2_output = ""
  finally
    call cmd2#main#PostRun()
  endtry
  redraw
  call cmd2#main#FeedCmdLine()
  call cmd2#util#ReselectVisual()
  call cmd2#main#Reenter()
endfunction

function! cmd2#main#PreRun()
  call cmd2#util#ReselectVisual()
  call cmd2#util#ResetReenter()
  call cmd2#util#ResetCursorOffset()
  call cmd2#util#BufferCursorHl()
  call cmd2#util#SetCmdHeight()
  call cmd2#util#SetMore()
endfunction

function! cmd2#main#PostRun()
  call cmd2#util#ResetGuiCursor()
  call cmd2#util#ClearBufferCursorHl()
  call cmd2#util#ClearHighlightVisual()
  call cmd2#util#ClearBlinkState()
  call cmd2#util#ClearRemapDepth()
  call cmd2#util#ResetCmdHeight()
  call cmd2#util#ResetMore()
endfunction

function! cmd2#main#Loop()
  let g:cmd2_output = ""
  let start_time = reltime()
  let current_time = start_time
  let current_node = g:cmd2_mapping_tree
  let ccount = 0
  let timeout_started = 0
  while 1
    call cmd2#render#Render(g:cmd2_pending_cmd, s:cmd2_cmd_type, start_time, current_time)
    let input = cmd2#main#Getchar(0)
    if type(input) != type(0)
      " if timeout_started, non-digit key has been pressed so we stop count
      if input =~ '\v^\d$' && !timeout_started
        let ccount = cmd2#main#HandleInputNum(input, ccount)
      else
        let [current_node, stopped] = cmd2#main#HandleInputChar(input, current_node)
        if len(keys(current_node)) == 1 || stopped
          " node only has value or stopped issued
          break
        else
            let timeout_started = 1
            let timeout_start_time = reltime()
        endif
      endif
    endif
    let current_time = reltime()
    if timeout_started &&
          \ cmd2#util#GetRelTimeMs(timeout_start_time, current_time) >= g:cmd2_timeoutlen
      break
    endif
    execute "sleep " . g:cmd2_loop_refresh_rate . "m"
  endwhile
  call cmd2#commands#DoMapping(current_node, ccount)
endfunction

" https://github.com/haya14busa/incsearch.vim/blob/392adbfaa4343f0b99c5b90e38470e88e44c5ec3/autoload/vital/_incsearch/Over/Input.vim#L6
function! cmd2#main#Getchar(...)
  let mode = get(a:, 1, 0)
  while 1
    try
      let char = call("getchar", a:000)
    catch /\v^Vim\:Interrupt$/
      let char = 3 " <C-c>
    endtry
    " Workaround for the <expr> mappings
    if string(char) !=# '\v^[\x80-\xFF]'
      return mode == 1 ? !!char
            \ : mode == 0 && string(char) == '0' ? 0
            \ : type(char) == type(0) ? nr2char(char) : char
    endif
  endwhile
endfunction

function! cmd2#main#HandleInputChar(input, node)
  if has_key(a:node, a:input)
    return [a:node[a:input], 0]
  else
    return [a:node, 1]
  endif
endfunction

function! cmd2#main#HandleInputNum(input, count)
  return a:count * 10 + a:input
endfunction

function! cmd2#main#FeedCmdLine()
  let cmd = g:cmd2_pending_cmd
  call feedkeys(s:cmd2_cmd_type . "\<C-U>". cmd[0] . g:cmd2_output . cmd[1], 'n')
  " reposition cursor
  let cmd2 = cmd[0] . g:cmd2_output . cmd[1]
  call feedkeys("\<C-B>", 'n')
  " -1 since cmd2_cursor_pos includes the prompt char
  let offset = strlen(g:cmd2_output) + g:cmd2_cursor_pos - 1
  let display_chars = offset > 0 ? strwidth(cmd2[0 : offset - 1]) : 0
  if strlen(cmd2) == offset
    " to position after last character
    let display_chars += 1
  endif
  let right_times = repeat("\<Right>", display_chars)
  call feedkeys(right_times, 'n')
endfunction

function! cmd2#main#Reenter()
  if g:cmd2_reenter
    call feedkeys("\<Plug>Cmd2", 'm')
    call feedkeys(g:cmd2_reenter_key, 'm')
  endif
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo

let s:save_cpo = &cpo
set cpo&vim

function! cmd2#render#Autoload()
  " do nothing
endfunction

function! cmd2#render#Main(state)
  call cmd2#render#Render(g:cmd2_pending_cmd, g:cmd2_cmd_type, a:state.start_time, a:state.current_time)
endfunction

" renders the cmdline through echo
function! cmd2#render#Render(cmd, type, start_time, current_time)
  let blink = g:cmd2_cursor_blink ?
        \ cmd2#render#GetCursorBlink(a:start_time, a:current_time)
        \ : 1
  if g:cmd2_blink_state == blink
    return
  else
    redraw
    " https://github.com/haya14busa/incsearch.vim/blob/master/autoload/vital/_incsearch/Over/Commandline/Modules/Redraw.vim#L38
    execute "normal! :"
    let g:cmd2_blink_state = blink
    call cmd2#render#CmdLine(a:cmd, a:type, blink)
  endif
endfunction

let g:cmd2_blink_state = -1

" renders the cmdline
function! cmd2#render#CmdLine(cmd, type, blink)
  try
    let cmd = a:cmd
    echo a:type
    call cmd2#render#RenderSplit(cmd[0], g:cmd2_snippet_cursor)
    if a:blink
      execute "echohl" g:cmd2_cursor_hl
    endif
    execute "echon '" . g:cmd2_cursor_text . "'"
    echohl None
    call cmd2#render#RenderSplit(cmd[1], g:cmd2_snippet_cursor)
  finally
    echohl None
  endtry
endfunction

function! cmd2#render#RenderSplit(cmd, split)
  let splitcmd = split(a:cmd, a:split, 1)
  echon splitcmd[0]
  let i = 1
  while i < len(splitcmd)
    execute "echohl " . g:cmd2_snippet_cursor_hl
    execute "echon '" . g:cmd2_snippet_cursor . "'"
    echohl None
    echon splitcmd[i]
    let i += 1
  endwhile
endfunction

function! cmd2#render#GetCursorBlink(start, current)
  let ms = cmd2#util#GetRelTimeMs(a:start, a:current)
  if ms < g:cmd2_cursor_blinkwait
    return 1
  endif
  let interval = fmod(ms - g:cmd2_cursor_blinkwait, g:cmd2_cursor_blinkon + g:cmd2_cursor_blinkoff)
  if interval < g:cmd2_cursor_blinkoff
    return 0
  else
    return 1
  endif
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo

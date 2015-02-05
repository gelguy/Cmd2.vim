let s:save_cpo = &cpo
set cpo&vim

function! cmd2#render#Autoload()
  " do nothing
endfunction

function! cmd2#render#Main(state)
  if cmd2#render#CheckBlink(a:state)
    redraw
    " https://github.com/haya14busa/incsearch.vim/blob/master/autoload/vital/_incsearch/Over/Commandline/Modules/Redraw.vim#L38
    execute "normal! :"
    let result = cmd2#render#PrepareCmdLine(g:cmd2_blink_state)
    call cmd2#render#Render(result)
  endif
endfunction

function! cmd2#render#PrepareCmdLine(blink)
  let result = [{'text': g:cmd2_cmd_type}]
  let result += cmd2#render#SplitSnippet(g:cmd2_pending_cmd[0], g:cmd2_snippet_cursor)
  if a:blink
    call add(result, {'text': g:cmd2_cursor_text, 'hl': g:cmd2_cursor_hl})
  else
    call add(result, {'text': g:cmd2_cursor_text})
  endif
  let result += cmd2#render#SplitSnippet(g:cmd2_pending_cmd[1], g:cmd2_snippet_cursor)
  return result
endfunction

function! cmd2#render#Render(list)
  try
    for block in a:list
      let hl = get(block, 'hl', 'None')
      execute "echohl" hl
      echon block.text
    endfor
  finally
    echohl None
  endtry
endfunction

let g:cmd2_blink_state = -1

" renders the cmdline through echo
function! cmd2#render#CheckBlink(state)
  let blink = g:cmd2_cursor_blink ?
        \ cmd2#render#GetCursorBlink(a:state.start_time, a:state.current_time)
        \ : 1
  if g:cmd2_blink_state == blink
    return 0
  else
    let g:cmd2_blink_state = blink
    return 1
  endif
endfunction

function! cmd2#render#SplitSnippet(cmd, split)
  let result = []
  let splitcmd = split(a:cmd, a:split, 1)
  call add(result, {'text': splitcmd[0]})
  let i = 1
  while i < len(splitcmd)
    call add(result, {'text': g:cmd2_snippet_cursor, 'hl': g:cmd2_snippet_cursor_hl})
    call add(result, {'text': splitcmd[i]})
    let i += 1
  endwhile
  return result
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

let s:save_cpo = &cpo
set cpo&vim

function! Cmd2#render#Autoload()
  " do nothing
endfunction

function! Cmd2#render#Prepare(state)
  let CmdLine = function('Cmd2#render#PrepareCmdLineWithMenu')
  call Cmd2#render#Main(CmdLine, a:state)
endfunction

function! Cmd2#render#Main(cmd, state)
  if Cmd2#render#CheckBlink(a:state) || a:state.force_render
    call Cmd2#util#SetCmdHeight()
    call Cmd2#util#SetLastStatus()
    if &cmdheight > g:Cmd2_old_cmdheight
      redraw
    endif
    " https://github.com/haya14busa/incsearch.vim/blob/master/autoload/vital/_incsearch/Over/Commandline/Modules/Redraw.vim#L38
    execute "normal! :"
    let result = call(a:cmd, [a:state])
    call Cmd2#render#Render(result)
  endif
  if a:state.force_render == 1
    let a:state.force_render = 0
  endif
endfunction

function! Cmd2#render#PrepareCmdLine(state)
  let result = []
  let result += [{'text': g:Cmd2_cmd_type}]
  let result += Cmd2#render#SplitSnippet(g:Cmd2_pending_cmd[0], g:Cmd2_snippet_cursor)
  let result += [{'text': g:Cmd2_temp_output}]
  if g:Cmd2_blink_state
    call add(result, {'text': g:Cmd2_cursor_text, 'hl': g:Cmd2_cursor_hl})
  else
    call add(result, {'text': g:Cmd2_cursor_text})
  endif
  let result += Cmd2#render#SplitSnippet(g:Cmd2_pending_cmd[1], g:Cmd2_snippet_cursor)
  return result
endfunction

function! Cmd2#render#PrepareCmdLineWithMenu(state)
  let result = []
  if has_key(g:Cmd2_menu, 'pages') && len(g:Cmd2_menu.pages) > 0
    let menu = Cmd2#menu#PrepareMenuLineFromMenu(g:Cmd2_menu)
    let result += menu
  endif
  let result += Cmd2#render#PrepareCmdLine(a:state)
  return result
endfunction

function! Cmd2#render#Render(list)
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

" renders the cmdline through echo
function! Cmd2#render#CheckBlink(state)
  let blink = g:Cmd2_cursor_blink ?
        \ Cmd2#render#GetCursorBlink(a:state.start_time, a:state.current_time)
        \ : 1
  if g:Cmd2_blink_state == blink
    return 0
  else
    let g:Cmd2_blink_state = blink
    return 1
  endif
endfunction

function! Cmd2#render#SplitSnippet(cmd, split)
  let result = []
  let splitcmd = split(a:cmd, a:split, 1)
  call add(result, {'text': splitcmd[0]})
  let i = 1
  while i < len(splitcmd)
    call add(result, {'text': g:Cmd2_snippet_cursor, 'hl': g:Cmd2_snippet_cursor_hl})
    call add(result, {'text': splitcmd[i]})
    let i += 1
  endwhile
  return result
endfunction

function! Cmd2#render#GetCursorBlink(start, current)
  let ms = Cmd2#util#GetRelTimeMs(a:start, a:current)
  if ms < g:Cmd2_cursor_blinkwait
    return 1
  endif
  let interval = fmod(ms - g:Cmd2_cursor_blinkwait, g:Cmd2_cursor_blinkon + g:Cmd2_cursor_blinkoff)
  if interval < g:Cmd2_cursor_blinkoff
    return 0
  else
    return 1
  endif
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo

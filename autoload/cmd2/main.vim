let s:save_cpo = &cpo
set cpo&vim

function! cmd2#main#Autoload()
  " do nothing
endfunction

function! cmd2#main#Init()
  let cmd = getcmdline()
  if cmd =~ '\M^''<,''>' ? 1 : 0
    let g:cmd2_visual_select = 1
    call cmd2#util#HighlightVisual()
  else
    let g:cmd2_visual_select = 0
  endif
  let pos = getcmdpos()
  let g:cmd2_cmd_type = getcmdtype()
  let g:cmd2_pending_cmd = [cmd[(pos == 1 ? -1 : 0):(pos > 1 ? pos - 2 : pos - 1)],
        \ cmd[(pos - 1):-1]
        \ ]
  silent! call cmd2#util#HideCursor()
endfunction

function! cmd2#main#Run()
  try
    call cmd2#main#PreRun()
    let args = {
          \ 'render': function('cmd2#render#Prepare'),
          \ 'handle': function('cmd2#handle#Handle'),
          \ 'finish': function('cmd2#commands#DoMapping'),
          \ 'state': {},
          \ }
    call cmd2#loop#Init(args)
  catch /^Vim:Interrupt$/
    let g:cmd2_output = ""
  finally
    call cmd2#main#PostRun()
  endtry
  redraw
  call cmd2#main#FeedCmdLine()
  call cmd2#util#ReselectVisual()
  call cmd2#main#Reenter()
  call cmd2#main#LeftoverKey()
endfunction

function! cmd2#main#PreRun()
  call cmd2#util#ReselectVisual()
  call cmd2#util#ResetReenter()
  call cmd2#util#BufferCursorHl()
  call cmd2#util#SaveCmdHeight()
  call cmd2#util#SetMore()
  call cmd2#util#SaveLaststatus()
  let g:cmd2_menu = {}
  let g:cmd2_temp_output = ""
  let g:cmd2_output = ""
  let g:cmd2_leftover_key = ""
  let g:cmd2_blink_state = -1
endfunction

function! cmd2#main#PostRun()
  call cmd2#util#ResetGuiCursor()
  call cmd2#util#ClearBufferCursorHl()
  call cmd2#util#ClearHighlightVisual()
  call cmd2#util#ClearBlinkState()
  call cmd2#util#ClearRemapDepth()
  call cmd2#util#ResetCmdHeight()
  call cmd2#util#ResetMore()
  call cmd2#util#ResetLaststatus()
endfunction

function! cmd2#main#FeedCmdLine()
  let cmd = g:cmd2_pending_cmd
  call feedkeys(g:cmd2_cmd_type . "\<C-U>". cmd[0] . g:cmd2_output, 'n')
  let len = strlen(substitute(cmd[1], ".", "x", "g"))
  let i = 0
  while i < len
    let char = matchstr(cmd[1], ".", byteidx(cmd[1], i))
    call feedkeys(char, 'n')
    let i += 1
  endwhile
  call feedkeys("\<C-E>", 'n')
  let left = repeat("\<Left>", len)
  call feedkeys(left, 'n')
endfunction

function! cmd2#main#Reenter()
  if g:cmd2_reenter
    call feedkeys("\<Plug>Cmd2", 'm')
    call feedkeys(g:cmd2_reenter_key, 'm')
  endif
endfunction

function! cmd2#main#LeftoverKey()
  if len(g:cmd2_leftover_key)
    call feedkeys(g:cmd2_leftover_key, 'm')
  endif
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo

let s:save_cpo = &cpo
set cpo&vim

function! Cmd2#main#Autoload()
  " do nothing
endfunction

function! Cmd2#main#Init()
  let cmd = getcmdline()
  if cmd =~ '\M^''<,''>' ? 1 : 0
    let g:Cmd2_visual_select = 1
    call Cmd2#util#HighlightVisual()
  else
    let g:Cmd2_visual_select = 0
  endif
  let pos = getcmdpos()
  let g:Cmd2_cmd_type = getcmdtype()
  let g:Cmd2_pending_cmd = [cmd[(pos == 1 ? -1 : 0):(pos > 1 ? pos - 2 : pos - 1)],
        \ cmd[(pos - 1):-1]
        \ ]
  silent! call Cmd2#util#HideCursor()
endfunction

let s:Module = copy(Cmd2#module#Module())

function! s:Module.New()
  let cmd2 = copy(self)
  let args = {
        \ 'render': Cmd2#render#New(),
        \ 'handle': Cmd2#handle#New(),
        \ 'finish': Cmd2#commands#New(),
        \ 'loop': Cmd2#loop#New(),
        \ 'state': {},
        \ }
  call cmd2.Init(args)
  return cmd2
endfunction

function! s:Module.Run()
  call feedkeys(g:Cmd2_leftover_key)
  let g:Cmd2_leftover_key = ""
  call self.loop.Run()
  call self.finish.Run()
endfunction

function! Cmd2#main#Module()
  return s:Module
endfunction

function! Cmd2#main#New()
  return Cmd2#main#Module().New()
endfunction

function! Cmd2#main#Run(...)
  try
    call Cmd2#main#PreRun()
    if a:0
      let name = a:1
    else
      let name = 'cmd2'
    endif
    let module = g:Cmd2_modules[name].New()
    call module.Run()
  catch /^Vim:Interrupt$/
    let g:Cmd2_output = ""
  finally
    call Cmd2#main#PostRun()
  endtry
  redraw
  " since feedkeys appends to end of typeahead
  " we get the remaining keys first then feed the cmdline again
  call Cmd2#main#GetRemainderKeys()
  call Cmd2#main#FeedCmdLine()
  call Cmd2#util#ReselectVisual()
  call Cmd2#main#Reenter()
  call Cmd2#main#LeftoverKey()
  call Cmd2#main#RemainderKeys()
  " clear cmdline
  execute "normal! :"
endfunction

function! Cmd2#main#PreRun()
  call Cmd2#util#ReselectVisual()
  call Cmd2#util#ResetReenter()
  call Cmd2#util#BufferCursorHl()
  call Cmd2#util#SaveCmdHeight()
  call Cmd2#util#SetMore()
  call Cmd2#util#SaveLaststatus()
  let g:Cmd2_menu = Cmd2#menu#New([])
  let g:Cmd2_temp_output = ""
  let g:Cmd2_post_temp_output = ""
  let g:Cmd2_output = ""
  let g:Cmd2_leftover_key = ""
  let g:Cmd2_blink_state = -1
  let g:Cmd2_remainder_keys = ""
endfunction

function! Cmd2#main#PostRun()
  call Cmd2#util#ResetGuiCursor()
  call Cmd2#util#ClearBufferCursorHl()
  call Cmd2#util#ClearHighlightVisual()
  call Cmd2#util#ClearBlinkState()
  call Cmd2#util#ClearRemapDepth()
  call Cmd2#util#ResetCmdHeight()
  call Cmd2#util#ResetMore()
  call Cmd2#util#ResetLaststatus()
endfunction

function! Cmd2#main#GetRemainderKeys()
  let remainder = ""
  while 1
    let char = getchar(0)
    if type(char) == 0 && string(char) == '0'
      break
    else
      let char = type(char) == type(0) ? nr2char(char) : char
      let remainder .= char
    endif
  endwhile
  let g:Cmd2_remainder_keys = remainder
endfunction

function! Cmd2#main#FeedCmdLine()
  if get(g:, 'Cmd2_feed_cmdline', 1)
    let cmd = g:Cmd2_pending_cmd
    call feedkeys(g:Cmd2_cmd_type . "\<C-U>". Cmd2#util#EscapeFeed(cmd[0] . g:Cmd2_output), 'n')
    let len = strlen(substitute(cmd[1], ".", "x", "g"))
    let i = 0
    while i < len
      let char = matchstr(cmd[1], ".", byteidx(cmd[1], i))
      call feedkeys(Cmd2#util#EscapeFeed(char), 'n')
      let i += 1
    endwhile
    call feedkeys("\<C-E>", 'n')
    let left = repeat("\<Left>", len)
    call feedkeys(left, 'n')
  endif
  if exists('g:Cmd2_feed_cmdline')
    unlet g:Cmd2_feed_cmdline
  endif
endfunction

function! Cmd2#main#Reenter()
  if g:Cmd2_reenter
    call feedkeys("\<Plug>Cmd2", 'm')
    call feedkeys(g:Cmd2_reenter_key, 'm')
  endif
endfunction

function! Cmd2#main#LeftoverKey()
  if len(g:Cmd2_leftover_key)
    if g:Cmd2_leftover_key == "\<Esc>"
      let g:Cmd2_leftover_key = "\<C-C>"
    elseif g:Cmd2_leftover_key == "\<CR>" && g:Cmd2_cmd_type == ':'
      call histadd(g:Cmd2_cmd_type, g:Cmd2_pending_cmd[0] . g:Cmd2_output . g:Cmd2_pending_cmd[1])
    endif
    call feedkeys(g:Cmd2_leftover_key, 'm')
  endif
endfunction

function! Cmd2#main#RemainderKeys()
  if len(g:Cmd2_remainder_keys)
    call feedkeys(g:Cmd2_remainder_keys, 'm')
  endif
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo

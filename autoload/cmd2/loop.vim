let s:save_cpo = &cpo
set cpo&vim

function! Cmd2#loop#Autoload()
  " do nothing
endfunction

function! Cmd2#loop#Init(args)
  let result = Cmd2#loop#Loop(a:args.render, a:args.handle, a:args.state)
  call call(a:args.finish, [result])
endfunction

function! Cmd2#loop#Loop(render, handle, state)
  let state = a:state
  call Cmd2#loop#PrepareState(state)
  while 1
    call call(a:render, [a:state])
    let input = Cmd2#loop#Getchar(0)
    if type(input) != type(0)
      call call(a:handle, [input, state])
      if state.start_timeout
        let state.timeout_started = 1
        let state.timeout_start_time = reltime()
      endif
    endif
    let state.current_time = reltime()
    if state.stopped || state.timeout_started &&
          \ Cmd2#util#GetRelTimeMs(state.timeout_start_time, state.current_time) >= g:Cmd2_timeoutlen
      break
    endif
    if g:Cmd2_loop_sleep
      execute "sleep " . g:Cmd2_loop_sleep . "m"
    endif
  endwhile
  return state.result
endfunction

function! Cmd2#loop#PrepareState(state)
  let reltime = reltime()
  let default = {
        \ 'force_render' : 0,
        \ 'result' : 0,
        \ 'start_time' : reltime,
        \ 'current_time' : reltime,
        \ 'start_timeout' : 0,
        \ 'stopped' : 0,
        \ 'timeout_started' : 0,
        \ }
  call extend(a:state, default, 'keep')
endfunction

" https://github.com/haya14busa/incsearch.vim/blob/392adbfaa4343f0b99c5b90e38470e88e44c5ec3/autoload/vital/_incsearch/Over/Input.vim#L6
function! Cmd2#loop#Getchar(...)
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

let &cpo = s:save_cpo
unlet s:save_cpo

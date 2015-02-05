let s:save_cpo = &cpo
set cpo&vim

function! cmd2#loop#Autoload()
  " do nothing
endfunction

function! cmd2#loop#Init(args)
  let result = cmd2#loop#Loop(a:args.render, a:args.handle)
  call call(a:args.finish, [result])
endfunction

function! cmd2#loop#Loop(render, handle)
  let state = {}
  call cmd2#loop#PrepareState(state)
  while 1
    call call(a:render, [state])
    let input = cmd2#loop#Getchar(0)
    if type(input) != type(0)
      call call(a:handle, [input, state])
      if state.start_timeout
        let state.timeout_started = 1
        let state.timeout_start_time = reltime()
      endif
    endif
    let state.current_time = reltime()
    if state.stopped || state.timeout_started &&
          \ cmd2#util#GetRelTimeMs(state.timeout_start_time, state.current_time) >= g:cmd2_timeoutlen
      break
    endif
    execute "sleep " . g:cmd2_loop_refresh_rate . "m"
  endwhile
  return state.result
endfunction

function! cmd2#loop#PrepareState(state)
  let a:state.force_render = 0
  let a:state.result = 0
  let a:state.start_time = reltime()
  let a:state.current_time = a:state.start_time
  let a:state.start_timeout = 0
  let a:state.stopped = 0
  let a:state.timeout_started = 0
endfunction

" https://github.com/haya14busa/incsearch.vim/blob/392adbfaa4343f0b99c5b90e38470e88e44c5ec3/autoload/vital/_incsearch/Over/Input.vim#L6
function! cmd2#loop#Getchar(...)
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

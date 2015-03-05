let s:save_cpo = &cpo
set cpo&vim

function! Cmd2#loop#Autoload()
  " do nothing
endfunction

let s:Loop = {}

function! Cmd2#loop#New()
  let loop = copy(s:Loop)
  return loop
endfunction

function! s:Loop.Module(module)
  let self.module = a:module
  return self
endfunction

function! s:Loop.Run()
  let state = self.module.state
  while 1
    call self.module.Render()
    let input = self.Getchar(0)
    if type(input) != type(0)
      call self.module.Handle(input)
      let state.skip_sleep = 1
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
    if g:Cmd2_loop_sleep && !state.skip_sleep
      execute "sleep " . g:Cmd2_loop_sleep . "m"
    endif
    if state.skip_sleep == 1
      let state.skip_sleep = 0
    endif
  endwhile
endfunction

" https://github.com/haya14busa/incsearch.vim/blob/392adbfaa4343f0b99c5b90e38470e88e44c5ec3/autoload/vital/_incsearch/Over/Input.vim#L6
function! s:Loop.Getchar(...)
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

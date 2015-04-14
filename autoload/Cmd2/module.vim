let s:save_cpo = &cpo
set cpo&vim

function! Cmd2#module#Autoload()
  " do nothing
endfunction

let s:Module = {}

function! Cmd2#module#Module()
  return s:Module
endfunction

function! Cmd2#module#New(args)
  let m = Cmd2#module#Module().New(a:args)
  return m.Init(a:args)
endfunction

function! s:Module.New()
  let m = copy(self)
  return m
endfunction

function! s:Module.Init(args)
  let self.loop = a:args.loop.Module(self)
  let self.handle = a:args.handle.Module(self)
  let self.render = a:args.render.Module(self)
  let self.finish = a:args.finish.Module(self)
  let self.state = self.PrepareState(a:args.state)
  return self
endfunction

function! s:Module.PrepareState(state)
  let reltime = reltime()
  let default = {
        \ 'force_render' : 0,
        \ 'start_time' : reltime,
        \ 'current_time' : reltime,
        \ 'start_timeout' : 0,
        \ 'stopped' : 0,
        \ 'timeout_started' : 0,
        \ 'skip_sleep' : 0,
        \ 'input_string': '',
        \ 'result': {},
        \ }
  return extend(a:state, default, 'keep')
endfunction

function! s:Module.Run()
  call self.loop.Run()
  call self.finish.Run()
endfunction

function! s:Module.Render()
  call self.render.Run()
endfunction

function! s:Module.Handle(input)
  call self.handle.Run(a:input)
endfunction

function! Cmd2#module#Register(name, module)
  if !exists('g:Cmd2_modules')
    let g:Cmd2_modules = {}
  endif
  let g:Cmd2_modules[a:name] = a:module
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo

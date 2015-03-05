let s:save_cpo = &cpo
set cpo&vim

function! Cmd2#handle#Autoload()
  " do nothing
endfunction

let s:Handle = {}

function! Cmd2#handle#New()
  let handle = copy(s:Handle)
  return handle
endfunction

function! s:Handle.Module(module)
  let self.module = a:module
  return self
endfunction

function! s:Handle.Run(input)
  let state = self.module.state
  call self.PrepareState()
  if a:input =~ '\v^\d$' && !state.timeout_started
    let state.ccount = self.InputNum(a:input)
  else
    let [state.current_node, stopped] = self.InputChar(a:input)
    let state.stopped = stopped || len(keys(state.current_node)) == 1
    let state.start_timeout = 1
    if len(state.current_node.value) == 0 || stopped
      let g:Cmd2_leftover_key .= a:input
    else
      let g:Cmd2_leftover_key = ''
    endif
  endif
  let state.result = {'node': state.current_node, 'ccount': state.ccount}
endfunction

function! s:Handle.PrepareState()
  let state = self.module.state
  let default = {
        \ 'current_node': g:Cmd2_mapping_tree,
        \ 'ccount': 0,
        \ 'start_timeout': 0,
        \ 'stopped': 0,
        \ }
  call extend(state, default, 'keep')
endfunction

function! s:Handle.InputChar(input)
  let node = self.module.state.current_node
  if has_key(node, a:input)
    return [node[a:input], 0]
  else
    return [node, 1]
  endif
endfunction

function! s:Handle.InputNum(input)
  let ccount = self.module.state.ccount
  return ccount * 10 + a:input
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo

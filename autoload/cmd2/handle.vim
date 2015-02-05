let s:save_cpo = &cpo
set cpo&vim

function! cmd2#handle#Autoload()
  " do nothing
endfunction

function! cmd2#handle#Handle(input, state)
  call cmd2#handle#PrepareState(a:state)
  if a:input =~ '\v^\d$' && !a:state.timeout_started
    let a:state.ccount = cmd2#handle#HandleInputNum(a:input, a:state.ccount)
  else
    let [a:state.current_node, stopped] = cmd2#handle#HandleInputChar(a:input, a:state.current_node)
    let a:state.stopped = stopped || len(keys(a:state.current_node)) == 1
    let a:state.start_timeout = 1
  endif
  let a:state.result = {'node': a:state.current_node, 'ccount': a:state.ccount}
endfunction

function! cmd2#handle#PrepareState(state)
  let a:state.current_node = get(a:state, 'current_node', g:cmd2_mapping_tree)
  let a:state.ccount = get(a:state, 'ccount', 0)
  let a:state.stopped = get(a:state, 'stopped', 0)
  let a:state.start_timeout = get(a:state, 'start_timeout', 0)
endfunction

function! cmd2#handle#HandleInputChar(input, node)
  if has_key(a:node, a:input)
    return [a:node[a:input], 0]
  else
    return [a:node, 1]
  endif
endfunction

function! cmd2#handle#HandleInputNum(input, count)
  return a:count * 10 + a:input
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo

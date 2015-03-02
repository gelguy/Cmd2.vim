let s:save_cpo = &cpo
set cpo&vim

function! Cmd2#handle#Autoload()
  " do nothing
endfunction

function! Cmd2#handle#Handle(input, state)
  call Cmd2#handle#PrepareState(a:state)
  let a:state.input_string .= a:input
  if a:input =~ '\v^\d$' && !a:state.timeout_started
    let a:state.ccount = Cmd2#handle#HandleInputNum(a:input, a:state.ccount)
  else
    let [a:state.current_node, stopped] = Cmd2#handle#HandleInputChar(a:input, a:state.current_node)
    let a:state.stopped = stopped || len(keys(a:state.current_node)) == 1
    let a:state.start_timeout = 1
  endif
  let a:state.result = {'node': a:state.current_node, 'ccount': a:state.ccount}
  if len(a:state.current_node.value) == 0 && stopped
    let g:Cmd2_leftover_key = a:state.input_string
  endif
endfunction

function! Cmd2#handle#PrepareState(state)
  let a:state.current_node = get(a:state, 'current_node', g:Cmd2_mapping_tree)
  let a:state.ccount = get(a:state, 'ccount', 0)
  let a:state.stopped = get(a:state, 'stopped', 0)
  let a:state.start_timeout = get(a:state, 'start_timeout', 0)
endfunction

function! Cmd2#handle#HandleInputChar(input, node)
  if has_key(a:node, a:input)
    return [a:node[a:input], 0]
  else
    return [a:node, 1]
  endif
endfunction

function! Cmd2#handle#HandleInputNum(input, count)
  return a:count * 10 + a:input
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo

let s:save_cpo = &cpo
set cpo&vim

function! cmd2#tree#Autoload()
  " do nothing
endfunction

function! cmd2#tree#New(node)
  return copy(a:node)
endfunction

function! cmd2#tree#NodeHasKey(node, key)
  return has_key(a:node, a:key)
endfunction

function! cmd2#tree#NodeAddNode(node, key)
  let a:node[a:key] = {'value': {}}
  return a:node[a:key]
endfunction

function! cmd2#tree#NodeAddValue(node, value)
  let a:node['value'] = a:value
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo

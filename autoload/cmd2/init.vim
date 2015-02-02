let s:save_cpo = &cpo
set cpo&vim

function! cmd2#init#Autoload()
  " do nothing
endfunction

function! cmd2#init#Options(default_options)
  let cmd2_options = extend(copy(a:default_options), g:cmd2_options, 'force')
  for key in keys(cmd2_options)
    call cmd2#init#Option(key, cmd2_options[key])
  endfor
endfunction

" Helper function for init#Options()
function! cmd2#init#Option(key, value)
  " a:value has to be wrapped in '' (treated as literal string)
  " ' needs to be escaped using ''
  let value = substitute(a:value, "'", "''", "g")
  execute "let g:cmd2_" . a:key . " = " . "'" . value . "'"
endfunction

function! cmd2#init#CmdMappings(default_cmd_mappings)
  let g:cmd2_mapping_tree = cmd2#tree#New({'value': {'command': ''}})
  let cmd2_cmd_mappings = extend(copy(a:default_cmd_mappings), g:cmd2_cmd_mappings, 'force')
  for key in keys(cmd2_cmd_mappings)
    let mapping = cmd2_cmd_mappings[key]
    call cmd2#init#CmdMapping(key, mapping, g:cmd2_mapping_tree)
  endfor
endfunction

function! cmd2#init#CmdMapping(key, value, root)
  let current_node = a:root
  let key = a:key
  " split key into multibyte characters
  while !empty(key)
    if key =~ "\<Plug>"
      let char = key[0:2]
      let key = key[3:-1]
    elseif key =~ '\v^[\x80-\xFF]'
      let char = key[0:2]
      let key = key[3:-1]
    else
      let char = key[0]
      let key = key[1:-1]
    endif
    if !cmd2#tree#NodeHasKey(current_node, char)
      let current_node = cmd2#tree#NodeAddNode(current_node, char)
    else
      let current_node = current_node[char]
    endif
  endwhile
  call cmd2#tree#NodeAddValue(current_node, a:value)
endfunction

function! cmd2#init#Mappings()
  let cmd2_mappings = extend(cmd2#cmd2_default_mappings, g:cmd2_mappings, 'force')
  for key in keys(cmd2_mappings)
    call cmd2#init#Mapping(key, cmd2_mappings[key])
  endfor
endfunction

function! cmd2#init#Mapping(key, value)
  " TODO
endfunction

function! cmd2#init#CursorHl()
  if hlID('Cursor')
    return 'Cursor'
  else
    hi! Cmd2Cursor cterm=reverse term=reverse
    return 'Cmd2Cursor'
  endif
endfunction


let &cpo = s:save_cpo
unlet s:save_cpo

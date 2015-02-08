let s:save_cpo = &cpo
set cpo&vim

function! cmd2#init#Autoload()
  " do nothing
endfunction

function! cmd2#init#Options(default_options)
  let Cmd2_options = extend(copy(a:default_options), g:Cmd2_options, 'force')
  for key in keys(Cmd2_options)
    call cmd2#init#Option(key, Cmd2_options[key])
  endfor
endfunction

" Helper function for init#Options()
function! cmd2#init#Option(key, value)
  let g:Cmd2_{a:key} = a:value
endfunction

function! cmd2#init#CmdMappings(default_cmd_mappings)
  let g:Cmd2_mapping_tree = cmd2#tree#New({'value': {'command': ''}})
  let Cmd2_cmd_mappings = extend(copy(a:default_cmd_mappings), g:Cmd2_cmd_mappings, 'force')
  for key in keys(Cmd2_cmd_mappings)
    let mapping = Cmd2_cmd_mappings[key]
    call cmd2#init#CmdMapping(key, mapping, g:Cmd2_mapping_tree)
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
  let Cmd2_mappings = extend(cmd2#Cmd2_default_mappings, g:Cmd2_mappings, 'force')
  for key in keys(Cmd2_mappings)
    call cmd2#init#Mapping(key, Cmd2_mappings[key])
  endfor
endfunction

function! cmd2#init#Mapping(key, value)
  " TODO
endfunction

function! cmd2#init#CursorHl()
  if hlID('Cursor')
    hi! link Cmd2Cursor Cursor
  else
    hi! Cmd2Cursor cterm=reverse term=reverse guifg=bg guibg=fg
  endif
  return 'Cmd2Cursor'
endfunction

function! cmd2#init#BufferCursorHl()
  if hlID('Cursor')
    hi! link Cmd2BufferCursor Cursor
  else
    hi! Cmd2BufferCursor cterm=reverse term=reverse guifg=bg guibg=fg
  endif
  return 'Cmd2BufferCursor'
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo

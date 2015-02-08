let s:save_cpo = &cpo
set cpo&vim

function! cmd2#commands#Autoload()
  " do nothing
endfunction

function! cmd2#commands#DoMapping(input)
  if !type(a:input) && !a:input
    return
  endif
  let mapping = a:input.node['value']
  let flags = get(mapping, 'flags', '')
  " capital since there might be a funcref
  let Cmd = get(mapping, 'command', '')
  let type = get(mapping, 'type', '')
  let ccount = flags =~# 'C' ? (a:input.ccount == 0 ? 1 : a:input.ccount)
        \ : flags =~# 'c' ? a:input.ccount
        \ : ""
  let old_view = winsaveview()
  let [vstart, vend, vpos, vmode] = cmd2#commands#VisualPre(flags)
  call winrestview(old_view)
  call cmd2#commands#HandleType(Cmd, type, ccount)
  call cmd2#commands#Vflag(vstart, vend, vpos, vmode, flags)
  call cmd2#commands#Pflag(old_view, flags)
  call cmd2#commands#Rflag(mapping, flags)
endfunction

function! cmd2#commands#VisualPre(flags)
  if a:flags =~# 'v' && g:Cmd2_visual_select
    let [vstart, vend, vpos, vmode] = cmd2#util#SaveVisual()
    return [vstart, vend, vpos, vmode]
  else
    return [-1, -1, -1, -1]
  endif
endfunction

function! cmd2#commands#Vflag(vstart, vend, vpos, vmode, flags)
  if a:flags =~# 'v' && g:Cmd2_visual_select
    let cursor_pos = getpos('.')
    call cmd2#util#RestoreVisual(a:vstart, a:vend, a:vpos, a:vmode)
    call setpos(".", cursor_pos)
  endif
endfunction

function! cmd2#commands#Pflag(old_view, flags)
  if a:flags =~# 'p'
    call winrestview(a:old_view)
  endif
endfunction

function! cmd2#commands#Rflag(mapping, flags)
  if a:flags =~# 'r'
    let g:Cmd2_reenter = 1
    let g:Cmd2_reenter_key = get(a:mapping, 'reenter', '')
  endif
endfunction

function! cmd2#commands#HandleType(cmd, type, ccount)
  if empty(a:cmd) || empty(a:type)
    " skip
    let g:Cmd2_output = ""
  elseif a:type == 'literal'
    call cmd2#commands#HandleLiteral(a:cmd, a:ccount)
  elseif a:type == 'text'
    call cmd2#commands#HandleText(a:cmd, a:ccount)
  elseif a:type == 'line'
    call cmd2#commands#HandleLine(a:cmd, a:ccount)
  elseif a:type == 'function'
    call cmd2#commands#HandleFunction(a:cmd, a:ccount)
  elseif a:type == 'snippet'
    call cmd2#commands#HandleSnippet(a:cmd, a:ccount)
  elseif a:type == 'normal'
    call cmd2#commands#HandleNormal(a:cmd, a:ccount, 0)
  elseif a:type == 'normal!'
    call cmd2#commands#HandleNormal(a:cmd, a:ccount, 1)
  elseif a:type == 'remap'
    call cmd2#commands#HandleRemap(a:cmd, a:ccount)
  endif
endfunction

function! cmd2#commands#HandleLiteral(cmd, ccount)
  if !len(a:ccount)
    let g:Cmd2_output = a:cmd
  else
    let g:Cmd2_output = repeat(a:cmd, a:ccount)
  endif
endfunction

function! cmd2#commands#HandleText(cmd, ccount)
  execute "set opfunc=cmd2#functions#GetContents"
  " normal (no !) to allow custom text obj remaps
  execute "normal g@" . a:ccount . a:cmd
endfunction

function! cmd2#commands#HandleLine(cmd, ccount)
  execute "set opfunc=cmd2#functions#GetLines"
  " normal (no !) to allow custom text obj remaps
  execute "normal g@" . a:ccount . a:cmd
endfunction

function! cmd2#commands#HandleFunction(cmd, ccount)
  if len(a:ccount)
    call call(a:cmd, [a:ccount])
  else
    call call(a:cmd, [])
  endif
endfunction

function! cmd2#commands#HandleSnippet(cmd, ccount)
  let snippet = substitute(a:cmd, g:Cmd2_snippet_cursor_replace, g:Cmd2_snippet_cursor, "g")
  let offset = match(snippet, g:Cmd2_snippet_cursor)
  if offset == -1
    let g:Cmd2_output = snippet
    return
  endif
  if offset == 0
    let before = ""
  else
    let before = snippet[0 : offset - 1]
  endif
  let after = snippet[offset + strlen(g:Cmd2_snippet_cursor) : -1]
  let g:Cmd2_pending_cmd[0] .= before
  let g:Cmd2_pending_cmd[1] = after . g:Cmd2_pending_cmd[1]
endfunction

function! cmd2#commands#HandleNormal(cmd, ccount, bang)
  let bang = a:bang ? '!' : ''
  execute "normal" . bang . " " . a:ccount . a:cmd
endfunction

let g:Cmd2_remap_depth = 0

function! cmd2#commands#HandleRemap(cmd, ccount)
  let g:Cmd2_remap_depth += 1
  if g:Cmd2_remap_depth > g:Cmd2_max_remap_depth
    return
  endif
  let node = cmd2#util#FindNode(a:cmd, g:Cmd2_mapping_tree)
  if !empty(node)
    call cmd2#commands#DoMapping({'node': node, 'ccount': a:ccount})
  endif
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo

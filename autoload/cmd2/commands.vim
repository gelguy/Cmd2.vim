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
  let [vstart, vend, vpos, vmode] = cmd2#commands#VisualPre(old_view, flags)
  call cmd2#commands#HandleType(Cmd, type, ccount)
  call cmd2#commands#Vflag(vstart, vend, vpos, vmode, flags)
  call cmd2#commands#Pflag(old_view, flags)
  call cmd2#commands#Rflag(mapping, flags)
endfunction

function! cmd2#commands#VisualPre(old_view, flags)
  if a:flags =~# 'v' && g:cmd2_visual_select
    let [vstart, vend, vpos, vmode] = cmd2#util#SaveVisual()
    call winrestview(a:old_view)
    return [vstart, vend, vpos, vmode]
  else
    return [-1, -1, -1, -1]
  endif
endfunction

function! cmd2#commands#Vflag(vstart, vend, vpos, vmode, flags)
  if a:flags =~# 'v' && g:cmd2_visual_select
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
    let g:cmd2_reenter = 1
    let g:cmd2_reenter_key = get(a:mapping, 'reenter', '')
  endif
endfunction

function! cmd2#commands#HandleType(cmd, type, ccount)
  if empty(a:cmd) || empty(a:type)
    " skip
    let g:cmd2_output = ""
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
  let g:cmd2_output = a:cmd
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
  if type(a:cmd) != 2
    " convert all other types to string
    let function = substitute(a:cmd, '\v\(\)$', "", "")
    execute "call call('" . function . "', [" . a:ccount . "])"
  else
    if len(a:ccount)
      call a:cmd(ccount)
    else
      call a:cmd()
    endif
  endif
endfunction

function! cmd2#commands#HandleSnippet(cmd, ccount)
  let snippet = substitute(a:cmd, g:cmd2_snippet_cursor_replace, g:cmd2_snippet_cursor, "g")
  let offset = match(snippet, g:cmd2_snippet_cursor)
  let offset = offset < 0 ? 0 : offset
  let snippet = substitute(snippet, g:cmd2_snippet_cursor, '', "")
  " move cursor back to where match starts
  let g:cmd2_cursor_pos -= strdisplaywidth(snippet) - offset
  let g:cmd2_output = snippet
endfunction

function! cmd2#commands#HandleNormal(cmd, ccount, bang)
  let bang = a:bang ? '!' : ''
  execute "normal" . bang . " " . a:cmd
endfunction

let g:cmd2_remap_depth = 0

function! cmd2#commands#HandleRemap(cmd, ccount)
  let g:cmd2_remap_depth += 1
  if g:cmd2_remap_depth > g:cmd2_max_remap_depth
    return
  endif
  let node = cmd2#util#FindNode(a:cmd, g:cmd2_mapping_tree)
  if !empty(node)
    call cmd2#commands#DoMapping({'node': node, 'ccount': a:ccount})
  endif
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo

let s:save_cpo = &cpo
set cpo&vim

function! cmd2#commands#Autoload()
  " do nothing
endfunction

function! cmd2#commands#DoMapping(node, ccount)
  let mapping = a:node['value']
  let flags = get(mapping, 'flags', '')
  let cmd = get(mapping, 'command', '')
  let type = get(mapping, 'type', '')
  let ccount = flags =~# 'C' ? (a:ccount == 0 ? 1 : a:ccount)
        \ : flags =~# 'c' ? a:ccount
        \ : ""
  let old_view = winsaveview()
  if flags =~# 'v'
    let [vstart, vend, vpos, vmode] = cmd2#util#SaveVisual()
    call winrestview(old_view)
  endif
  call cmd2#commands#HandleType(cmd, type, ccount)
  if flags =~# 'v'
    let cursor_pos = getpos('.')
    call cmd2#util#RestoreVisual(vstart, vend, vpos, vmode)
    call setpos(".", cursor_pos)
  endif
  if flags =~# 'p'
    call winrestview(old_view)
  endif
  if flags =~# 'r'
    let g:cmd2_reenter = 1
    let g:cmd2_reenter_key = get(mapping, 'reenter', '')
  endif
endfunction

function! cmd2#commands#HandleType(cmd, type, ccount)
  if empty(a:cmd) || empty(a:type)
    " skip
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
  execute "set opfunc=cmd2#commands#GetContents"
  " normal (no !) to allow custom text obj remaps
  execute "normal g@" . a:ccount . a:cmd
endfunction

function! cmd2#commands#HandleLine(cmd, ccount)
  execute "set opfunc=cmd2#commands#GetLines"
  " normal (no !) to allow custom text obj remaps
  execute "normal g@" . a:ccount . a:cmd

endfunction

function! cmd2#commands#HandleFunction(cmd, ccount)
  let function = substitute(a:cmd, '\v\(\)$', "", "")
  execute "call call('" . a:cmd . "', [" . a:ccount . "])"
endfunction

function! cmd2#commands#HandleSnippet(cmd, ccount)
  let snippet = substitute(a:cmd, g:cmd2_snippet_cursor_replace, g:cmd2_snippet_cursor, "g")
  let offset = match(snippet, g:cmd2_snippet_cursor)
  let offset = offset < 0 ? 0 : offset
  let snippet = substitute(snippet, g:cmd2_snippet_cursor, '', "")
  " move cursor back to where match starts
  let g:cmd2_cursor_pos -= strlen(snippet) - offset
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
    call cmd2#commands#DoMapping(node, a:ccount)
  endif
endfunction

function! cmd2#commands#GetContents(type)
  let old_reg = @@
  let sel_save = &selection
  let &selection = "inclusive"
  if a:type == 'line'
    silent exe "normal! '[V']y"
  else
    silent exe "normal! `[v`]y"
  endif
  let g:cmd2_output = @@
  let &selection = sel_save
  let @@ = old_reg
endfunction

function! cmd2#commands#GetLines(type)
  silent exe "normal! '["
  let start_line = getpos('.')[1]
  silent exe "normal! ']"
  let end_line = getpos('.')[1]
  if start_line != end_line
    let g:cmd2_output = start_line . "," . end_line
  else
    let g:cmd2_output = start_line
  endif
endfunction

function! cmd2#commands#TabForward()
  call cmd2#commands#Tab('forwards')
endfunction

function! cmd2#commands#TabBackward()
  call cmd2#commands#Tab('backwards')
endfunction

function! cmd2#commands#Tab(direction)
  let cmd = g:cmd2_pending_cmd[0] . g:cmd2_pending_cmd[1]
  let current_pos = strlen(g:cmd2_pending_cmd[0])
  if a:direction == 'backwards'
    let new_pos = -1
    let old_pos = -1
    while 1
      let new_pos = match(cmd, g:cmd2_snippet_cursor, old_pos + 1)
      if new_pos < 0 || new_pos > current_pos - 1
        " - 1 so we stop before we reach current position
        let new_pos = old_pos
        break
      endif
      let old_pos = new_pos
    endwhile
  elseif a:direction == 'forwards'
    let new_pos = match(cmd, g:cmd2_snippet_cursor, current_pos)
  endif
  if new_pos >= 0
    let cursor_width = strlen(g:cmd2_snippet_cursor)
    let g:cmd2_pending_cmd = [cmd[0 : (new_pos-1)], cmd[(new_pos + cursor_width) : -1]]
    " +1 to include cmdline type
    let g:cmd2_cursor_pos = strlen(g:cmd2_pending_cmd[0]) + 1
  endif
endfunction

let s:cmd2_cword_pos = [-1,-1]

function! cmd2#commands#Cword(ccount)
  let current_pos = getpos('.')
  if current_pos[1] == s:cmd2_cword_pos[0] &&
        \ current_pos[2] == col('$') - 1 &&
        \ current_pos[2] == s:cmd2_cword_pos[1]
    return
  endif
  let reg_save = @@
  let selection_save = &selection
  let &selection = 'exclusive'
  normal! viw
  let i = 1
  while i < a:ccount
    normal! e
    let i += 1
  endwhile
  normal! y
  execute "normal! gv\<Esc>"
  let g:cmd2_output = substitute(@@, "\n", " ", "")
  let @@ = reg_save
  let &selection = selection_save
  let s:cmd2_cword_pos = [getpos('.')[1], getpos('.')[2]]
endfunction

function! cmd2#commands#CopySearch()
  let cmd = g:cmd2_pending_cmd[0] . g:cmd2_pending_cmd[1]
  let matchstr = matchlist(cmd, '\vs/(.{-})/')
  if !empty(matchstr[1])
    let g:cmd2_output = matchstr[1]
  endif
endfunction

function! cmd2#commands#Back()
  let head = g:cmd2_pending_cmd[0]
  let current_pos = 0
  let next_pos = 0
  while 1
    let next_match = match(head, '\v\k+', next_pos)
    if next_match >= 0 && next_match < strlen(head)
      let current_pos = next_match
      let next_pos = matchend(head, '\v\k+', next_pos)
    else
      break
    endif
  endwhile
  " to include prompt
  let g:cmd2_cursor_pos = current_pos + 1
endfunction

function! cmd2#commands#End()
  let tail = g:cmd2_pending_cmd[1]
  let matchend = matchend(tail, '\v\k+')
  if matchend < 0
    let g:cmd2_cursor_pos += strlen(tail)
  else
    let g:cmd2_cursor_pos += matchend
  endif
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo

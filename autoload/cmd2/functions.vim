let s:save_cpo = &cpo
set cpo&vim

function! Cmd2#functions#Autoload()
  " do nothing
endfunction

function! Cmd2#functions#GetContents(type)
  let old_reg = @@
  let sel_save = &selection
  let &selection = "inclusive"
  if a:type == 'line'
    silent exe "normal! '[V']y"
  else
    silent exe "normal! `[v`]y"
  endif
  let g:Cmd2_output = @@
  let &selection = sel_save
  let @@ = old_reg
endfunction

function! Cmd2#functions#GetLines(type)
  silent exe "normal! '["
  let start_line = getpos('.')[1]
  silent exe "normal! ']"
  let end_line = getpos('.')[1]
  if start_line != end_line
    let g:Cmd2_output = start_line . "," . end_line
  else
    let g:Cmd2_output = start_line
  endif
endfunction

function! Cmd2#functions#TabForward(...)
  call Cmd2#functions#TabCount('forwards', a:000)
endfunction

function! Cmd2#functions#TabBackward(...)
  call Cmd2#functions#TabCount('backwards', a:000)
endfunction

function! Cmd2#functions#TabCount(direction, count_list)
  let ccount = get(a:count_list, 0, 1)
  let i = 0
  while i < ccount
    call Cmd2#functions#Tab(a:direction)
    let i += 1
  endwhile
endfunction

function! Cmd2#functions#Tab(direction, ...)
  let cmd = g:Cmd2_pending_cmd[0] . g:Cmd2_pending_cmd[1]
  let current_pos = strlen(g:Cmd2_pending_cmd[0])
  if a:direction == 'backwards'
    let new_pos = -1
    let old_pos = -1
    while 1
      let new_pos = match(cmd, g:Cmd2_snippet_cursor, old_pos + 1)
      if new_pos < 0 || new_pos > current_pos - 1
        " - 1 so we stop before we reach current position
        let new_pos = old_pos
        break
      endif
      let old_pos = new_pos
    endwhile
  elseif a:direction == 'forwards'
    let new_pos = match(cmd, g:Cmd2_snippet_cursor, current_pos)
  endif
  if new_pos >= 0
    let cursor_width = strlen(g:Cmd2_snippet_cursor)
    let g:Cmd2_pending_cmd = [cmd[0 : (new_pos-1)], cmd[(new_pos + cursor_width) : -1]]
  endif
endfunction

let s:Cmd2_cword_pos = [-1,-1]

function! Cmd2#functions#Cword(...)
  let ccount = get(a:000, 0, 1)
  let current_pos = getpos('.')
  if current_pos[1] == s:Cmd2_cword_pos[0] &&
        \ current_pos[2] == col('$') - 1 &&
        \ current_pos[2] == s:Cmd2_cword_pos[1]
    return
  endif
  let reg_save = @@
  let selection_save = &selection
  let &selection = 'exclusive'
  normal! viw
  let i = 1
  while i < ccount
    normal! e
    let i += 1
  endwhile
  normal! y
  execute "normal! gv\<Esc>"
  let g:Cmd2_output = substitute(@@, "\n", " ", "")
  let @@ = reg_save
  let &selection = selection_save
  " -1 since selection is exclusive
  let s:Cmd2_cword_pos = [getpos('.')[1], (getpos("'>")[2] - 1)]
endfunction

function! Cmd2#functions#CopySearch(...)
  let cmd = g:Cmd2_pending_cmd[0] . g:Cmd2_pending_cmd[1]
  let matchstr = matchlist(cmd, '\vs/(.{-})/')
  if !empty(matchstr[1])
    let g:Cmd2_output = matchstr[1]
  endif
endfunction

function! Cmd2#functions#Back(...)
  let ccount = get(a:000, 0, 1)
  let j = 0
  while j < ccount
    let head = g:Cmd2_pending_cmd[0]
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
    let head = g:Cmd2_pending_cmd[0]
    if current_pos == 0
      let g:Cmd2_pending_cmd[0] = ""
    else
      let g:Cmd2_pending_cmd[0] = head[0 : current_pos - 1]
    endif
    let g:Cmd2_pending_cmd[1] = head[current_pos : -1] . g:Cmd2_pending_cmd[1]
    let j += 1
  endwhile
endfunction

function! Cmd2#functions#End(...)
  let ccount = get(a:000, 0, 1)
  let j = 0
  while j < ccount
    let tail = g:Cmd2_pending_cmd[1]
    let matchend = matchend(tail, '\v\k+')
    if matchend <= 0
      let g:Cmd2_pending_cmd[0] .= tail
      let g:Cmd2_pending_cmd[1] = ""
    else
      let g:Cmd2_pending_cmd[0] .= tail[0 : matchend - 1]
      let g:Cmd2_pending_cmd[1] = tail[matchend : -1]
    endif
    let j += 1
  endwhile
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo

let s:save_cpo = &cpo
set cpo&vim

function! cmd2#functions#Autoload()
  " do nothing
endfunction

function! cmd2#functions#GetContents(type)
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

function! cmd2#functions#GetLines(type)
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

function! cmd2#functions#TabForward()
  call cmd2#functions#Tab('forwards')
endfunction

function! cmd2#functions#TabBackward()
  call cmd2#functions#Tab('backwards')
endfunction

function! cmd2#functions#Tab(direction)
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
  endif
endfunction

let s:cmd2_cword_pos = [-1,-1]

function! cmd2#functions#Cword(ccount)
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
  " -1 since selection is exclusive
  let s:cmd2_cword_pos = [getpos('.')[1], (getpos("'>")[2] - 1)]
endfunction

function! cmd2#functions#CopySearch()
  let cmd = g:cmd2_pending_cmd[0] . g:cmd2_pending_cmd[1]
  let matchstr = matchlist(cmd, '\vs/(.{-})/')
  if !empty(matchstr[1])
    let g:cmd2_output = matchstr[1]
  endif
endfunction

function! cmd2#functions#Back()
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
  let head = g:cmd2_pending_cmd[0]
  if current_pos == 0
    let g:cmd2_pending_cmd[0] = ""
  else
    let g:cmd2_pending_cmd[0] = head[0 : current_pos - 1]
  endif
  let g:cmd2_pending_cmd[1] = head[current_pos : -1] . g:cmd2_pending_cmd[1]
endfunction

function! cmd2#functions#End()
  let tail = g:cmd2_pending_cmd[1]
  let matchend = matchend(tail, '\v\k+')
  if matchend <= 0
    let g:cmd2_pending_cmd[0] .= tail
    let g:cmd2_pending_cmd[1] = ""
  else
    let g:cmd2_pending_cmd[0] .= tail[0 : matchend - 1]
    let g:cmd2_pending_cmd[1] = tail[matchend : -1]
  endif
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo

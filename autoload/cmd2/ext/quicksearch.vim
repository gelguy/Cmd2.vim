let s:save_cpo = &cpo
set cpo&vim

function! Cmd2#ext#quicksearch#Autoload()
  " do nothing
endfunction

function! Cmd2#ext#quicksearch#Forward()
  call Cmd2#ext#quicksearch#Search('')
endfunction

function! Cmd2#ext#quicksearch#Backward()
  call Cmd2#ext#quicksearch#Search('b')
endfunction

function! Cmd2#ext#quicksearch#Search(flag)
  let old_hlsearch = &hlsearch
  let old_ignorecase = &ignorecase
  try
    let &ignorecase = g:Cmd2__quicksearch_ignorecase
    let pattern = g:Cmd2_pending_cmd[0] . g:Cmd2_pending_cmd[1]
    if !len(pattern)
      if exists('s:previous') && len(s:previous)
        let pattern = s:previous
      else
        return
      endif
    endif
    let @/ = pattern
    call search(pattern, a:flag)
    call Cmd2#ext#quicksearch#ClearHl()
    let [line, col] = getpos('.')[1:2]
    let flag = g:Cmd2__quicksearch_ignorecase ? '\c' : ''
    let s:tab_search_hl = matchadd(g:Cmd2__quicksearch_hl, flag . pattern)
    let s:tab_search_current_hl = matchadd(g:Cmd2__quicksearch_current_hl,
          \ flag . '\V\%' . line . 'l\%\>' . (col - 1) . 'c' . pattern . '\%\<' . (col + len(pattern) + 1) . 'c')
    let s:previous = pattern
    " for lazyredraw
    redraw
  finally
    let &hlsearch = old_hlsearch
    let &ignorecase = old_ignorecase
  endtry
endfunction

function! Cmd2#ext#quicksearch#ClearHl()
  if exists('s:tab_search_hl') && s:tab_search_hl >= 0
    call matchdelete(s:tab_search_hl)
    let s:tab_search_hl = -1
  endif
  if exists('s:tab_search_current_hl') && s:tab_search_current_hl >= 0
    call matchdelete(s:tab_search_current_hl)
    let s:tab_search_current_hl = -1
  endif
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo

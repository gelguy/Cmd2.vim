let s:save_cpo = &cpo
set cpo&vim

function! cmd2#ext#complete#Autoload()
  " do nothing
endfunction

function! cmd2#ext#complete#Main()
  try
    let old_menu = g:cmd2_menu
    let s:old_cmd_0 = g:cmd2_pending_cmd[0]
    call call(g:cmd2__complete_generate, [s:old_cmd_0])
    let candidates = cmd2#ext#complete#GenerateCandidates(s:old_cmd_0)
    if g:cmd2__complete_ignorecase
      if g:cmd2__complete_uniq_ignorecase
        call uniq(sort(candidates, 'i'), 'i')
      else
        call uniq(sort(candidates, 'i'))
      endif
    else
      if g:cmd2__complete_uniq_ignorecase
        call uniq(sort(candidates), 'i')
      else
        call uniq(sort(candidates))
      endif
    endif
    if len(candidates)
      " insert original string at the front
      call insert(candidates, cmd2#ext#complete#StringToMatch())
      let g:cmd2_menu = cmd2#menu#CreateMenu(candidates, [0,0], &columns)
      call cmd2#menu#Next(g:cmd2_menu)
      let g:cmd2_temp_output = cmd2#ext#complete#GetTempOutput()
      let state = {}
      let state.start_time = reltime()
      let state.current_time = state.start_time
      let state.force_render = 1
      let args = {
            \ 'render': function('cmd2#render#Prepare'),
            \ 'handle': function('cmd2#ext#complete#Handle'),
            \ 'finish': function('cmd2#ext#complete#Finish'),
            \ 'state': state,
            \ }
      call cmd2#loop#Init(args)
    endif
  finally
    let g:cmd2_menu = old_menu
  endtry
endfunction

function! cmd2#ext#complete#Handle(input, state)
  if a:input == "\<Tab>"
    call cmd2#menu#Next(g:cmd2_menu)
    let g:cmd2_temp_output = cmd2#ext#complete#GetTempOutput()
    let a:state.start_time = reltime()
    let a:state.current_time = a:state.start_time
    let a:state.force_render = 1
  elseif a:input == "\<S-Tab>"
    call cmd2#menu#Previous(g:cmd2_menu)
    let g:cmd2_temp_output = cmd2#ext#complete#GetTempOutput()
    let a:state.start_time = reltime()
    let a:state.current_time = a:state.start_time
    let a:state.force_render = 1
  elseif a:input == "\<Esc>"
    let g:cmd2_output = ""
    let g:cmd2_output = s:old_cmd_0
    let a:state.stopped = 1
  else
    let g:cmd2_output = cmd2#ext#complete#GetOutput()
    let g:cmd2_leftover_key = a:input
    let a:state.stopped = 1
  endif
endfunction

function! cmd2#ext#complete#Finish(input)
  " do nothing
endfunction

function! cmd2#ext#complete#GenerateCandidates(cmd)
  let string = cmd2#ext#complete#StringToMatch()
  if !len(string)
    return []
  endif
  let result = cmd2#ext#complete#ScanBuffer(string)
  return result
endfunction

function! cmd2#ext#complete#ScanBuffer(string)
  let old_view = winsaveview()
  let matches = []
  call cursor(1,1)
  let ignore_case = g:cmd2__complete_ignorecase ? '\c' : ''
  let pattern = '\V' . ignore_case . g:cmd2__complete_start_pattern
  if g:cmd2__complete_fuzzy
    let pattern .= cmd2#ext#complete#CreateFuzzyPattern(a:string, g:cmd2__complete_pattern . '\*')
  else
    let pattern .= a:string
  endif
  let pattern .= g:cmd2__complete_pattern . '\+'
  let match = search(pattern, 'cnW')
  while match
    let matches += cmd2#ext#complete#GetMatchesOnLine(match, pattern, a:string)
    if match == line('$')
      break
    else
      call cursor((getpos('.')[1] + 1), 1)
      let match = search(pattern, 'cnW')
    endif
  endwhile
  call winrestview(old_view)
  return matches
endfunction

function! cmd2#ext#complete#GetMatchesOnLine(line_num, pattern, string)
  let matches = []
  let line = getline(a:line_num)
  let start_pos = match(line, a:pattern)
  while start_pos != -1
    let end_pos = matchend(line, a:pattern, start_pos)
    let substring = line[start_pos : (end_pos - 1)]
    call add(matches, substring)
    let start_pos = match(line, a:pattern, end_pos)
  endwhile
  return matches
endfunction

function! cmd2#ext#complete#CreateFuzzyPattern(string, pattern)
  let result = ''
  let i = 0
  while i < len(a:string)
    let char = matchstr(a:string, ".", byteidx(a:string, i))
    let result .= char
    let result .= a:pattern
    let i += len(char)
  endwhile
  return result
endfunction

function! cmd2#ext#complete#StringToMatch()
  return matchstr(s:old_cmd_0, '\v\k*$')
endfunction

function! cmd2#ext#complete#GetTempOutput()
  let g:cmd2_pending_cmd[0] = s:old_cmd_0[0 : -len(cmd2#ext#complete#StringToMatch()) - 1]
  return cmd2#menu#Current(g:cmd2_menu)
endfunction

function! cmd2#ext#complete#GetOutput()
  let g:cmd2_pending_cmd[0] = s:old_cmd_0[0 : -len(cmd2#ext#complete#StringToMatch()) - 1]
  let string = cmd2#menu#Current(g:cmd2_menu)
  return string
endfunction

function! cmd2#ext#complete#GetCmdSubstring(str)
  let string = cmd2#ext#complete#StringToMatch()
  return a:str[len(string) : -1]
endfunction

function! cmd2#ext#complete#HasComplete()
  let pos = getcmdpos()
  let cmdline = getcmdline()[0 : pos]
  return getcmdtype() =~ '\v[?/]' || match(cmdline, '\v[?/]\k*$') >= 0
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo

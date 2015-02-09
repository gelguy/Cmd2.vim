let s:save_cpo = &cpo
set cpo&vim

function! Cmd2#ext#complete#Autoload()
  " do nothing
endfunction

function! Cmd2#ext#complete#Main(...)
  try
    let old_menu = g:Cmd2_menu
    let s:old_cmd_0 = g:Cmd2_pending_cmd[0]
    let candidates = call(g:Cmd2__complete_generate, [s:old_cmd_0])
    if len(candidates)
      let idx = index(candidates, Cmd2#ext#complete#StringToMatch())
      if idx >= 0
        call remove(candidates, idx)
      endif
      " insert original string at the front
      call insert(candidates, Cmd2#ext#complete#StringToMatch())
      let g:Cmd2_menu = Cmd2#menu#CreateMenu(candidates, [0,0], &columns)
      call Cmd2#menu#Next(g:Cmd2_menu)
      let g:Cmd2_temp_output = Cmd2#ext#complete#GetTempOutput()
      let state = {}
      let state.start_time = reltime()
      let state.current_time = state.start_time
      let state.force_render = 1
      let args = {
            \ 'render': function('Cmd2#render#Prepare'),
            \ 'handle': function('Cmd2#ext#complete#Handle'),
            \ 'finish': function('Cmd2#ext#complete#Finish'),
            \ 'state': state,
            \ }
      call Cmd2#loop#Init(args)
    endif
  finally
    let g:Cmd2_menu = old_menu
  endtry
endfunction

function! Cmd2#ext#complete#Handle(input, state)
  if a:input == g:Cmd2__complete_next
    call Cmd2#menu#Next(g:Cmd2_menu)
    let g:Cmd2_temp_output = Cmd2#ext#complete#GetTempOutput()
    let a:state.start_time = reltime()
    let a:state.current_time = a:state.start_time
    let a:state.force_render = 1
  elseif a:input == g:Cmd2__complete_previous
    call Cmd2#menu#Previous(g:Cmd2_menu)
    let g:Cmd2_temp_output = Cmd2#ext#complete#GetTempOutput()
    let a:state.start_time = reltime()
    let a:state.current_time = a:state.start_time
    let a:state.force_render = 1
  elseif a:input == "\<Esc>"
    let g:Cmd2_output = ""
    let g:Cmd2_output = s:old_cmd_0
    let a:state.stopped = 1
  else
    let g:Cmd2_output = Cmd2#ext#complete#GetOutput()
    let g:Cmd2_leftover_key = a:input
    let a:state.stopped = 1
  endif
endfunction

function! Cmd2#ext#complete#Finish(input)
  " do nothing
endfunction

function! Cmd2#ext#complete#GenerateCandidates(cmd)
  let string = Cmd2#ext#complete#StringToMatch()
  if !len(string)
    return []
  endif
  let result = Cmd2#ext#complete#ScanBuffer(string)
  let result = Cmd2#ext#complete#Uniq(result)
  call Cmd2#ext#complete#Sort(result, g:Cmd2__complete_ignorecase)
  return result
endfunction

function! Cmd2#ext#complete#ScanBuffer(string)
  let old_view = winsaveview()
  let matches = []
  call cursor(1,1)
  let pattern = call(g:Cmd2__complete_pattern_func, [a:string])
  let match = search(pattern, 'W')
  while match
    let matches += Cmd2#ext#complete#GetMatchesOnLine(match, pattern, a:string)
    if match == line('$')
      break
    else
      call cursor((getpos('.')[1] + 1), 1)
      let match = search(pattern, 'W')
    endif
  endwhile
  call winrestview(old_view)
  return matches
endfunction

function! Cmd2#ext#complete#CreatePattern(string)
  let pattern = ""
  let ignore_case = g:Cmd2__complete_ignorecase ? '\c' : ''
  let pattern = '\V' . ignore_case . g:Cmd2__complete_start_pattern
  if g:Cmd2__complete_fuzzy
    let pattern .= Cmd2#ext#complete#CreateFuzzyPattern(a:string, g:Cmd2__complete_middle_pattern)
  else
    let pattern .= a:string
  endif
  let pattern .= g:Cmd2__complete_end_pattern
  return pattern
endfunction

function! Cmd2#ext#complete#GetMatchesOnLine(line_num, pattern, string)
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

function! Cmd2#ext#complete#CreateFuzzyPattern(string, pattern)
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

function! Cmd2#ext#complete#StringToMatch()
  return matchstr(s:old_cmd_0, '\v\k*$')
endfunction

function! Cmd2#ext#complete#GetTempOutput()
  let g:Cmd2_pending_cmd[0] = s:old_cmd_0[0 : -len(Cmd2#ext#complete#StringToMatch()) - 1]
  return Cmd2#menu#Current(g:Cmd2_menu)
endfunction

function! Cmd2#ext#complete#GetOutput()
  let g:Cmd2_pending_cmd[0] = s:old_cmd_0[0 : -len(Cmd2#ext#complete#StringToMatch()) - 1]
  let string = Cmd2#menu#Current(g:Cmd2_menu)
  return string
endfunction

function! Cmd2#ext#complete#GetCmdSubstring(str)
  let string = Cmd2#ext#complete#StringToMatch()
  return a:str[len(string) : -1]
endfunction

function! Cmd2#ext#complete#InContext()
  let pos = getcmdpos()
  let cmdline = getcmdline()[0 : pos]
  return !wildmenumode() && (getcmdtype() =~ '\v[?/]' || match(cmdline, '\v[?/]\k*$') >= 0)
endfunction

function! Cmd2#ext#complete#Uniq(list)
  let dict = {}
  for item in a:list
    if g:Cmd2__complete_uniq_ignorecase
      let item = tolower(item)
    endif
    if !has_key(dict, item)
      let dict[item] = 1
    endif
  endfor
  return keys(dict)
endfunction

function! Cmd2#ext#complete#Sort(candidates, ignorecase)
  if a:ignorecase
    call sort(a:candidates, 'Cmd2#ext#complete#Compare')
  else
    call sort(a:candidates)
  endif
endfunction

function! Cmd2#ext#complete#Compare(a1, a2)
  let a1 = tolower(a:a1)
  let a2 = tolower(a:a2)
  let i = 0
  let len = min([len(a1), len(a2)])
  while i < len
    let comp = a1[i] == a2[i] ? 0 : a1[i] > a2[i] ? 1 : -1
    if comp
      return comp
    endif
    let i += 1
  endwhile
  return len(a1) == len(a2) ? 0 : len(a1) > len(a2) ? 1 : -1
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo

let s:save_cpo = &cpo
set cpo&vim

function! Cmd2#ext#complete#Autoload()
  " do nothing
endfunction

let s:Module = {}

function! Cmd2#ext#complete#Module()
  return s:Module
endfunction

function! Cmd2#ext#complete#Main(...)
  call Cmd2#ext#complete#New().Run()
endfunction

function! Cmd2#ext#complete#New()
  return Cmd2#ext#complete#Module().New()
endfunction

function! s:Module.New()
  let complete = copy(self)
  let state = {}
  let state.start_time = reltime()
  let state.current_time = state.start_time
  let state.force_render = 1
  let args = {
        \ 'render': Cmd2#render#New().WithMenu(),
        \ 'handle': Cmd2#ext#complete#Handle(),
        \ 'finish': Cmd2#ext#complete#Finish(),
        \ 'loop': Cmd2#loop#New(),
        \ 'state': state,
        \ }
  let module = Cmd2#module#New(args)
  let complete.module = module
  return complete
endfunction

function! s:Module.Run()
  try
    let old_menu = g:Cmd2_menu
    let s:old_cmd = copy(g:Cmd2_pending_cmd)
    if len(g:Cmd2__complete_loading_text)
      " first redraw to clear cmdline, second to do echo
      redraw
      let cmdline = [{'text': g:Cmd2_cmd_type}, {'text': g:Cmd2_pending_cmd[0]}]
      if len(g:Cmd2__complete_loading_hl)
        call add(cmdline, {'text' : g:Cmd2__complete_loading_text, 'hl': g:Cmd2__complete_loading_hl})
      else
        call add(cmdline, {'text' : g:Cmd2__complete_loading_text})
      endif
      call add(cmdline, {'text': g:Cmd2_pending_cmd[1]})
      call Cmd2#render#Render(cmdline)
      redraw
    endif
    let candidates = call(g:Cmd2__complete_generate, [Cmd2#ext#complete#StringToMatch()])
    if len(candidates)
      let idx = index(candidates, Cmd2#ext#complete#StringToMatch())
      if idx >= 0
        call remove(candidates, idx)
      endif
      " insert original string at the front
      call insert(candidates, Cmd2#ext#complete#StringToMatch())
      let candidates = call(g:Cmd2__complete_conceal_func, [candidates])
      let g:Cmd2_menu = Cmd2#menu#New(candidates)
      call g:Cmd2_menu.Next()
      let g:Cmd2_temp_output = Cmd2#ext#complete#GetTempOutput()
      call Cmd2#ext#complete#Incsearch()
      call feedkeys(g:Cmd2_leftover_key)
      let g:Cmd2_leftover_key = ""
      call self.module.Run()
    endif
  finally
    let g:Cmd2_menu = old_menu
    call Cmd2#ext#complete#ClearIncsearchHl()
  endtry
endfunction

let s:Handle = {}

function! Cmd2#ext#complete#Handle()
  return copy(s:Handle)
endfunction

function! s:Handle.Module(module)
  let self.module = a:module
  return self
endfunction

function! s:Handle.Run(input)
  if a:input == g:Cmd2__complete_next
    call g:Cmd2_menu.Next()
    let g:Cmd2_temp_output = Cmd2#ext#complete#GetTempOutput()
    call Cmd2#ext#complete#Incsearch()
    let self.module.state.start_time = reltime()
    let self.module.state.current_time = self.module.state.start_time
    let self.module.state.force_render = 1
    call self.module.Render()
  elseif a:input == g:Cmd2__complete_previous
    call g:Cmd2_menu.Previous()
    let g:Cmd2_temp_output = Cmd2#ext#complete#GetTempOutput()
    call Cmd2#ext#complete#Incsearch()
    let self.module.state.start_time = reltime()
    let self.module.state.current_time = self.module.state.start_time
    let self.module.state.force_render = 1
    call self.module.Render()
  elseif a:input == g:Cmd2__complete_exit
    let g:Cmd2_output = ""
    let g:Cmd2_pending_cmd = s:old_cmd
    let self.module.state.stopped = 1
  else
    let output = Cmd2#ext#complete#GetOutput()
    let g:Cmd2_output = escape(output, '.\/~^$')
    let g:Cmd2_leftover_key = a:input
    let self.module.state.stopped = 1
  endif
endfunction

let s:Finish = {}

function! Cmd2#ext#complete#Finish()
  return copy(s:Finish)
endfunction

function! s:Finish.Module(module)
  let self.module = a:module
  return self
endfunction

function! s:Finish.Run()
  return
endfunction

function! Cmd2#ext#complete#GenerateCandidates(string)
  if !len(a:string)
    return []
  endif
  let result = Cmd2#ext#complete#ScanBuffer(a:string)
  let result = Cmd2#ext#complete#Uniq(result)
  call Cmd2#ext#complete#Sort(result, g:Cmd2__complete_ignorecase)
  return result
endfunction

function! Cmd2#ext#complete#ScanBuffer(string)
  let old_view = winsaveview()
  let matches = []
  call cursor(1,1)
  let pattern = call(g:Cmd2__complete_pattern_func, [a:string])
  let match = search(pattern, 'cW')
  while match
    let matches += Cmd2#ext#complete#GetMatchesOnLine(match, pattern, a:string)
    if match == line('$')
      break
    else
      call cursor((getpos('.')[1] + 1), 1)
      let match = search(pattern, 'cW')
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
  while i < len(substitute(a:string, '.', 'x', 'g'))
    let char = matchstr(a:string, ".", byteidx(a:string, i))
    if char == '\'
      if i == len(substitute(a:string, '.', 'x', 'g'))
        let char .= '\'
      else
        let char .= matchstr(a:string, ".", byteidx(a:string, i+1))
      endif
      let offset = 1
    else
      let offset = 0
    endif
    let result .= char
    let result .= a:pattern
    let i += 1 + offset
  endwhile
  return result
endfunction

function! Cmd2#ext#complete#StringToMatch()
  return call(g:Cmd2__complete_get_string, [])
endfunction

function! Cmd2#ext#complete#GetString()
  return matchstr(s:old_cmd[0], g:Cmd2__complete_string_pattern)
endfunction

function! Cmd2#ext#complete#GetTempOutput()
  let g:Cmd2_pending_cmd[0] = s:old_cmd[0][0 : -len(Cmd2#ext#complete#StringToMatch()) - 1]
  let current = g:Cmd2_menu.Current()
  if type(current) == 4
    return current.value
  else
    return current
  endif
endfunction

function! Cmd2#ext#complete#GetOutput()
  let g:Cmd2_pending_cmd[0] = s:old_cmd[0][0 : -len(Cmd2#ext#complete#StringToMatch()) - 1]
  let string = g:Cmd2_menu.Current()
  if type(string) == 4
    return string.value
  else
    return string
  endif
endfunction

function! Cmd2#ext#complete#GetCmdSubstring(str)
  let string = Cmd2#ext#complete#StringToMatch()
  return a:str[len(string) : -1]
endfunction

function! Cmd2#ext#complete#Conceal(candidates)
  let result = []
  for candidate in a:candidates
    let concealed = candidate
    for key in keys(g:Cmd2__complete_conceal_patterns)
      let concealed = substitute(concealed, key, g:Cmd2__complete_conceal_patterns[key], 'g')
    endfor
    call add(result, {'text': concealed, 'value': candidate})
  endfor
  return result
endfunction

function! Cmd2#ext#complete#Incsearch()
  if g:Cmd2__complete_incsearch
    call Cmd2#ext#complete#ClearIncsearchHl()
    call search(g:Cmd2_pending_cmd[0] . g:Cmd2_temp_output . g:Cmd2_pending_cmd[1])
    call Cmd2#ext#complete#AddInsearchHl(g:Cmd2_pending_cmd[0] . g:Cmd2_temp_output . g:Cmd2_pending_cmd[1])
  endif
endfunction

function! Cmd2#ext#complete#ClearIncsearchHl()
  if exists('s:Cmd2_incsearch_hl')
    call matchdelete(s:Cmd2_incsearch_hl)
    unlet s:Cmd2_incsearch_hl
  endif
endfunction

function! Cmd2#ext#complete#AddInsearchHl(string)
  let s:Cmd2_incsearch_hl = matchadd('IncSearch', a:string)
endfunction

function! Cmd2#ext#complete#InContext()
  let pos = getcmdpos()
  let cmdline = getcmdline()[0 : pos]
  return !wildmenumode() && (getcmdtype() =~ '\v[?/]' || match(cmdline, '\v[gs][?/]\k*$') >= 0)
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
    call sort(a:candidates, 'Cmd2#ext#complete#CompareIgnoreCase')
  else
    call sort(a:candidates, 'Cmd2#ext#complete#Compare')
  endif
endfunction

function! Cmd2#ext#complete#MRUIndex()
  return g:Cmd2_search_mru_hash
endfunction

function! Cmd2#ext#complete#CompareIgnoreCase(a1, a2)
  let MRUIndex = Cmd2#ext#complete#MRUIndex()
  let index_a1 = get(MRUIndex, a:a1, len(g:Cmd2_search_mru))
  let index_a2 = get(MRUIndex, a:a2, len(g:Cmd2_search_mru))
  if index_a2 < 0
    let index_a2 = len(g:Cmd2_search_mru)
  endif
  if index_a1 < index_a2
    return -1
  elseif index_a1 > index_a2
    return 1
  else
    let a1 = tolower(a:a1)
    let a2 = tolower(a:a2)
    return a1 == a2 ? 0 : (a1 < a2 ? -1 : 1)
  endif
endfunction

function! Cmd2#ext#complete#Compare(a1, a2)
  let MRUIndex = Cmd2#ext#complete#MRUIndex()
  let index_a1 = get(MRUIndex, a:a1, len(g:Cmd2_search_mru))
  let index_a2 = get(MRUIndex, a:a2, len(g:Cmd2_search_mru))
  if index_a2 < 0
    let index_a2 = len(g:Cmd2_search_mru)
  endif
  if index_a1 < index_a2
    return -1
  elseif index_a1 > index_a2
    return 1
  else
    return a:a1 == a:a2 ? 0 : (a:a1 < a:a2 ? -1 : 1)
  endif
endfunction

function! Cmd2#ext#complete#AddToMRU(string)
  if g:Cmd2__complete_mru_length <= 0 || len(a:string) == 0
    return
  endif
  if len(g:Cmd2_search_mru) > g:Cmd2__complete_mru_length
    call remove(g:Cmd2_search_mru, -1)
  endif
  let index = index(g:Cmd2_search_mru, a:string)
  if index >= 0
    call remove(g:Cmd2_search_mru, index)
  endif
  call insert(g:Cmd2_search_mru, a:string)

  let result = {}
  let i = 0
  while i < len(g:Cmd2_search_mru)
    let result[g:Cmd2_search_mru[i]] = i
    let i += 1
  endwhile
  let g:Cmd2_search_mru_hash = result
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo

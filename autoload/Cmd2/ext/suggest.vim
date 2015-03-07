let s:save_cpo = &cpo
set cpo&vim

function! Cmd2#ext#suggest#Autoload()
  " do nothing
endfunction

let s:Cmdline = {}

function! Cmd2#ext#suggest#Module()
  return s:Cmdline
endfunction

function! Cmd2#ext#suggest#New(args)
  return Cmd2#ext#suggest#Module().New(a:args)
endfunction

function! s:Cmdline.New()
  let cmdline = copy(self)
  let state = {
        \ 'mapped_input': [],
        \ }
  let args = {
        \ 'render': Cmd2#render#New().WithInsertCursor().WithMenu(),
        \ 'handle': Cmd2#ext#suggest#Handle(),
        \ 'finish': Cmd2#ext#suggest#Finish(),
        \ 'loop': Cmd2#loop#New(),
        \ 'state': state,
        \ }
  let module = Cmd2#module#New(args)
  let module.render.temp_hl = g:Cmd2__suggest_complete_hl
  let module.render.post_temp_hl = g:Cmd2__suggest_hl
  let module.cmdline = cmdline
  let module.previous_item = ''
  let module.original_cmd0 = ''
  let module.menu = Cmd2#menu#New([])
  let cmdline.module = module
  return cmdline
endfunction

function! s:Cmdline.Run()
  let old_menu = g:Cmd2_menu
  let self.module.old_cursor_text = g:Cmd2_cursor_text
  try
    let self.module.active_menu = 0
    call feedkeys(g:Cmd2_leftover_key)
    let g:Cmd2_leftover_key = ""
    call self.module.Run()
  finally
    let g:Cmd2_menu = old_menu
    let g:Cmd2_cursor_text = self.module.old_cursor_text
  endtry
endfunction

let s:Handle = {}

function! Cmd2#ext#suggest#Handle()
  return copy(s:Handle)
endfunction

function! s:Handle.Module(module)
  let self.module = a:module
  return self
endfunction

let g:Cmd2_cmdline_history = 0
let g:Cmd2_cmdline_history_cmd = ['', '']
let g:Cmd2_cmdline_history_new = 1

let s:ignore_history = ["\<Up>", "\<Down>", "\<Left>", "\<Right>"]
let s:keep_menu = ["\<Tab>", "\<S-Tab>", "\<Up>", "\<Down>", "\<C-N>", "\<C-P>", ]
let s:reject_complete = ["\<BS>", "\<Del>"]
let s:hide_complete = ["\<BS>", "\<Del>", "\<Left>", "\<Right>", "\<Tab>", "\<S-Tab>", "\<C-N>", "\<C-P>", "\<Esc>"]
let s:no_reenter = ["\<C-R>", "\<C-\>", "\<C-C>", "\<C-Q>", "\<C-V>", "\<C-K>"]
let s:no_event = [
      \ "<LeftMouse>", "<C-LeftMouse>", "<S-LeftMouse>", "<2-LeftMouse>", "<3-LeftMouse>", "<4-LeftMouse>",
      \ "<MiddleMouse>",
      \ "<RightMouse>", "<C-RightMouse>", "<S-RightMouse>", "<A-RightMouse>",
      \ "<LeftDrag>", "<LeftRelease>", "<MiddleMouse>", "<MiddleDrag>", "<MiddleRelease>", "<RightDrag>", "<RightRelease>",
      \ "<X1Mouse>", "<X1Drag>", "<X1Release>", "<X2Mouse>", "<X2Drag>", "<X2Release>",
      \ ]

function! s:Handle.Run(input)
  let force_menu = 0
  let had_menu = 0
  if !g:Cmd2__suggest_show_suggest
    let g:Cmd2_post_temp_output = ''
  endif
  if g:Cmd2_cmdline_history_new
    let g:Cmd2_cmdline_history_new = 0
    let g:Cmd2_cmdline_history = 0
    let g:Cmd2_cmdline_history_cmd = deepcopy(g:Cmd2_pending_cmd)
  endif
  if index(s:keep_menu, a:input) == -1
    if self.module.active_menu
      let g:Cmd2_pending_cmd[0] .= g:Cmd2_temp_output
      let had_menu = 1
      let self.module.active_menu = 0
    endif
    let g:Cmd2_temp_output = ''
  endif
  call add(self.module.state.mapped_input, a:input)
  let maps = Cmd2#ext#suggest#GetCmap(self.module.state.mapped_input)
  if len(maps)
    let self.module.state.start_timeout = 1
    let self.module.state.start_time = reltime()
    let result = Cmd2#ext#suggest#GetNormalKeys(self.module.state.mapped_input)
    if len(maps) == 1 && result ==# maps[0]
      let g:Cmd2_leftover_key = join(self.module.state.mapped_input, '')
      let self.module.state.stopped = 1
      let self.module.state.mapped_input = []
      let g:Cmd2_cmdline_history_new = 1
    else
      if a:input != "\<Plug>"
        let g:Cmd2_cursor_text = get(s:special_key_map, a:input, a:input)
      endif
      let self.module.state.force_render = 1
      call self.module.Render()
    endif
    return
  elseif len(self.module.state.mapped_input) > 1
    let self.module.state.stopped = 1
    return
  endif
  let previous_cmd0 = g:Cmd2_pending_cmd[0]
  let g:Cmd2_cursor_text = self.module.old_cursor_text
  let self.module.state.mapped_input = []
  if a:input == "\<CR>"
    let self.module.state.stopped = 1
    let g:Cmd2_cmdline_history_new = 1
    let g:Cmd2_leftover_key = a:input
  elseif a:input == "\<Esc>"
    if had_menu && g:Cmd2__suggest_esc_menu
      let g:Cmd2_pending_cmd[0] = self.module.original_cmd0
    else
      let self.module.state.stopped = 1
      call histadd(g:Cmd2_cmd_type, g:Cmd2_pending_cmd[0] . g:Cmd2_pending_cmd[1])
      let g:Cmd2_leftover_key = "\<C-C>"
    endif
  elseif a:input == "\<Left>"
    if len(g:Cmd2_pending_cmd[0])
      let char = g:Cmd2_pending_cmd[0][-1:]
      let g:Cmd2_pending_cmd[0] = g:Cmd2_pending_cmd[0][0:-2]
      let g:Cmd2_pending_cmd[1] = char . g:Cmd2_pending_cmd[1]
    endif
  elseif a:input == "\<Right>"
    if len(g:Cmd2_post_temp_output)
      let g:Cmd2_pending_cmd[0] .= g:Cmd2_post_temp_output
      let g:Cmd2_post_temp_output = ''
    elseif len(g:Cmd2_pending_cmd[1])
      let char = g:Cmd2_pending_cmd[1][0]
      let g:Cmd2_pending_cmd[0] .= char
      let g:Cmd2_pending_cmd[1] = g:Cmd2_pending_cmd[1][1:]
    endif
  elseif a:input == "\<BS>"
    if len(g:Cmd2_post_temp_output)
      let g:Cmd2_post_temp_output = ''
    elseif len(g:Cmd2_pending_cmd[0])
      let g:Cmd2_pending_cmd[0] = g:Cmd2_pending_cmd[0][0:-2]
    elseif !len(g:Cmd2_pending_cmd[1])
      let self.module.state.stopped = 1
      let g:Cmd2_leftover_key = "\<C-C>"
    endif
  elseif a:input == "\<Del>"
    if len(g:Cmd2_post_temp_output)
      let g:Cmd2_post_temp_output = ''
    elseif len(g:Cmd2_pending_cmd[1])
      let g:Cmd2_pending_cmd[1] = g:Cmd2_pending_cmd[1][1:]
    endif
  elseif a:input == "\<Up>"
    if self.module.active_menu
      let split_terms = Cmd2#ext#suggest#SplitWithDir(g:Cmd2_pending_cmd[0] . g:Cmd2_temp_output)
      let last_term = len(split_terms) ? split_terms[-1] : ''
      if Cmd2#ext#suggest#IsDir(last_term)
        let last_term = substitute(last_term, '\\ ', ' ', 'g')
        if len(self.module.menu.pages)
          let fname = fnamemodify(last_term, ':h:h:h')
        else
          let fname = fnamemodify(last_term, ':h:h')
        endif
        let escape_fname = substitute(fname, ' ', '\\ ', 'g')
        let g:Cmd2_pending_cmd[0] = join(split_terms[0 : -2], ' ') . ' '
        " if split_terms[-1] =~ '\k'
          " let leftover = substitute(split_terms[-1], '\(.\{-}\)\k.*', '\1', 'g')
        " else
          " let leftover = split_terms[-1]
        " endif
        let g:Cmd2_pending_cmd[0] .= escape_fname . '/'
        let last_term = substitute(last_term, '\\ ', ' ', 'g')
        if len(self.module.menu.pages)
          let fname = fnamemodify(last_term, ':h:h')
        else
          let fname = fnamemodify(last_term, ':h')
        endif
        if fname == '.'
          let escape_fname = substitute(last_term, ' ', '\\ ', 'g')
        else
          let escape_fname = substitute(fname, ' ', '\\ ', 'g')
        endif
        let escape_fname .= escape_fname[-1 :] == '/' ? '' : '/'
        let self.module.previous_item = escape_fname
        let had_menu = 1
        let g:Cmd2_temp_output = ''
        let force_menu = 1
      elseif len(glob(last_term))
        let last_term = substitute(last_term, '\\ ', ' ', 'g')
          let fname = fnamemodify(last_term, ':h:h')
          let escape_fname = substitute(fname, ' ', '\\ ', 'g')
          let g:Cmd2_pending_cmd[0] = join(split_terms[0 : -2], ' ') . ' '
          let g:Cmd2_pending_cmd[0] .= escape_fname . '/'
          let fname = fnamemodify(last_term, ':h')
        let escape_fname = substitute(fname, ' ', '\\ ', 'g')
        let escape_fname .= escape_fname[-1 :] == '/' ? '' : '/'
        let self.module.previous_item = escape_fname
        let had_menu = 1
        let g:Cmd2_temp_output = ''
        let force_menu = 1
      endif
    else
      " to see if we can't go <Up> - <Up> cancels the whole cmdline if it fails so _temp does not get the key
      let g:Cmd2_cmdline_temp = {}
      execute "silent normal! :" . g:Cmd2_cmdline_history_cmd[0] . g:Cmd2_cmdline_history_cmd[1]
            \ . repeat("\<Up>", g:Cmd2_cmdline_history + 1) . "\<C-\>eextend(g:Cmd2_cmdline_temp,{'a': 1}).a\n"
      if len(g:Cmd2_cmdline_temp)
        let g:Cmd2_cmdline_history += 1
        let g:Cmd2_pending_cmd = deepcopy(g:Cmd2_cmdline_history_cmd)
      let g:Cmd2_leftover_key = repeat("\<Up>", g:Cmd2_cmdline_history) . "\<Plug>(Cmd2Cmdline)"
      let self.module.state.stopped = 1
    endif
  endif
  elseif a:input == "\<Down>"
    if self.module.active_menu
      let split = Cmd2#ext#suggest#SplitWithDir(g:Cmd2_pending_cmd[0] . g:Cmd2_temp_output)
      let last_term = len(split) ? split[-1] : ''
      if Cmd2#ext#suggest#IsDir(last_term)
        let g:Cmd2_pending_cmd[0] .= g:Cmd2_temp_output
        let had_menu = 1
        let g:Cmd2_temp_output = ''
        let force_menu = 1
      endif
    elseif g:Cmd2_cmdline_history > 0
      let g:Cmd2_cmdline_history -= 1
      let g:Cmd2_pending_cmd = deepcopy(g:Cmd2_cmdline_history_cmd)
      let g:Cmd2_leftover_key = repeat("\<Up>", g:Cmd2_cmdline_history) . "\<Plug>(Cmd2Cmdline)"
      let self.module.state.stopped = 1
    endif
  elseif a:input == "\<Tab>" || a:input == "\<S-Tab>" || a:input == "\<C-N>" || a:input == "\<C-P>"
    if !self.module.active_menu
      let self.module.original_cmd0 = g:Cmd2_pending_cmd[0]
    endif
    if !len(self.module.menu.pages) || !len(self.module.menu.pages[0])
      let force_menu = 1
    elseif len(self.module.menu.pages) == 1 && len(self.module.menu.pages[0]) == 1 && !self.module.active_menu
      let menu_current = self.module.menu.Current()
      let current = type(menu_current) == 4 ? menu_current.value : menu_current
      let split_terms = Cmd2#ext#suggest#SplitWithDir(g:Cmd2_pending_cmd[0])
      " for tab to complete and go to next menu
      if g:Cmd2__suggest_jump_complete
        let g:Cmd2_pending_cmd[0] = join(split_terms[0 : -2], ' ') . (len(split_terms) > 1 ? ' ' : '')
        let g:Cmd2_pending_cmd[0] .= current
      else
        let self.module.previous_item = current
      endif
      " if split_terms[-1] =~ '\k'
        " let leftover = substitute(split_terms[-1], '\(.\{-}\)\k.*', '\1', 'g')
      " else
        " let leftover = split_terms[-1]
      " endif
      let had_menu = 1
      let g:Cmd2_temp_output = ''
      let force_menu = 1
      let self.module.active_menu = 1
    else
      if a:input == "\<Tab>" || a:input == "\<C-N>"
        call self.module.menu.Next()
      else
        call self.module.menu.Previous()
      endif
      let menu_current = self.module.menu.Current()
      let current = type(menu_current) == 4 ? menu_current.value : menu_current
      if g:Cmd2_pending_cmd[0][-1 :] == ' ' || !len(g:Cmd2_pending_cmd[0])
        let g:Cmd2_temp_output = current
      else
        let split_terms = Cmd2#ext#suggest#SplitWithDir(g:Cmd2_pending_cmd[0])
        let g:Cmd2_pending_cmd[0] = join(split_terms[0 : -2], ' ') . (len(split_terms) > 1 ? ' ' : '')
        " if split_terms[-1] =~ '\k'
          " let leftover = substitute(split_terms[-1], '\(.\{-}\)\k.*', '\1', 'g')
        " else
          " let leftover = split_terms[-1]
        " endif
        " let g:Cmd2_pending_cmd[0] .= leftover
        let g:Cmd2_temp_output = current
      endif
      let self.module.active_menu = 1
      let g:Cmd2_post_temp_output = ''
    endif
  elseif has_key(s:special_key_map, a:input)
    if index(s:no_event, a:input) == -1
      let g:Cmd2_leftover_key = a:input
      if index(s:no_reenter, a:input) == -1
        let g:Cmd2_leftover_key .= "\<Plug>(Cmd2Cmdline)"
      endif
      let self.module.state.stopped = 1
    endif
  else
    let g:Cmd2_pending_cmd[0] .= a:input
  endif
  if index(s:keep_menu, a:input) == -1 || force_menu
    let results = Cmd2#ext#suggest#GetCandidates(force_menu)
    let split = Cmd2#ext#suggest#SplitWithDir(g:Cmd2_pending_cmd[0])
    let last_term = len(split) ? split[-1] : ''
    if last_term == '.\' || last_term == './'
      let conceal = 0
    else
      let conceal = Cmd2#ext#suggest#IsDir(last_term) ? len(last_term) : 0
    endif
    let result = Cmd2#ext#suggest#Conceal(results, conceal)
    call self.module.cmdline.CreateMenu(result, a:input)
  endif
  if index(s:hide_complete, a:input) != -1
    let g:Cmd2_post_temp_output = ''
  endif
  let self.module.state.start_time = reltime()
  let self.module.state.current_time = self.module.state.start_time
  let self.module.state.force_render = 1
  call self.module.Render()
  if index(s:ignore_history, a:input) == -1
    let g:Cmd2_cmdline_history_new = 1
  endif
endfunction

function! s:Cmdline.CreateMenu(results, input)
  let self.module.menu = Cmd2#menu#New(a:results)
  let menu_current = self.module.menu.Current()
  let current = type(menu_current) == 4 ? menu_current.value : menu_current
  let self.module.menu.pos = [0, -1]
  let self.module.menu.empty_render = 1
  if self.module.active_menu
    if len(self.module.previous_item)
      let g:a = self.module.previous_item
      let g:b = self.module.menu
      let self.module.menu.pos = self.module.menu.Find(self.module.previous_item)
      if self.module.menu.pos == [-1, -1]
        let self.module.menu.pos = [0, 0]
      endif
      let self.module.previous_item = ''
    else
      let self.module.menu.pos = [0, 0]
    endif
    let menu_current = self.module.menu.Current()
    let current = type(menu_current) == 4 ? menu_current.value : menu_current
    if len(current)
      if g:Cmd2_pending_cmd[0][-1 :] == ' ' || !len(g:Cmd2_pending_cmd[0])
        let g:Cmd2_temp_output = current
      else
        let split_terms = Cmd2#ext#suggest#SplitWithDir(g:Cmd2_pending_cmd[0])
        let g:Cmd2_pending_cmd[0] = join(split_terms[0 : -2], ' ') . (len(split_terms) > 1 ? ' ' : '')
        let g:Cmd2_temp_output = current
      endif
    endif
    let g:Cmd2_post_temp_output = ''
  elseif index(s:hide_complete, a:input) != -1
    " do nothing
  elseif g:Cmd2_pending_cmd[0][-1 :] == ' '
    let g:Cmd2_post_temp_output = current
  else
    let split_terms = Cmd2#ext#suggest#SplitWithDir(g:Cmd2_pending_cmd[0])
    if len(split_terms)
      if current[0 : len(split_terms[-1]) - 1] == split_terms[-1]
        let g:Cmd2_post_temp_output = current[len(split_terms[-1]) :]
      else
        let g:Cmd2_post_temp_output = ''
      endif
    else
      let g:Cmd2_post_temp_output = current
    endif
  endif
  let g:Cmd2_menu = self.module.menu
endfunction

let s:Finish = {}

function! Cmd2#ext#suggest#Finish()
  return copy(s:Finish)
endfunction

function! s:Finish.Module(module)
  let self.module = a:module
  return self
endfunction

function! s:Finish.Run()
  if len(self.module.state.mapped_input)
    let i = 0
    let has_cmap = -1
    while i < len(self.module.state.mapped_input)
      let cmap = Cmd2#ext#suggest#GetCmap(self.module.state.mapped_input[0:i])
      if !len(cmap)
        break
      elseif index(cmap, join(self.module.state.mapped_input[0:i], '')) >= 0
        let has_cmap = i
        break
      endif
      let i += 1
    endwhile
    let g:Cmd2_leftover_key = join(self.module.state.mapped_input[0:-2], '')
    if has_cmap == -1
      let g:Cmd2_leftover_key .= "\<Plug>(Cmd2Cmdline)"
            \ . self.module.state.mapped_input[-1]
    endif
    let g:Cmd2_cmdline_history_new = 1
  endif
endfunction

function! Cmd2#ext#suggest#GetCandidates(force_menu)
  if g:Cmd2_pending_cmd[0][-1 :] =~ '\\\@<![[\]()~''".,]'
    return []
  else
    for no_complete in g:Cmd2__suggest_no_complete
      if g:Cmd2_pending_cmd[0] =~ no_complete
        return []
      endif
    endfor
  endif
  let tokens = Cmd2#ext#suggest#SplitWithDir(g:Cmd2_pending_cmd[0])
  if !len(tokens) || (g:Cmd2_pending_cmd[0][-1 :] == ' ' && !g:Cmd2__suggest_space_trigger && !a:force_menu)
    return []
  elseif (len(tokens[-1]) < g:Cmd2__suggest_min_length) && !a:force_menu
    return []
  endif
  let g:Cmd2_cmdline_temp = {}
  let old_shellslash = &shellslash
  set shellslash
  try
    execute "silent normal! :" . g:Cmd2_pending_cmd[0]
          \ . "\<C-A>" . "\<C-\>eextend(g:Cmd2_cmdline_temp,{'cmdline': getcmdline()}).cmdline\n"
  catch
    let g:Cmd2_cmdline_temp = {}
  finally
    let &shellslash = old_shellslash
  endtry
  if has_key(g:Cmd2_cmdline_temp, 'cmdline') && g:Cmd2_cmdline_temp['cmdline'] != g:Cmd2_pending_cmd[0] . ''
    let completions = Cmd2#ext#suggest#SplitWithDir(g:Cmd2_cmdline_temp.cmdline)
    let terms = Cmd2#ext#suggest#SplitWithDir(g:Cmd2_pending_cmd[0])
    if terms[-1] == './' || terms[-1] == '.\'
      let result = []
      for completion in completions
        if completion[0 : len(terms[-1]) - 1] ==# terms[-1]
          call add(result, completion[len(terms[-1]) :])
        else
          call add(result, completion)
        endif
      endfor
      let completions = result
    endif
    if g:Cmd2_pending_cmd[0][-1 :] == ' ' || !len(g:Cmd2_pending_cmd[0])
      call add(terms, '')
    endif
    let complete_terms = len(terms)
    let results = completions[complete_terms - 1 :]
  else
    let results = []
  endif
  return results
endfunction

function! Cmd2#ext#suggest#SplitWithDir(line)
  let split_terms = split(a:line, '\\\@<!\s\+')
  return split_terms
endfunction

function! Cmd2#ext#suggest#IsDir(string)
  let string = substitute(a:string, '\\ ', ' ', 'g')
  return isdirectory(string)
endfunction

function! Cmd2#ext#suggest#Conceal(results, conceal)
  let result = []
  for candidate in a:results
    let concealed = candidate
    call add(result, {'text': (candidate[a:conceal :]), 'value': candidate})
  endfor
  return result
endfunction

" https://github.com/osyo-manga/vital-over/blob/master/autoload/vital/__latest__/Over/String.vim#L148
let s:special_keys = [
      \ 'BS', 'Down', 'Up', 'Left', 'Right', 'Home', 'End', 'Insert', 'Delete', 'PageUp', 'PageDown', 'F1',
      \ 'F2', 'F3', 'F4', 'F5', 'F6', 'F7', 'F8', 'F9', 'F10', 'F11', 'F12',
      \ 'A-BS', 'A-Down', 'A-Up', 'A-Left', 'A-Right', 'A-Home', 'A-End', 'A-Insert', 'A-Delete', 'A-PageUp', 'A-PageDown',
      \ 'A-F1', 'A-F2', 'A-F3', 'A-F4', 'A-F5', 'A-F6', 'A-F7', 'A-F8', 'A-F9', 'A-F10', 'A-F11', 'A-F12', 'A-Tab',
      \ 'C-BS', 'C-Down', 'C-Up', 'C-Left', 'C-Right', 'C-Home', 'C-End', 'C-Insert', 'C-Delete', 'C-PageUp', 'C-PageDown', 'C-Tab',
      \ 'C-F1', 'C-F2', 'C-F3', 'C-F4', 'C-F5', 'C-F6', 'C-F7', 'C-F8', 'C-F9', 'C-F10', 'C-F11', 'C-F12',
      \ 'S-Down', 'S-Up', 'S-Left', 'S-Right', 'S-Home', 'S-Insert', 'S-PageUp', 'S-PageDown', 'S-Tab', 'S-Space',
      \ 'S-F1', 'S-F2', 'S-F3', 'S-F4', 'S-F5', 'S-F6', 'S-F7', 'S-F8', 'S-F9', 'S-F10', 'S-F11', 'S-F12',
      \ 'C-A', 'C-B', 'C-C', 'C-D', 'C-E', 'C-F',
      \ 'C-G', 'C-H', 'C-I', 'C-J', 'C-K', 'C-L', 'C-M',
      \ 'C-N', 'C-O', 'C-P', 'C-Q', 'C-R', 'C-S', 'C-T',
      \ 'C-U', 'C-V', 'C-W', 'C-X', 'C-Y', 'C-Z',
      \ 'C-\',
      \ 'LeftMouse', 'C-LeftMouse', 'S-LeftMouse', '2-LeftMouse', '3-LeftMouse', '4-LeftMouse',
      \ 'MiddleMouse',
      \ 'RightMouse', 'C-RightMouse', 'S-RightMouse', 'A-RightMouse',
      \ 'LeftDrag', 'LeftRelease', 'MiddleMouse', 'MiddleDrag', 'MiddleRelease', 'RightDrag', 'RightRelease',
      \ 'X1Mouse', 'X1Drag', 'X1Release', 'X2Mouse', 'X2Drag', 'X2Release',
      \ 'Plug'
      \ ]

let s:special_key_map = {}

for key in s:special_keys
  let key = '<' . key . '>'
  " https://github.com/junegunn/vim-pseudocl/blob/master/autoload/pseudocl/render.vim#L273
  let eval_key = substitute(key, '.*', '\=eval("\"\\".submatch(0)."\"")', 'g')
  let s:special_key_map[eval_key] = key
endfor

let s:special_key_map["\<CR>"] = '<CR>'

function! Cmd2#ext#suggest#GetCmap(cmap)
  let cmap = Cmd2#ext#suggest#GetNormalKeys(a:cmap)
  let string = ''
  redir => string
  execute 'silent cmap ' . cmap
  redir END
  redraw
  let lines = split(string, '\n')
  if len(lines) == 1 && lines[0] ==# 'No mapping found'
    return []
  else
    let result = []
    for line in lines
      let cmap_keys = substitute(line, '\v.\s+(.{-})\s+.*', '\1', 'g')
      if cmap_keys =~ '\V\^' . cmap
        call add(result, cmap_keys)
      endif
    endfor
    return result
  endif
endfunction

function! Cmd2#ext#suggest#GetNormalKeys(keys)
  let result = []
  for map in a:keys
    call add(result, get(s:special_key_map, map, map))
  endfor
  return join(result, '')
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo

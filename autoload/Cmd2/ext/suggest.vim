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
  let module.render.post_temp_hl = g:Cmd2__suggest_suggest_hl
  let module.cmdline = cmdline
  let module.previous_item = ''
  let module.original_cmd0 = ''
  let module.menu_type = ''
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
    let self.module.menu = Cmd2#menu#New([])
    let self.module.menu.empty_render = 1
    let g:Cmd2_menu = self.module.menu
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
let s:no_reenter = ["\<C-R>", "\<C-\>", "\<C-C>", "\<C-Q>", "\<C-V>", "\<C-K>", "\<S-CR>"]
let s:no_event = [
      \ "<LeftMouse>", "<C-LeftMouse>", "<S-LeftMouse>", "<2-LeftMouse>", "<3-LeftMouse>", "<4-LeftMouse>",
      \ "<MiddleMouse>",
      \ "<RightMouse>", "<C-RightMouse>", "<S-RightMouse>", "<A-RightMouse>",
      \ "<LeftDrag>", "<LeftRelease>", "<MiddleMouse>", "<MiddleDrag>", "<MiddleRelease>", "<RightDrag>", "<RightRelease>",
      \ "<X1Mouse>", "<X1Drag>", "<X1Release>", "<X2Mouse>", "<X2Drag>", "<X2Release>",
      \ ]

let g:d = []
function! s:Handle.Run(input)
  let force_menu = 0
  let had_active_menu = 0
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
      let had_active_menu = 1
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
    if self.module.menu_type == 'search'
      if len(self.module.menu.pages) && len(self.module.menu.pages[0])
            \ && ((g:Cmd2__suggest_enter_search_complete == 2)
            \ || (g:Cmd2__suggest_enter_search_complete == 1 && len(self.module.menu.pages) == 1 && len(self.module.menu.pages[0]) == 1))
        if self.module.menu.pos == [0, -1]
          let menu_current = self.module.menu.pages[0][0]
        else
          let menu_current = self.module.menu.Current()
        endif
        let current = type(menu_current) == 4 ? menu_current.value : menu_current
        let g:Cmd2_pending_cmd[0] = current
      endif
      " let g:Cmd2_pending_cmd[0] = escape(g:Cmd2_pending_cmd[0], '.\/~^$')
    elseif len(self.module.menu.pages) && len(self.module.menu.pages[0])
          \ && ((g:Cmd2__suggest_enter_suggest == 2)
          \ || (g:Cmd2__suggest_enter_suggest == 1 && len(self.module.menu.pages) == 1 && len(self.module.menu.pages[0]) == 1))
      let g:Cmd2_pending_cmd[0] .= g:Cmd2_post_temp_output
    endif
    let self.module.state.stopped = 1
    let g:Cmd2_cmdline_history_new = 1
    let g:Cmd2_leftover_key = a:input
  elseif a:input == "\<Esc>"
    if had_active_menu && g:Cmd2__suggest_esc_menu
      let g:Cmd2_pending_cmd[0] = self.module.original_cmd0
    else
      let self.module.state.stopped = 1
      call histadd(g:Cmd2_cmd_type, g:Cmd2_pending_cmd[0] . g:Cmd2_pending_cmd[1])
      let g:Cmd2_leftover_key = "\<C-C>"
    endif
  elseif a:input == "\<Left>"
    if len(g:Cmd2_pending_cmd[0])
      let [initial, last] = Cmd2#ext#suggest#InitialAndLast(g:Cmd2_pending_cmd[0])
      let g:Cmd2_pending_cmd[0] = initial
      let g:Cmd2_pending_cmd[1] = last . g:Cmd2_pending_cmd[1]
    endif
  elseif a:input == "\<Right>"
    if len(g:Cmd2_post_temp_output)
      let g:Cmd2_pending_cmd[0] .= g:Cmd2_post_temp_output
      let g:Cmd2_post_temp_output = ''
    elseif len(g:Cmd2_pending_cmd[1])
      let [head, tail] = Cmd2#ext#suggest#HeadAndTail(g:Cmd2_pending_cmd[1])
      let g:Cmd2_pending_cmd[0] .= head
      let g:Cmd2_pending_cmd[1] = tail
    endif
  elseif a:input == "\<BS>"
    if len(g:Cmd2_post_temp_output) && g:Cmd2__suggest_bs_suggest
      let g:Cmd2_post_temp_output = ''
    elseif len(g:Cmd2_pending_cmd[0])
      let [initial, last] = Cmd2#ext#suggest#InitialAndLast(g:Cmd2_pending_cmd[0])
      let g:Cmd2_pending_cmd[0] = initial
    elseif !len(g:Cmd2_pending_cmd[1])
      let self.module.state.stopped = 1
      let g:Cmd2_leftover_key = "\<C-C>"
    endif
  elseif a:input == "\<Del>"
    if len(g:Cmd2_post_temp_output)
      let g:Cmd2_post_temp_output = ''
    elseif len(g:Cmd2_pending_cmd[1])
      let [head, tail] = Cmd2#ext#suggest#HeadAndTail(g:Cmd2_pending_cmd[1])
      let g:Cmd2_pending_cmd[1] = tail
    endif
  elseif a:input == "\<Up>"
    if self.module.active_menu && self.module.menu_type != 'search'
      let split_terms = Cmd2#ext#suggest#SplitTokens(g:Cmd2_pending_cmd[0] . g:Cmd2_temp_output)
      let last_term = len(split_terms) ? split_terms[-1] : ''
      if Cmd2#ext#suggest#IsDir(last_term)
        let last_term = substitute(last_term, '\m\\ ', ' ', 'g')
        if len(self.module.menu.pages)
          let fname = fnamemodify(last_term, ':h:h:h')
        else
          let fname = fnamemodify(last_term, ':h:h')
        endif
        let escape_fname = substitute(fname, '\m ', '\\ ', 'g')
        let g:Cmd2_pending_cmd[0] = join(split_terms[0 : -2], ' ') . ' '
        " if split_terms[-1] =~ '\k'
        " let leftover = substitute(split_terms[-1], '\(.\{-}\)\k.*', '\1', 'g')
        " else
        " let leftover = split_terms[-1]
        " endif
        let g:Cmd2_pending_cmd[0] .= escape_fname . '/'
        let last_term = substitute(last_term, '\m\\ ', ' ', 'g')
        if len(self.module.menu.pages)
          let fname = fnamemodify(last_term, ':h:h')
        else
          let fname = fnamemodify(last_term, ':h')
        endif
        if fname == '.'
          let escape_fname = substitute(last_term, '\m ', '\\ ', 'g')
        else
          let escape_fname = substitute(fname, '\m ', '\\ ', 'g')
        endif
        let escape_fname .= escape_fname[-1 :] == '/' ? '' : '/'
        let self.module.previous_item = escape_fname
        let had_active_menu = 1
        let g:Cmd2_temp_output = ''
        let force_menu = 1
      elseif len(glob(last_term))
        let last_term = substitute(last_term, '\m\\ ', ' ', 'g')
        let fname = fnamemodify(last_term, ':h:h')
        let escape_fname = substitute(fname, '\m ', '\\ ', 'g')
        let g:Cmd2_pending_cmd[0] = join(split_terms[0 : -2], ' ') . ' '
        let g:Cmd2_pending_cmd[0] .= escape_fname . '/'
        let fname = fnamemodify(last_term, ':h')
        let escape_fname = substitute(fname, '\m ', '\\ ', 'g')
        let escape_fname .= escape_fname[-1 :] == '/' ? '' : '/'
        let self.module.previous_item = escape_fname
        let had_active_menu = 1
        let g:Cmd2_temp_output = ''
        let force_menu = 1
      endif
    else
      " to see if we can't go <Up> - <Up> cancels the whole cmdline if it fails so _temp does not get the key
      try
        let g:Cmd2_cmdline_temp = {}
        execute "silent normal! :" . g:Cmd2_cmdline_history_cmd[0] . g:Cmd2_cmdline_history_cmd[1]
              \ . repeat("\<Up>", g:Cmd2_cmdline_history + 1) . "\<C-\>eextend(g:Cmd2_cmdline_temp,{'a': 1}).a\n"
      catch
        let g:Cmd2_cmdline_temp = {}
      endtry
      if len(g:Cmd2_cmdline_temp)
        let g:Cmd2_cmdline_history += 1
        let g:Cmd2_pending_cmd = deepcopy(g:Cmd2_cmdline_history_cmd)
        let g:Cmd2_leftover_key = repeat("\<Up>", g:Cmd2_cmdline_history) . "\<Plug>(Cmd2Cmdline)"
        let self.module.state.stopped = 1
      endif
    endif
  elseif a:input == "\<Down>"
    if self.module.active_menu && self.module.menu_type != 'search'
      let split = Cmd2#ext#suggest#SplitTokens(g:Cmd2_pending_cmd[0] . g:Cmd2_temp_output)
      let last_term = len(split) ? split[-1] : ''
      if Cmd2#ext#suggest#IsDir(last_term)
        let g:Cmd2_pending_cmd[0] .= g:Cmd2_temp_output
        let had_active_menu = 1
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
        if self.module.menu_type == 'search'
          let g:Cmd2_pending_cmd[0] = current
          let had_active_menu = 1
          let g:Cmd2_temp_output = ''
          let force_menu = 1
          let self.module.active_menu = 1
        else
          let split_terms = Cmd2#ext#suggest#SplitTokens(g:Cmd2_pending_cmd[0])
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
          let had_active_menu = 1
          let g:Cmd2_temp_output = ''
          let force_menu = 1
          let self.module.active_menu = 1
        endif
      else
        let stop = 0
        if g:Cmd2__suggest_tab_longest && g:Cmd2_cmd_type != '/'
          let old_shellslash = &shellslash
          set shellslash
          let g:Cmd2_cmdline_temp = {}
          try
            execute "silent normal! :" . g:Cmd2_pending_cmd[0]
                  \ . "\<C-L>" . "\<C-\>eextend(g:Cmd2_cmdline_temp,{'cmdline': getcmdline()}).cmdline\n"
          catch
            let g:Cmd2_cmdline_temp = {}
          finally
            let &shellslash = old_shellslash
          endtry
          if has_key(g:Cmd2_cmdline_temp, 'cmdline') && g:Cmd2_cmdline_temp['cmdline'] != g:Cmd2_pending_cmd[0]
                \ && g:Cmd2_cmdline_temp['cmdline'] != g:Cmd2_pending_cmd[0] . "\<C-L>"
            let g:Cmd2_pending_cmd[0] = g:Cmd2_cmdline_temp.cmdline
            let stop = 1
          endif
        endif
        if !stop
          if a:input == "\<Tab>" || a:input == "\<C-N>"
            call self.module.menu.Next()
          else
            call self.module.menu.Previous()
          endif
          let menu_current = self.module.menu.Current()
          let current = type(menu_current) == 4 ? menu_current.value : menu_current
          if self.module.menu_type == 'search'
            let g:Cmd2_pending_cmd[0] = ''
            let g:Cmd2_temp_output = current
          else
            if g:Cmd2_pending_cmd[0][-1 :] == ' ' || !len(g:Cmd2_pending_cmd[0])
              let g:Cmd2_temp_output = current
            else
              let split_terms = Cmd2#ext#suggest#SplitTokens(g:Cmd2_pending_cmd[0])
              let g:Cmd2_pending_cmd[0] = join(split_terms[0 : -2], ' ') . (len(split_terms) > 1 ? ' ' : '')
              " if split_terms[-1] =~ '\k'
              " let leftover = substitute(split_terms[-1], '\(.\{-}\)\k.*', '\1', 'g')
              " else
              " let leftover = split_terms[-1]
              " endif
              " let g:Cmd2_pending_cmd[0] .= leftover
              let g:Cmd2_temp_output = current
            endif
          endif
          let self.module.active_menu = 1
          let g:Cmd2_post_temp_output = ''
        endif
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
    let candidates = Cmd2#ext#suggest#GetCandidates(self.module, force_menu)
    let split = Cmd2#ext#suggest#SplitTokens(g:Cmd2_pending_cmd[0])
    let last_term = len(split) ? split[-1] : ''
    if self.module.menu_type == 'search'
      let result = Cmd2#ext#complete#Conceal(candidates)
    else
      if last_term == '.\' || last_term == './' || last_term == '.'
        let conceal = 0
      elseif len(split) && split[-1][0 : 1] == 'no'
            \  && len(candidates) && exists('+' . candidates[0][2 :])
        let conceal = 2
      elseif len(split) && split[-1][0] == '&'
            \  && len(candidates) && exists('&' . candidates[0][1 :])
        let conceal = 1
      else
        let conceal = Cmd2#ext#suggest#IsDir(last_term) ? len(last_term) : 0
      endif
      let result = Cmd2#ext#suggest#Conceal(candidates, conceal)
    endif
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
    if self.module.menu_type == 'search'
      let g:Cmd2_pending_cmd[0] = ''
      let g:Cmd2_temp_output = current
    elseif len(current)
      if g:Cmd2_pending_cmd[0][-1 :] == ' ' || !len(g:Cmd2_pending_cmd[0])
        let g:Cmd2_temp_output = current
      else
        let split_terms = Cmd2#ext#suggest#SplitTokens(g:Cmd2_pending_cmd[0])
        let g:Cmd2_pending_cmd[0] = join(split_terms[0 : -2], ' ') . (len(split_terms) > 1 ? ' ' : '')
        let g:Cmd2_temp_output = current
      endif
    endif
    let g:Cmd2_post_temp_output = ''
  elseif index(s:hide_complete, a:input) != -1
    " do nothing
  elseif self.module.menu_type == 'search'
    if current[0 : len(g:Cmd2_pending_cmd[0]) - 1] ==# g:Cmd2_pending_cmd[0]
      let g:Cmd2_post_temp_output = current[len(g:Cmd2_pending_cmd[0]) :]
    else
      let g:Cmd2_post_temp_output = ''
    endif
  elseif g:Cmd2_pending_cmd[0][-1 :] == ' '
    let g:Cmd2_post_temp_output = current
  else
    let split_terms = Cmd2#ext#suggest#SplitTokens(g:Cmd2_pending_cmd[0])
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
      else
        let keys = Cmd2#ext#suggest#GetNormalKeys(self.module.state.mapped_input[0:i])
        if index(cmap, keys) >= 0
          let has_cmap = i
          break
        endif
      endif
      let i += 1
    endwhile
    if has_cmap == -1
      let g:d = self.module.state.mapped_input
      let g:Cmd2_leftover_key = join(self.module.state.mapped_input[0:-2], '')
      let g:Cmd2_leftover_key .= "\<Plug>(Cmd2Cmdline)"
            \ . self.module.state.mapped_input[-1]
    else
      let g:Cmd2_leftover_key = join(self.module.state.mapped_input, '')
    endif
    let g:Cmd2_cmdline_history_new = 1
  endif
endfunction

let s:abbrev = {
      \ 'a': 'append',
      \ 'b': 'buffer',
      \ 'c': 'change',
      \ 'd': 'delete',
      \ 'e': 'edit',
      \ 'f': 'file',
      \ 'g': 'global',
      \ 'h': 'help',
      \ 'i': 'insert',
      \ 'j': 'join',
      \ 'k': 'k',
      \ 'l': 'list',
      \ 'm': 'move',
      \ 'n': 'next',
      \ 'o': 'open',
      \ 'p': 'print',
      \ 'q': 'quit',
      \ 'r': 'read',
      \ 's': 'substitute',
      \ 't': 't',
      \ 'u': 'undo',
      \ 'v': 'vglobal',
      \ 'w': 'write',
      \ 'x': 'xit',
      \ 'y': 'yank',
      \ 'z': 'z',
      \ }

function! Cmd2#ext#suggest#GetCandidates(module, force_menu)
  if len(g:Cmd2_pending_cmd[1]) && !g:Cmd2__suggest_middle_trigger
    return []
  endif
  if g:Cmd2_cmd_type == '/'
    let string = g:Cmd2_pending_cmd[0]
    if !len(string) || len(string) < g:Cmd2__suggest_min_length
      return []
    endif
    let a:module.menu_type = 'search'
    let candidates = call(g:Cmd2__complete_generate, [g:Cmd2_pending_cmd[0]])
    return candidates
  endif
  if g:Cmd2_pending_cmd[0][-1 :] =~ '\m\\\@<![(''",[]' || g:Cmd2_pending_cmd[0] !~ '\a'
    return []
  elseif !a:force_menu
    for no_trigger in g:Cmd2__suggest_no_trigger
      if g:Cmd2_pending_cmd[0] =~ no_trigger
        return []
      endif
    endfor
  endif
  let tokens = Cmd2#ext#suggest#SplitTokens(g:Cmd2_pending_cmd[0])
  if (len(tokens[-1]) < g:Cmd2__suggest_min_length) && !a:force_menu
    return []
  endif
  let g:Cmd2_cmdline_temp = {}
  let old_shellslash = &shellslash
  set shellslash
  let cmd_to_test = Cmd2#util#EscapeFeed(g:Cmd2_pending_cmd[0])
  try
    execute "silent normal! :" . cmd_to_test
          \ . "\<C-A>" . "\<C-\>eextend(g:Cmd2_cmdline_temp,{'cmdline': getcmdline()}).cmdline\n"
  catch
    let g:Cmd2_cmdline_temp = {}
  finally
    let &shellslash = old_shellslash
  endtry
  if has_key(g:Cmd2_cmdline_temp, 'cmdline') && g:Cmd2_cmdline_temp['cmdline'] != g:Cmd2_pending_cmd[0] . ''
    let complete_tokens = Cmd2#ext#suggest#SplitTokens(g:Cmd2_cmdline_temp.cmdline)
    let terms = Cmd2#ext#suggest#SplitTokens(g:Cmd2_pending_cmd[0])
    if g:Cmd2_pending_cmd[0][-1 :] == ' ' || !len(g:Cmd2_pending_cmd[0])
      call add(terms, ' ')
    endif
    let completions = complete_tokens[len(terms) - 1 :]
    if has_key(s:abbrev, terms[-1]) && len(terms) == 1
      let index = index(completions, terms[-1])
      call remove(completions, index)
      call insert(completions, s:abbrev[terms[-1]])
      let results = completions
    elseif terms[-1] == './' || terms[-1] == '.\'
      let a:module.menu_type = 'dir_current'
      let result = []
      for completion in completions
        if completion[0 : len(terms[-1]) - 1] ==# terms[-1]
          call add(result, completion[len(terms[-1]) :])
        else
          call add(result, completion)
        endif
      endfor
      let results = result
    elseif terms[-1][0] == '&' && exists('&' . completions[0][1:])
      let a:module.menu_type = 'variable_&'
      let i = 1
      while i < len(completions)
        let completions[i] = '&' . completions[i]
        let i += 1
      endwhile
      let results = completions
    elseif terms[-1][0 : 1] == 'no' && exists('+' . completions[0][2:])
      let a:module.menu_type = 'option_no'
      let i = 1
      while i < len(completions)
        let completions[i] = 'no' . completions[i]
        let i += 1
      endwhile
      let results = completions
    elseif len(g:Cmd2_pending_cmd[0]) && g:Cmd2_pending_cmd[0][-1 :] != ' '  && Cmd2#util#IsMenu(terms[-1])
      let a:module.menu_type = 'menu'
      let result = completions
      let menu = join(split(terms[-1], '\m\.', 1)[0 : -2], '.')
      for completion in completions
        call add(result, menu . '.' . completion)
      endfor
      let results = result
    else
      let a:module.menu_type = 'default'
      let results = completions
    endif
  else
    let results = []
  endif
  return results
endfunction

function! Cmd2#ext#suggest#SplitTokens(line)
  let split_terms = split(a:line, '\m\%(\\\|\@<!\)\@<!\s\+')
  return split_terms
endfunction

function! Cmd2#ext#suggest#IsDir(string)
  let string = substitute(a:string, '\m\\ ', ' ', 'g')
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
      \ 'Plug',
      \ 'S-BS', 'C-BS', 'A-BS',
      \ 'S-CR', 'C-CR',
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

function! Cmd2#ext#suggest#InitialAndLast(string)
  let len = len(substitute(a:string, '\m.', 'x', 'g'))
  let char = matchstr(a:string, ".", byteidx(a:string, len - 1))
  return [a:string[0 : -len(char) - 1], char]
endfunction

function! Cmd2#ext#suggest#HeadAndTail(string)
  let len = len(substitute(a:string, '\m.', 'x', 'g'))
  let char = matchstr(a:string, ".", byteidx(a:string, 0))
  return [char, a:string[len(char) : -1]]
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo

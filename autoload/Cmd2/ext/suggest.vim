let s:save_cpo = &cpo
set cpo&vim

function! Cmd2#ext#suggest#Autoload()
  " do nothing
endfunction

let s:Suggest = copy(Cmd2#module#Module())

function! Cmd2#ext#suggest#Module()
  return s:Suggest
endfunction

function! s:Suggest.New()
  let suggest = copy(self)
  let state = {
        \ 'mapped_input': [],
        \ 'force_render': 1,
        \ }
  let render = g:Cmd2__suggest_render
  let eval_render = eval(render)
  let args = {
        \ 'render': eval(g:Cmd2__suggest_render),
        \ 'handle': Cmd2#ext#suggest#Handle(),
        \ 'finish': Cmd2#ext#suggest#Finish(),
        \ 'loop': Cmd2#loop#New(),
        \ 'state': state,
        \ }
  call suggest.Init(args)
  let suggest.render.temp_hl = g:Cmd2__suggest_complete_hl
  let suggest.render.post_temp_hl = g:Cmd2__suggest_suggest_hl
  let suggest.suggest = suggest
  let suggest.previous_item = ''
  let suggest.original_cmd0 = ''
  let suggest.original_view = winsaveview()
  let suggest.menu_type = ''
  let suggest.rest_view = 1
  let suggest.active_menu = 0
  let suggest.force_menu = 0
  let suggest.new_menu = 0
  let suggest.had_active_menu = 0
  return suggest
endfunction

function! s:Suggest.Run()
  let old_menu = g:Cmd2_menu
  let self.old_cursor_text = g:Cmd2_cursor_text
  try
    call feedkeys(g:Cmd2_leftover_key)
    let g:Cmd2_leftover_key = ""
    call self.render.UpdateCmd(g:Cmd2_pending_cmd[0])
    call self.handle.Menu('')
    call self.render.UpdateCmd('')
    call self.handle.SimulateSearch('')
    call self.render.Run()
    call self.loop.Run()
    if self.rest_view
      call winrestview(self.original_view)
    endif
    call self.finish.Run()
  finally
    let g:Cmd2_menu = old_menu
    let g:Cmd2_cursor_text = self.old_cursor_text
    call self.ClearIncSearch()
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
let s:reject_complete = ["\<BS>", "\<Del>"]
let s:hide_suggest = ["\<BS>", "\<Del>", "\<Left>", "\<Right>", "\<Tab>", "\<S-Tab>", "\<C-N>", "\<C-P>", "\<Esc>", "\<Up>", "\<Down>"]
let s:no_reenter = ["\<C-R>", "\<C-\>", "\<C-C>", "\<C-Q>", "\<C-V>", "\<C-K>", "\<S-CR>", "\<C-A>", "\<C-D>", "\<C-F>","\<C-J>"]
let s:no_event = [
      \ "<LeftMouse>", "<C-LeftMouse>", "<S-LeftMouse>", "<2-LeftMouse>", "<3-LeftMouse>", "<4-LeftMouse>",
      \ "<MiddleMouse>",
      \ "<RightMouse>", "<C-RightMouse>", "<S-RightMouse>", "<A-RightMouse>",
      \ "<LeftDrag>", "<LeftRelease>", "<MiddleMouse>", "<MiddleDrag>", "<MiddleRelease>", "<RightDrag>", "<RightRelease>",
      \ "<X1Mouse>", "<X1Drag>", "<X1Release>", "<X2Mouse>", "<X2Drag>", "<X2Release>",
      \ ]

function! s:Handle.Run(input)

  " prepare new state
  call self.PreRun(a:input)

  " handle cmaps
  " Cmaps returns 1 if handler should exit
  if self.Cmaps(a:input)
    return
  endif

  if a:input == "\<CR>"
    call self.CR(a:input)
  elseif a:input == "\<Esc>"
    call self.Esc(a:input)
  elseif a:input == "\<Left>"
    call self.Left(a:input)
  elseif a:input == "\<Right>"
    call self.Right(a:input)
  elseif a:input == "\<BS>"
    call self.BS(a:input)
  elseif a:input == "\<Del>"
    call self.Del(a:input)
  elseif a:input == "\<Up>"
    call self.Up(a:input)
  elseif a:input == "\<Down>"
    call self.Down(a:input)
  elseif a:input == "\<Tab>" || a:input == "\<S-Tab>" || a:input == "\<C-N>" || a:input == "\<C-P>"
    call self.Tab(a:input)
  elseif has_key(s:special_key_map, a:input)
    call self.SpecialKey(a:input)
  else
    call self.CloseMenu()
    let g:Cmd2_pending_cmd[0] .= a:input
    let self.module.new_menu = 1
  endif

  if self.module.active_menu
    call self.module.render.UpdateCmd(self.module.original_cmd0)
  else
    call self.module.render.UpdateCmd(g:Cmd2_pending_cmd[0])
  endif

  if self.module.new_menu || self.module.force_menu
    call self.Menu(a:input)
  endif

  call self.SimulateSearch(a:input)

  call self.PostRun(a:input)
endfunction

function! s:Handle.SimulateSearch(input)
  if self.module.menu_type == 'search' && a:input != "\<CR>" && a:input != "\<Esc>"
    if self.module.active_menu
      let menu_current = self.module.menu.Current()
      let query = type(menu_current) == 4 ? menu_current.value : menu_current
    else
      let query = self.GetSearchQuery()
    endif
    if len(query)
      let flag = g:Cmd2_cmd_type == '/' ? '' : 'b'
      if g:Cmd2__suggest_incsearch
        call winrestview(self.module.original_view)
        try
          call search(query, flag)
        catch
        endtry
        call self.module.ClearIncSearch()
        try
          let self.module.incsearch_match = matchadd('IncSearch', '\%#' . query)
        catch
        endtry
      endif
      if g:Cmd2__suggest_hlsearch
        let @/ = query
        set hls
      endif
    endif
  endif
endfunction

function! s:Suggest.ClearIncSearch()
  if exists('self.incsearch_match')
    call matchdelete(self.incsearch_match)
    unlet self.incsearch_match
  endif
endfunction

function! s:Handle.PreRun(input)
  let self.module.force_menu = 0
  let self.module.new_menu = 0
  let self.module.had_active_menu = 0
  if !g:Cmd2__suggest_show_suggest
    let g:Cmd2_post_temp_output = ''
  endif
  if g:Cmd2_cmdline_history_new
    let g:Cmd2_cmdline_history_new = 0
    let g:Cmd2_cmdline_history = 0
    let g:Cmd2_cmdline_history_cmd = deepcopy(g:Cmd2_pending_cmd)
  endif
endfunction

function! s:Handle.CloseMenu()
  if self.module.active_menu
    let g:Cmd2_pending_cmd[0] .= g:Cmd2_temp_output
    let self.module.had_active_menu = 1
    let self.module.active_menu = 0
  endif
  let g:Cmd2_temp_output = ''
endfunction

function! s:Handle.Cmaps(input)

  " return 1 if handler should exit
  call add(self.module.state.mapped_input, a:input)
  let maps = Cmd2#ext#suggest#GetCmap(self.module.state.mapped_input)
  if len(maps)
    let self.module.state.start_timeout = 1
    let self.module.state.start_time = reltime()
    let result = Cmd2#ext#suggest#GetNormalKeys(self.module.state.mapped_input)
    if len(maps) == 1 && result ==# maps[0]
      let g:Cmd2_pending_cmd[0] .= g:Cmd2_temp_output
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
    return 1
  elseif len(self.module.state.mapped_input) > 1
    let self.module.state.stopped = 1
    return 1
  endif

  let self.module.previous_cmd0 = g:Cmd2_pending_cmd[0]
  let g:Cmd2_cursor_text = self.module.old_cursor_text
  let self.module.state.mapped_input = []

  return 0
endfunction

function! s:Handle.GetSearchQuery()
    " check if enter_search_complete is activated
    if (g:Cmd2__suggest_enter_search_complete == 2 && len(self.module.menu.pages) && len(self.module.menu.pages[0]))
          \ || (g:Cmd2__suggest_enter_search_complete == 1 && len(self.module.menu.pages) == 1 && len(self.module.menu.pages[0]) == 1)
      if self.module.menu.pos == [0, -1]
        let menu_current = self.module.menu.pages[0][0]
      else
        let menu_current = self.module.menu.Current()
      endif
      let current = type(menu_current) == 4 ? menu_current.value : menu_current
      return current
    endif
    return g:Cmd2_pending_cmd[0]
endfunction

function! s:Handle.CR(input)
  call self.CloseMenu()
  if self.module.menu_type == 'search'

    let g:Cmd2_pending_cmd[0] = self.GetSearchQuery()
    " let g:Cmd2_pending_cmd[0] = escape(g:Cmd2_pending_cmd[0], '.\/~^$')

    " check if enter_suggest is activated
  elseif (g:Cmd2__suggest_enter_suggest == 2 && len(self.module.menu.pages) && len(self.module.menu.pages[0]))
        \ || (g:Cmd2__suggest_enter_suggest == 1 && len(self.module.menu.pages) == 1 && len(self.module.menu.pages[0]) == 1)
    let g:Cmd2_pending_cmd[0] .= g:Cmd2_post_temp_output
  endif

  if self.module.menu_type == 'search'
    call Cmd2#ext#complete#AddToMRU(g:Cmd2_pending_cmd[0])
  endif

  let cmd = g:Cmd2_pending_cmd[0] . g:Cmd2_pending_cmd[1]

  if g:Cmd2__suggest_incsearch && self.module.menu_type == 'search' && len(cmd)
    call histadd(g:Cmd2_cmd_type, cmd)
    let self.module.rest_view = 0
    call winrestview(self.module.original_view)

    let flag = g:Cmd2_cmd_type == '/' ? '' : 'b'
    try
      call search(cmd, flag)
    catch
    endtry
    let @/ = cmd
    let g:Cmd2_feed_cmdline = 0
    if g:Cmd2__suggest_hlsearch
      let g:Cmd2_leftover_key = "\<Plug>(Cmd2_hls)"
    endif
  else
    let g:Cmd2_leftover_key = a:input
  endif

  let self.module.state.stopped = 1
endfunction

function! s:Handle.Esc(input)
  if self.module.active_menu && g:Cmd2__suggest_esc_menu
    let g:Cmd2_pending_cmd[0] = self.module.original_cmd0
    let self.module.active_menu = 0
    let g:Cmd2_temp_output = ''
    let self.module.new_menu = 1
  else
    let self.module.state.stopped = 1
    call histadd(g:Cmd2_cmd_type, g:Cmd2_pending_cmd[0] . g:Cmd2_pending_cmd[1])

    " clear pending_cmd since when cmd exceeds cmdheight
    " echo more msg will appear
    let g:Cmd2_pending_cmd = ['', '']
    let g:Cmd2_leftover_key = "\<C-C>"
    if g:Cmd2__suggest_hlsearch
      let g:Cmd2_leftover_key .= "\<Plug>(Cmd2_nohls)"
    endif
  endif
endfunction

function! s:Handle.Left(input)
  call self.CloseMenu()
  if len(g:Cmd2_pending_cmd[0])
    let [initial, last] = Cmd2#ext#suggest#InitialAndLast(g:Cmd2_pending_cmd[0])
    let g:Cmd2_pending_cmd[0] = initial
    let g:Cmd2_pending_cmd[1] = last . g:Cmd2_pending_cmd[1]
  endif
  let self.module.new_menu = 1
endfunction

function! s:Handle.Right(input)
  call self.CloseMenu()
  if len(g:Cmd2_post_temp_output)
    let g:Cmd2_pending_cmd[0] .= g:Cmd2_post_temp_output
    let g:Cmd2_post_temp_output = ''
  elseif len(g:Cmd2_pending_cmd[1])
    let [head, tail] = Cmd2#ext#suggest#HeadAndTail(g:Cmd2_pending_cmd[1])
    let g:Cmd2_pending_cmd[0] .= head
    let g:Cmd2_pending_cmd[1] = tail
  endif
  let self.module.new_menu = 1
endfunction

function! s:Handle.BS(input)
  call self.CloseMenu()
  if len(g:Cmd2_post_temp_output) && g:Cmd2__suggest_bs_suggest
    let g:Cmd2_post_temp_output = ''
  elseif len(g:Cmd2_pending_cmd[0])
    let [initial, last] = Cmd2#ext#suggest#InitialAndLast(g:Cmd2_pending_cmd[0])
    let g:Cmd2_pending_cmd[0] = initial
  elseif !len(g:Cmd2_pending_cmd[1])
    let self.module.state.stopped = 1
    let g:Cmd2_leftover_key = "\<C-C>"
  endif
  let self.module.new_menu = 1
endfunction

function! s:Handle.Del(input)
  call self.CloseMenu()
  if len(g:Cmd2_post_temp_output)
    let g:Cmd2_post_temp_output = ''
  elseif len(g:Cmd2_pending_cmd[1])
    let [head, tail] = Cmd2#ext#suggest#HeadAndTail(g:Cmd2_pending_cmd[1])
    let g:Cmd2_pending_cmd[1] = tail
  endif
  let self.module.new_menu = 1
endfun

function! s:Handle.Up(input)
  if self.module.active_menu && self.module.menu_type != 'search'
    let split_terms = Cmd2#ext#suggest#SplitTokens(g:Cmd2_pending_cmd[0] . g:Cmd2_temp_output)
    let last_term = len(split_terms) ? split_terms[-1] : ''

    if Cmd2#ext#suggest#IsDir(last_term)

      " find parent dir
      " e.g. a/b/c/
      " use :h:h:h to find a, :h:h to find b and set b as last term
      let last_term = substitute(last_term, '\m\\ ', ' ', 'g')
      let fname = fnamemodify(last_term, ':h:h:h')
      let escape_fname = substitute(fname, '\m ', '\\ ', 'g')
      let g:Cmd2_pending_cmd[0] = join(split_terms[0 : -2], ' ') . ' '

      " create menu of parent's parent directory
      " find position of parent directory in the new menu
      let g:Cmd2_pending_cmd[0] .= escape_fname . '/'
      let last_term = substitute(last_term, '\m\\ ', ' ', 'g')
      let fname = fnamemodify(last_term, ':h:h')
      if fname == '.'
        let escape_fname = substitute(last_term, '\m ', '\\ ', 'g')
      else
        let escape_fname = substitute(fname, '\m ', '\\ ', 'g')
      endif
      let escape_fname .= escape_fname[-1 :] == '/' ? '' : '/'
      let self.module.previous_item = escape_fname
      let self.module.had_active_menu = 1
      let g:Cmd2_temp_output = ''
      let self.module.new_menu = 1

    elseif len(glob(last_term))

      " same thing but with file
      " e.g. a/b/c
      " use :h:h to find a, :h to find b
      let last_term = substitute(last_term, '\m\\ ', ' ', 'g')
      let fname = fnamemodify(last_term, ':h:h')
      let escape_fname = substitute(fname, '\m ', '\\ ', 'g')
      let g:Cmd2_pending_cmd[0] = join(split_terms[0 : -2], ' ') . ' '
      let g:Cmd2_pending_cmd[0] .= escape_fname . '/'
      let fname = fnamemodify(last_term, ':h')
      let escape_fname = substitute(fname, '\m ', '\\ ', 'g')
      let escape_fname .= escape_fname[-1 :] == '/' ? '' : '/'
      let self.module.previous_item = escape_fname
      let self.module.had_active_menu = 1
      let g:Cmd2_temp_output = ''
      let self.module.new_menu = 1
    endif
  else
    call self.CloseMenu()
    " feed history_cmd and press Up * history count
    try
      let g:Cmd2_cmdline_temp = {}
      execute "silent normal! " . g:Cmd2_cmd_type . g:Cmd2_cmdline_history_cmd[0] . g:Cmd2_cmdline_history_cmd[1]
            \ . repeat("\<Up>", g:Cmd2_cmdline_history + 1) . "\<C-\>eextend(g:Cmd2_cmdline_temp,{'cmdline': getcmdline()}).cmdline\n\<C-U>"
    catch
      let g:Cmd2_cmdline_temp = {}
    endtry
    if len(g:Cmd2_cmdline_temp)
      let g:Cmd2_cmdline_history += 1
      let g:Cmd2_pending_cmd[0] = g:Cmd2_cmdline_temp.cmdline
      let g:Cmd2_pending_cmd[1] = ''
    endif
    let self.module.new_menu = 1
  endif
endfunction

function! s:Handle.Down(input)

  " set current completion as pending_cmd and force_menu
  if self.module.active_menu && self.module.menu_type != 'search'
    let split = Cmd2#ext#suggest#SplitTokens(g:Cmd2_pending_cmd[0] . g:Cmd2_temp_output)
    let last_term = len(split) ? split[-1] : ''
    if Cmd2#ext#suggest#IsDir(last_term)
      let g:Cmd2_pending_cmd[0] .= g:Cmd2_temp_output
      let self.module.had_active_menu = 1
      let g:Cmd2_temp_output = ''
      let self.module.new_menu = 1
    endif
  elseif g:Cmd2_cmdline_history >= 0
    if g:Cmd2_cmdline_history == 0
      let g:Cmd2_pending_cmd = deepcopy(g:Cmd2_cmdline_history_cmd)
    else
      let g:Cmd2_cmdline_history -= 1

      " feed history_cmd and press Up * history count
      try
        let g:Cmd2_cmdline_temp = {}
        execute "silent normal! " . g:Cmd2_cmd_type . g:Cmd2_cmdline_history_cmd[0] . g:Cmd2_cmdline_history_cmd[1]
              \ . repeat("\<Up>", g:Cmd2_cmdline_history) . "\<C-\>eextend(g:Cmd2_cmdline_temp,{'cmdline': getcmdline()}).cmdline\n\<C-U>"
      catch
        let g:Cmd2_cmdline_temp = {'cmdline': ''}
      endtry
      let g:Cmd2_pending_cmd[0] = g:Cmd2_cmdline_temp.cmdline
      let g:Cmd2_pending_cmd[1] = ''
    endif
    let self.module.new_menu = 1
  endif
endfunction

function! s:Handle.Tab(input)

  " save command to revert to on <Esc>
  if !self.module.active_menu
    let self.module.original_cmd0 = g:Cmd2_pending_cmd[0]
  endif

  " if no menu, force_menu
  " if after force_menu, there is still no menu nothing will happen
  if !len(self.module.menu.pages) || !len(self.module.menu.pages[0])
    let self.module.force_menu = 1

  " if only one item, check for jump_complete
  elseif len(self.module.menu.pages) == 1 && len(self.module.menu.pages[0]) == 1 && !self.module.active_menu
        \ && self.module.menu_type != 'search'
    let menu_current = self.module.menu.Current()
    let current = type(menu_current) == 4 ? menu_current.value : menu_current
    let split_terms = Cmd2#ext#suggest#SplitTokens(g:Cmd2_pending_cmd[0])
    " for tab to complete and go to next menu
    if g:Cmd2__suggest_jump_complete
      let g:Cmd2_pending_cmd[0] = join(split_terms[0 : -2], ' ') . (len(split_terms) > 1 ? ' ' : '')
      let g:Cmd2_pending_cmd[0] .= current
    else
      let self.module.previous_item = current
    endif
    let self.module.had_active_menu = 1
    let g:Cmd2_temp_output = ''
    let self.module.new_menu = 1
    let self.module.active_menu = 1
  else

    " check for suggest_tab_longest
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
        call self.module.render.UpdateCmd(g:Cmd2_pending_cmd[0])
        let self.module.new_menu = 1
        let stop = 1
      endif
    endif

    if !stop

      " normal menu movements
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
          let g:Cmd2_temp_output = current
        endif
      endif
      let self.module.active_menu = 1
      let g:Cmd2_post_temp_output = ''
    endif
  endif
endfunction

function! s:Handle.SpecialKey(input)
  let self.module.new_menu = 1
  if index(s:no_event, a:input) == -1
    let g:Cmd2_leftover_key = a:input
    if index(s:no_reenter, a:input) == -1
      let g:Cmd2_leftover_key .= "\<Plug>(Cmd2Suggest)"
    endif
    let self.module.state.stopped = 1
  endif
  let self.module.new_menu = 1
endfunction

function! s:Handle.PostRun(input)
  if index(s:hide_suggest, a:input) != -1
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

function! s:Handle.Menu(input)
  let start = reltime()

  " get candidates
  " if force_menu, don't catch errors
  if !self.module.force_menu
    try
      let candidates = Cmd2#ext#suggest#GetCandidates(self.module, self.module.force_menu)
    catch
      let candidates = []
    endtry
  else
    let candidates = Cmd2#ext#suggest#GetCandidates(self.module, self.module.force_menu)
  endif

  if g:Cmd2__suggest_search_profile && self.module.menu_type == 'search' && len(g:Cmd2_pending_cmd[0])
    let g:Cmd2_profile = get(g:, 'Cmd2_profile', [])
    let time = Cmd2#util#GetRelTimeMs(start, reltime())
    call add(g:Cmd2_profile, {g:Cmd2_pending_cmd[0] : time})
  endif

  let split = Cmd2#ext#suggest#SplitTokens(g:Cmd2_pending_cmd[0])
  let last_term = len(split) ? split[-1] : ''

  " conceal
  if self.module.menu_type == 'search'
    let result = Cmd2#ext#complete#Conceal(candidates)
  else
    if last_term == '.\' || last_term == './' || last_term == '.'
      let conceal = 0
    elseif self.module.menu_type == 'option_no'
      let conceal = 2
    elseif self.module.menu_type == 'option_&'
      let conceal = 1
    else
      let conceal = Cmd2#ext#suggest#IsDir(last_term) ? len(last_term) : 0
    endif
    let result = Cmd2#ext#suggest#Conceal(candidates, conceal)
  endif
  call self.module.suggest.CreateMenu(result, a:input)
endfunction

function! s:Suggest.CreateMenu(results, input)
  let self.menu = Cmd2#menu#New(a:results, self.render.menu_columns)
  let menu_current = self.menu.Current()
  let current = type(menu_current) == 4 ? menu_current.value : menu_current
  let self.menu.pos = [0, -1]
  let self.menu.empty_render = 1

  " in active_menu, select previous item or first item
  if self.active_menu
    if len(self.previous_item)
      let self.menu.pos = self.menu.Find(self.previous_item)
      if self.menu.pos == [-1, -1]
        let self.menu.pos = [0, 0]
      endif
      let self.previous_item = ''
    else
      let self.menu.pos = [0, 0]
    endif
    let menu_current = self.menu.Current()
    let current = type(menu_current) == 4 ? menu_current.value : menu_current
    if self.menu_type == 'search'
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
  elseif index(s:hide_suggest, a:input) != -1
    " do nothing

  " check to for post_temp_output
  elseif self.menu_type == 'search'
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

  let g:Cmd2_menu = self.menu
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

  " finish only called when a cmap is stopped halfway
  if len(self.module.state.mapped_input)
    let g:Cmd2_pending_cmd[0] .= g:Cmd2_temp_output
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
      let g:Cmd2_leftover_key = join(self.module.state.mapped_input[0:-2], '')
      let g:Cmd2_leftover_key .= "\<Plug>(Cmd2Suggest)"
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

function! Cmd2#ext#suggest#GetSearchCandidates(module, force_menu)
  let string = g:Cmd2_pending_cmd[0]
  if (!len(string) || len(string) < g:Cmd2__suggest_min_length) && !a:force_menu
    return []
  endif
  let a:module.menu_type = 'search'
  let candidates = call(g:Cmd2__complete_generate, [g:Cmd2_pending_cmd[0]])
  return candidates
endfunction

function! Cmd2#ext#suggest#GetCandidates(module, force_menu)

  if len(g:Cmd2_pending_cmd[1]) && !g:Cmd2__suggest_middle_trigger && !a:force_menu
    return []
  endif
  if g:Cmd2_cmd_type == '/' || g:Cmd2_cmd_type == '?'
    return Cmd2#ext#suggest#GetSearchCandidates(a:module, a:force_menu)
  endif
  if g:Cmd2_pending_cmd[0][-1 :] =~ '\V\[\\@<![(''",]'
        \ && !a:force_menu
    " these characters if at the end of the cmd will create a huge list of
    " suggestons, so we stop unless force_menu
    return []
  elseif !a:force_menu
    for no_trigger in g:Cmd2__suggest_no_trigger
      if g:Cmd2_pending_cmd[0] =~ no_trigger
        return []
      endif
    endfor
  endif

  let tokens = Cmd2#ext#suggest#SplitTokens(g:Cmd2_pending_cmd[0])

  if !a:force_menu && (empty(tokens) || (len(tokens[-1]) < g:Cmd2__suggest_min_length))
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
    return Cmd2#ext#suggest#ParseCompletions(terms, completions, a:module)
  els
    return []
  endif
endfunction

function! Cmd2#ext#suggest#ParseCompletions(terms, completions, module)
  let completions = a:completions

  " check for abbreviations
  if has_key(s:abbrev, a:terms[-1]) && len(a:terms) == 1
    let index = index(completions, a:terms[-1])
    call remove(completions, index)
    call insert(completions, s:abbrev[a:terms[-1]])
    return completions

  " if ./ or .\ results will start with ./dir
  elseif a:terms[-1] == './' || a:terms[-1] == '.\'
    let a:module.menu_type = 'dir_current'
    let result = []
    for completion in completions
      if completion[0 : len(a:terms[-1]) - 1] ==# a:terms[-1]
        call add(result, completion[len(a:terms[-1]) :])
      else
        call add(result, completion)
      endif
    endfor
    return result

  " if &option, results will start with &
  elseif a:terms[-1][0] == '&' && (exists('&' . completions[0][1:]) || completions[0][1:] == 'all')
    let a:module.menu_type = 'option_&'
    let i = 1
    while i < len(completions)
      let completions[i] = '&' . completions[i]
      let i += 1
    endwhile
    return completions

  " if nooption, results will start with no
  elseif a:terms[-1][0 : 1] == 'no' && exists('+' . completions[0][2:])
    let a:module.menu_type = 'option_no'
    let i = 1
    while i < len(completions)
      let completions[i] = 'no' . completions[i]
      let i += 1
    endwhile
    return completions

  " if menu, results will start with Parent.menu
  elseif len(g:Cmd2_pending_cmd[0]) && g:Cmd2_pending_cmd[0][-1 :] != ' '  && Cmd2#util#IsMenu(a:terms[-1])
    let a:module.menu_type = 'menu'
    let result = []
    let menu = join(split(a:terms[-1], '\m\.', 1)[0 : -2], '.')
    for completion in completions
      call add(result, menu . '.' . completion)
    endfor
    return result

  else
    let a:module.menu_type = 'default'
    return completions
  endif
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

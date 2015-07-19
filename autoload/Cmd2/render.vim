let s:save_cpo = &cpo
set cpo&vim

function! Cmd2#render#Autoload()
  " do nothing
endfunction

let s:Render = {}

function! Cmd2#render#New()
  let render = copy(s:Render)
  let render.renderer = render.CmdLine()
  let render.temp_hl = 'None'
  let render.post_temp_hl = 'None'
  let render.show_cursor = 1
  let render.menu_columns = &columns
  let render.cmd = ''
  let render.old_pending_cmd = []
  let render.old_blink_state = -1
  return render
endfunction

function! s:Render.Module(module)
  let self.module = a:module
  return self
endfunction

function! s:Render.UpdateCmd(cmd)
  let self.cmd = a:cmd
endfunction

function! s:Render.WithInsertCursor()
  let self.renderer = self.CmdLineWithInsertCursor()
  return self
endfunction

function! s:Render.WithMenu()
  let self.renderer = self.CmdLineWithMenu()
  return self
endfunction

function! s:Render.GetAirlineMenuDefaults()
  return {
        \ 'name': 'Cmd2',
        \ 'sep': g:airline_left_sep,
        \ }
endfunction

function! s:Render.SetAirlineMenuOptions(options)
  let options = self.GetAirlineMenuDefaults()
  let self.airline = {}
  call extend(options, a:options, 'force')
  for key in keys(options)
    let self.airline[key] = options[key]
  endfor
endfunction

function! s:Render.WithAirlineMenu(...)
  let options = a:0 ? a:1 : {}
  call self.SetAirlineMenuOptions(options)
  " - 1 to include space after last sep,
  " - 2 to include spaces before and after name
  let self.menu_columns = &columns - 2*strdisplaywidth(self.airline.sep) - strdisplaywidth(self.airline.name) - 3
  let self.renderer = self.CmdLineWithAirlineMenu()
  return self
endfunction

function! s:Render.WithAirlineMenu2(...)
  let options = a:0 ? a:1 : {}
  call self.SetAirlineMenuOptions(options)
  let palette = g:airline#themes#{g:airline_theme}#palette
  call s:Load_theme(palette)
  let self.old_run = Cmd2#render#New().Run
  let self.renderer = self.CmdLineWithAirlineMenu2()
  function! self.Run()
    call call(self.old_run, [], self)
  endfunction
  function! self.UpdateCmd(cmd)
    let self.cmd = len(a:cmd) ? ' ' . a:cmd . ' ' : ''
    " - 1 to include space after last sep
    "- 2 to include spaces before and after name
    let self.menu_columns = &columns - len(self.cmd) - 2*strdisplaywidth(self.airline.sep) - strdisplaywidth(self.airline.name) - 3
  endfunction
  return self
endfunction

function! s:Load_theme(palette)
  if exists('a:palette.cmd2')
    let theme = a:palette.cmd2
  else
    let color_template = 'insert'
    let theme = s:Generate_color_map(
          \ a:palette[color_template]['airline_c'],
          \ a:palette[color_template]['airline_b'],
          \ a:palette[color_template]['airline_a'])
  endif
  for key in keys(theme)
    call airline#highlighter#exec(key, theme[key])
  endfor
endfunction

function! s:Generate_color_map(dark, light, white)
  return {
        \ 'Cmd2dark'   : a:dark,
        \ 'Cmd2light'  : a:light,
        \ 'Cmd2white'  : a:white,
        \ 'Cmd2arrow1' : [ a:light[1] , a:white[1] , a:light[3] , a:white[3] , ''     ] ,
        \ 'Cmd2arrow2' : [ a:white[1] , a:light[1] , a:white[3] , a:light[3] , ''     ] ,
        \ 'Cmd2arrow3' : [ a:light[1] , a:dark[1]  , a:light[3] , a:dark[3]  , ''     ] ,
        \ }
endfunction

function! s:Render.Run()
  let state = self.module.state
  if self.NeedRefresh() || state.force_render
    call Cmd2#util#SetCmdHeight()
    call Cmd2#util#SetLastStatus()
    let echo_contents = self.renderer.Run()
    call self.Render(echo_contents)
  endif
  if state.force_render == 1
    let state.force_render = 0
  endif
  let self.old_blink_state = g:Cmd2_blink_state
endfunction

function! s:Render.NeedRefresh()
  call self.CheckBlink()
  if self.old_blink_state != g:Cmd2_blink_state
    return 1
  endif
  return 0
endfunction

function! s:Render.CmdLine()
  let renderer = {}
  let renderer.render = self
  function! renderer.Run()
    let result = []
    let result += [{'text': g:Cmd2_cmd_type}]
    let result += self.render.SplitSnippet(g:Cmd2_pending_cmd[0], g:Cmd2_snippet_cursor)
    let result += [{'text': g:Cmd2_temp_output, 'hl': self.render.temp_hl}]
    if g:Cmd2_blink_state
      call add(result, {'text': g:Cmd2_cursor_text, 'hl': g:Cmd2_cursor_hl})
    else
      call add(result, {'text': g:Cmd2_cursor_text})
    endif
    let result += self.render.SplitSnippet(g:Cmd2_pending_cmd[1], g:Cmd2_snippet_cursor)
    return result
  endfunction
  return renderer
endfunction

function! s:Render.CmdLineWithInsertCursor()
  let renderer = {}
  let renderer.render = self
  function! renderer.Run()
    let result = []
    let result += [{'text': g:Cmd2_cmd_type}]
    let result += self.render.SplitSnippet(g:Cmd2_pending_cmd[0], g:Cmd2_snippet_cursor)
    let result += [{'text': g:Cmd2_temp_output, 'hl': self.render.temp_hl}]
    if len(g:Cmd2_post_temp_output) && g:Cmd2__suggest_show_suggest
      let after_cursor = [{'text': g:Cmd2_post_temp_output, 'hl' :self.render.post_temp_hl}]
    else
      let after_cursor = []
    endif
    let after_cursor += self.render.SplitSnippet(g:Cmd2_pending_cmd[1], g:Cmd2_snippet_cursor)
    if g:Cmd2_blink_state
      let first = after_cursor[0]
      if len(after_cursor[0].text)
        let char = matchstr(after_cursor[0].text, ".", byteidx(after_cursor[0].text, 0))
        let result += [{'text': char, 'hl': g:Cmd2_cursor_hl}]
        let after_cursor[0].text = after_cursor[0].text[len(char) :]
      else
        let result += [{'text': ' ', 'hl': g:Cmd2_cursor_hl}]
      endif
    endif
    let result += after_cursor
    return result
  endfunction
  return renderer
endfunction

function! s:Render.CmdLineWithMenu()
  let renderer = {}
  let renderer.render = self
  let renderer.cmdline_renderer = self.renderer
  function! renderer.Run()
    let result = []
    if has_key(g:Cmd2_menu, 'pages')
      let menu = g:Cmd2_menu.MenuLine()
      let result += menu
    endif
    let result += self.cmdline_renderer.Run()
    return result
  endfunction
  return renderer
endfunction

function! s:Render.CmdLineWithAirlineMenu()
  let renderer = {}
  let renderer.render = self
  let renderer.cmdline_renderer = self.renderer
  function! renderer.Run()
    let result = [{'text': ' ' . self.render.airline.name . ' ', 'hl': 'airline_a'},
          \ {'text': self.render.airline.sep, 'hl': 'airline_a_to_airline_b'},
          \ {'text': self.render.airline.sep, 'hl': 'airline_b_to_airline_c'},
          \ {'text': ' ', 'hl': 'airline_x'},
          \]
    if has_key(g:Cmd2_menu, 'pages')
      let menu = g:Cmd2_menu.MenuLine()
      let result += menu
    endif
    let result += self.cmdline_renderer.Run()
    return result
  endfunction
  return renderer
endfunction

function! s:Render.CmdLineWithAirlineMenu2()
  let renderer = {}
  let renderer.render = self
  let renderer.cmdline_renderer = self.renderer
  function! renderer.Run()
    let result = []
    let g:Cmd2_menu.columns = self.render.menu_columns
    let result += [{'text': ' ' . self.render.airline.name . ' ', 'hl': 'Cmd2white'},
          \ {'text': self.render.airline.sep, 'hl': 'Cmd2arrow2'},
          \ {'text': self.render.cmd, 'hl': 'Cmd2light'},
          \ {'text': self.render.airline.sep, 'hl': 'Cmd2arrow3'},
          \ {'text': ' ', 'hl': 'airline_x'},
          \]
    if has_key(g:Cmd2_menu, 'pages')
      let menu = g:Cmd2_menu.MenuLine()
      let result += menu
    endif
    let result += self.cmdline_renderer.Run()
    return result
  endfunction
  return renderer
endfunction

function! s:Render.Render(list)
  call Cmd2#render#Render(a:list)
endfunction

function! Cmd2#render#Render(list)
  let cmd = ''
  for block in a:list
    if len(block.text)
      let hl = get(block, 'hl', 'None')
      let cmd .= 'echohl ' . hl . ' | '
      let cmd .= 'echon ''' . substitute(Cmd2#util#EscapeEcho(block.text), "'", "''", 'g') . ''' | '
    endif
  endfor
  if &cmdheight > g:Cmd2_old_cmdheight
    redraw
  endif
  " https://github.com/haya14busa/incsearch.vim/blob/master/autoload/vital/_incsearch/Over/Commandline/Modules/Redraw.vim#L38
  execute "normal! :"
  try
    execute cmd
  finally
    echohl None
  endtry
endfunction

" renders the cmdline through echo
function! s:Render.CheckBlink()
  let blink = g:Cmd2_cursor_blink ?
        \ self.GetCursorBlink(self.module.state.start_time, self.module.state.current_time)
        \ : 1
  if g:Cmd2_blink_state == blink
    return 0
  else
    let g:Cmd2_blink_state = blink
    return 1
  endif
endfunction

function! s:Render.SplitSnippet(cmd, split)
  let result = []
  let splitcmd = split(a:cmd, a:split, 1)
  call add(result, {'text': splitcmd[0]})
  let i = 1
  while i < len(splitcmd)
    if len(splitcmd[i])
      call add(result, {'text': g:Cmd2_snippet_cursor, 'hl': g:Cmd2_snippet_cursor_hl})
      call add(result, {'text': splitcmd[i]})
    endif
    let i += 1
  endwhile
  return result
endfunction

function! s:Render.GetCursorBlink(start, current)
  let ms = Cmd2#util#GetRelTimeMs(a:start, a:current)
  if ms < g:Cmd2_cursor_blinkwait
    return 1
  endif
  let interval = fmod(ms - g:Cmd2_cursor_blinkwait, g:Cmd2_cursor_blinkon + g:Cmd2_cursor_blinkoff)
  if interval < g:Cmd2_cursor_blinkoff
    return 0
  else
    return 1
  endif
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo

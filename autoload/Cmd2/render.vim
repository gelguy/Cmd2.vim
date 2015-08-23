let s:save_cpo = &cpo
set cpo&vim

function! Cmd2#render#Autoload()
  " do nothing
endfunction

let s:Render = {}

function! Cmd2#render#New()
  let render = copy(s:Render)
  let render.renderer = render.CmdLineRenderer()
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
  let self.renderer = self.CmdLineWithInsertCursorRenderer()
  return self
endfunction

function! s:Render.WithMenu()
  let self.renderer = self.CmdLineWithMenuRenderer()
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
  let self.renderer = self.CmdLineWithAirlineMenuRenderer()
  return self
endfunction

function! s:Render.WithAirlineMenu2(...)
  let options = a:0 ? a:1 : {}
  call self.SetAirlineMenuOptions(options)
  let palette = g:airline#themes#{g:airline_theme}#palette
  call s:Load_theme(palette)
  let self.renderer = self.CmdLineWithAirlineMenu2Renderer()

  function! self.UpdateCmd(cmd)
    let self.cmd = len(a:cmd) ? ' ' . a:cmd . ' ' : ''
    " - 1 to include space after last sep
    " - 2 to include spaces before and after name
    let self.menu_columns = &columns - strdisplaywidth(self.cmd) - 2*strdisplaywidth(self.airline.sep) - strdisplaywidth(self.airline.name) - 3
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

function! s:Render.CmdLineRenderer()
  let renderer = {}
  let renderer.render = self

  function! renderer.Run()
    return self.render.MakeCmdLineWithBlockCursor()
  endfunction

  return renderer
endfunction

function! s:Render.CmdLineWithInsertCursorRenderer()
  let renderer = {}
  let renderer.render = self

  function! renderer.Run()
    return self.render.MakeCmdLineWithInsertCursor()
  endfunction

  return renderer
endfunction

function! s:Render.CmdLineWithMenuRenderer()
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

function! s:Render.CmdLineWithAirlineMenuRenderer()
  let renderer = {}
  let renderer.render = self
  let renderer.cmdline_renderer = self.renderer

  function! renderer.Run()
    let result = [{'text': ' ' . self.render.airline.name . ' ', 'hl': 'airline_a'},
          \ {'text': self.render.airline.sep, 'hl': 'airline_a_to_airline_b'},
          \ {'text': self.render.airline.sep, 'hl': 'airline_b_to_airline_c'},
          \ {'text': ' ', 'hl': 'airline_x'},
          \]
    let menu = g:Cmd2_menu.MenuLine()
    let result += menu
    let result += self.cmdline_renderer.Run()
    return result
  endfunction

  return renderer
endfunction

function! s:Render.CmdLineWithAirlineMenu2Renderer()
  let renderer = {}
  let renderer.render = self
  let renderer.cmdline_renderer = self.renderer

  function! renderer.Run()
    let result = [{'text': ' ' . self.render.airline.name . ' ', 'hl': 'Cmd2white'},
          \ {'text': self.render.airline.sep, 'hl': 'Cmd2arrow2'},
          \ {'text': self.render.cmd, 'hl': 'Cmd2light'},
          \ {'text': self.render.airline.sep, 'hl': 'Cmd2arrow3'},
          \ {'text': ' ', 'hl': 'airline_x'},
          \]
    let g:Cmd2_menu.columns = self.render.menu_columns
    let menu = g:Cmd2_menu.MenuLine()
    let result += menu
    let result += self.cmdline_renderer.Run()
    return result
  endfunction

  return renderer
endfunction

function! s:Render.Render(list)
  call Cmd2#render#Render(a:list)
endfunction

" renders the cmdline through echo
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
  return interval >= g:Cmd2_cursor_blinkoff
endfunction

function! s:Render.PrepareCmdLineSections()
  let result = {}
  let result.type = [{'text': g:Cmd2_cmd_type}]
  let result.cmd0 = self.SplitSnippet(g:Cmd2_pending_cmd[0], g:Cmd2_snippet_cursor)
  let result.temp = [{'text': g:Cmd2_temp_output, 'hl': self.temp_hl}]
  let result.post_temp = [{'text': g:Cmd2_post_temp_output, 'hl' :self.post_temp_hl}]
  let result.cmd1 = self.SplitSnippet(g:Cmd2_pending_cmd[1], g:Cmd2_snippet_cursor)
  return result
endfunction

function! s:Render.JoinSections(sections)
  let result = []
  let result += a:sections.type
  let result += a:sections.cmd0
  let result += a:sections.temp
  let result += a:sections.cursor
  let result += a:sections.post_temp
  let result += a:sections.cmd1
  return result
endfunction

function! s:Render.MakeCmdLineWithInsertCursor()
  let sections = self.PrepareCmdLineSections()
  if g:Cmd2_blink_state
    " find out which character the cursor is over and remove it
    let cursor_in_section = len(sections.post_temp[0].text) ? 'post_temp' :
          \ len(sections.cmd1[0].text) ? 'cmd1' : ''
    if len(cursor_in_section)
      let cursor_text = matchstr(sections[cursor_in_section][0].text, ".", byteidx(sections[cursor_in_section][0].text, 0))
      let sections[cursor_in_section][0].text = sections[cursor_in_section][0].text[len(cursor_text):]
      let sections.cursor = [{'text': cursor_text, 'hl': g:Cmd2_cursor_hl}]
    else
      " cursor is after last character
      let sections.cursor = [{'text': ' ', 'hl': g:Cmd2_cursor_hl}]
    endif
  else
    let sections.cursor = [{'text': ''}]
  endif
  return self.JoinSections(sections)
endfunction

function! s:Render.MakeCmdLineWithBlockCursor()
  let sections = self.PrepareCmdLineSections()
  let cursor = {}
  let cursor.text = g:Cmd2_cursor_text
  if g:Cmd2_blink_state
    let cursor.hl = g:Cmd2_cursor_hl
  endif
  let sections.cursor = [cursor]
  return self.JoinSections(sections)
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo

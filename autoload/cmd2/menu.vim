let s:save_cpo = &cpo
set cpo&vim

function! cmd2#menu#Autoload()
  " do nothing
endfunction

function! cmd2#menu#CreateMenu(list, pos, columns)
  let menu = {}
  let offset = strdisplaywidth(g:cmd2_menu_previous) + strdisplaywidth(g:cmd2_menu_next) + 2
  let menu.pages = cmd2#menu#CreatePages(a:list, a:columns, offset)
  let menu.pos = a:pos
  let menu.columns = a:columns
  return menu
endfunction

function! cmd2#menu#CreatePages(list, columns, offset)
  if !len(a:list)
    return []
  else
    let pages = [[]]
  endif
  let cur_page = 0
  let cur_length = 0
  for item in a:list
    if type(item) == 4
      let text = item.text
    else
      let text = item
    endif
    " + 1 to include space after text
    if cur_length + a:offset + strdisplaywidth(text) + 1 > a:columns
      call add(pages, [])
      let cur_page += 1
      let cur_length = 0
    endif
    call add(pages[cur_page], item)
    let cur_length += strdisplaywidth(text) + 1
  endfor
  return pages
endfunction

function! cmd2#menu#Next(menu)
  if !len(a:menu.pages) || !len(a:menu.pages[a:menu.pos[0]])
    return
  endif
  let page = a:menu.pos[0]
  let index = a:menu.pos[1]
  let index += 1
  if index >= len(a:menu.pages[page])
    let index = 0
    let page += 1
    if page >= len(a:menu.pages)
      let page = 0
    endif
  endif
  let a:menu.pos[0] = page
  let a:menu.pos[1] = index
endfunction

function! cmd2#menu#Previous(menu)
  if !len(a:menu.pages) || !len(a:menu.pages[a:menu.pos[0]])
    return
  endif
  let page = a:menu.pos[0]
  let index = a:menu.pos[1]
  let index -= 1
  if index < 0
    let page -= 1
    if page < 0
      let page = len(a:menu.pages) - 1
    endif
    let index = len(a:menu.pages[page]) - 1
  endif
  let a:menu.pos[0] = page
  let a:menu.pos[1] = index
endfunction

function! cmd2#menu#Current(menu)
  if !len(a:menu.pages) || !len(a:menu.pages[a:menu.pos[0]])
    return ""
  endif
  let item = a:menu.pages[a:menu.pos[0]][a:menu.pos[1]]
  return item
endfunction

function! cmd2#menu#PrepareMenuLineFromMenu(menu)
  return cmd2#menu#PrepareMenuLine(a:menu.pages, a:menu.pos, a:menu.columns)
endfunction

function! cmd2#menu#PrepareMenuLine(pages, pos, columns)
  let line = []
  let cur_length = 0
  let page = a:pages[a:pos[0]]
  let i = 0
  if a:pos[0] > 0
    call add(line, {'text': (g:cmd2_menu_previous . ' '), 'hl': g:cmd2_menu_hl})
    let cur_length += strdisplaywidth(g:cmd2_menu_previous) + 1
  endif
  while i < len(page)
    if type(page[i]) == 4
      let text = page[i].text
    else
      let text = page[i]
    endif
    let hl = a:pos[1] == i ? g:cmd2_menu_selected_hl : g:cmd2_menu_hl
    call add(line, {'text': text, 'hl': hl})
    call add(line, {'text': ' ', 'hl': g:cmd2_menu_hl})
    let cur_length += strdisplaywidth(text) + 1
    let i += 1
  endwhile
  let padding_length = a:columns - cur_length
  if len(a:pages) - 1 > a:pos[0]
    let padding_length -= strdisplaywidth(g:cmd2_menu_next) + 1
  endif
  let padding = repeat(' ', padding_length)
  call add(line, {'text': padding, 'hl': g:cmd2_menu_hl})
  if len(a:pages) - 1 > a:pos[0]
    call add(line, {'text': (g:cmd2_menu_next . ' '), 'hl': g:cmd2_menu_hl})
  endif
  return line
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
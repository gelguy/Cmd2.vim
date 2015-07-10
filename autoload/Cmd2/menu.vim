let s:save_cpo = &cpo
set cpo&vim

function! Cmd2#menu#Autoload()
  " do nothing
endfunction

function! Cmd2#menu#New(list, ...)
  let menu = s:Menu.New(a:list, a:0 ? a:1 : &columns)
  return menu
endfunction

let s:Menu = {}

function! s:Menu.New(list, columns)
  let menu = deepcopy(self)
  let menu.pos = [0,0]
  let menu.columns = a:columns
  let menu.pages = menu.CreatePages(a:list)
  let menu.empty_render = 0
  return menu
endfunction

function! s:Menu.CreatePages(list)
  if !len(a:list)
    return []
  endif
  let pages = [[]]
  let cur_page = 0
  let cur_length = 0
  " + 2 to include spaces before and after
  let offset = strdisplaywidth(g:Cmd2_menu_previous) + strdisplaywidth(g:Cmd2_menu_next) + 2
  for item in a:list
    if type(item) == 4
      let text = item.text
    else
      let text = item
    endif
    " if cur_length == 0, item is first item, don't create new page
    if cur_length + offset + strdisplaywidth(text) + strdisplaywidth(g:Cmd2_menu_separator) > self.columns
          \ && cur_length != 0
      call add(pages, [])
      let cur_page += 1
      let cur_length = 0
    endif
    call add(pages[cur_page], item)
    let cur_length += strdisplaywidth(text) + strdisplaywidth(g:Cmd2_menu_separator)
  endfor
  return pages
endfunction

function! s:Menu.Next()
  if !len(self.pages) || !len(self.pages[self.pos[0]])
    return
  endif
  let page = self.pos[0]
  let index = self.pos[1]
  let index += 1
  if index >= len(self.pages[page])
    let index = 0
    let page += 1
    if page >= len(self.pages)
      let page = 0
    endif
  endif
  let self.pos[0] = page
  let self.pos[1] = index
endfunction

function! s:Menu.Previous()
  if !len(self.pages) || !len(self.pages[self.pos[0]])
    return
  endif
  let page = self.pos[0]
  let index = self.pos[1]
  let index -= 1
  if index < 0
    let page -= 1
    if page < 0
      let page = len(self.pages) - 1
    endif
    let index = len(self.pages[page]) - 1
  endif
  let self.pos[0] = page
  let self.pos[1] = index
endfunction

function! s:Menu.Current()
  if !len(self.pages) || !len(self.pages[self.pos[0]])
    return ''
  endif
  let item = self.pages[self.pos[0]][self.pos[1]]
  return item
endfunction

function! s:Menu.Find(item)
  if !len(self.pages) || !len(self.pages[0])
    return [-1, -1]
  endif
  let page = 0
  while page < len(self.pages)
    let pos = 0
    while pos < len(self.pages[page])
      let item = self.pages[page][pos]
      let value = type(item) == 4 ? item.value : item
      if value ==# a:item
        return [page, pos]
      endif
      let pos += 1
    endwhile
    let page += 1
  endwhile
  return [-1,-1]
endfunction

function! s:Menu.MenuLine()
  if len(self) == 0 || len(self.pages) == 0
    if self.empty_render
      let empty = repeat(' ', self.columns)
      return [{'text': empty, 'hl': g:Cmd2_menu_hl}]
    else
      return [{'text': ''}]
    endif
  endif
  let line = []
  let cur_length = 0
  let page = self.pages[self.pos[0]]
  let i = 0
  if self.pos[0] > 0
    call add(line, {'text': (g:Cmd2_menu_previous . ' '), 'hl': g:Cmd2_menu_hl})
    let cur_length += strdisplaywidth(g:Cmd2_menu_previous) + 1
  endif
  while i < len(page)
    if type(page[i]) == 4
      let text = page[i].text
    else
      let text = page[i]
    endif
    let hl = self.pos[1] == i ? g:Cmd2_menu_selected_hl : g:Cmd2_menu_hl
    " 2 to include space after < and before >
    if len(text) + strdisplaywidth(g:Cmd2_menu_previous) + strdisplaywidth(g:Cmd2_menu_next) +
          \ 2 * strdisplaywidth(g:Cmd2_menu_separator) > self.columns
      let space_left = self.columns - (strdisplaywidth(g:Cmd2_menu_previous)
            \ + strdisplaywidth(g:Cmd2_menu_next) + 2 + strdisplaywidth(g:Cmd2_menu_separator))
      let space_left -= strdisplaywidth(g:Cmd2_menu_more)
      let len = strlen(substitute(text, ".", "x", "g"))
      let j = 0
      let result = ""
      while j < len
        let byte_index = byteidx(text, j)
        let char = matchstr(text, ".", byteidx(text, j))
        let display_width = strdisplaywidth(char)
        if space_left < display_width
          break
        else
          let result .= char
          let space_left -= display_width
          let j += 1
        endif
      endwhile
      let text = result
      let text .= g:Cmd2_menu_more
    endif
    call add(line, {'text': text, 'hl': hl})
    if i < len(page) - 1
      call add(line, {'text': g:Cmd2_menu_separator, 'hl': g:Cmd2_menu_separator_hl})
      let cur_length += strdisplaywidth(text) + strdisplaywidth(g:Cmd2_menu_separator)
    else
      let cur_length += strdisplaywidth(text)
    endif
    let i += 1
  endwhile
  let padding_length = self.columns - cur_length
  if len(self.pages) - 1 > self.pos[0]
    let padding_length -= strdisplaywidth(g:Cmd2_menu_next) + 1
  endif
  let padding = repeat(' ', padding_length)
  call add(line, {'text': padding, 'hl': g:Cmd2_menu_hl})
  if len(self.pages) - 1 > self.pos[0]
    call add(line, {'text': (g:Cmd2_menu_next . ' '), 'hl': g:Cmd2_menu_hl})
  endif
  return line
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo

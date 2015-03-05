let s:save_cpo = &cpo
set cpo&vim

function! Cmd2#commands#Autoload()
  " do nothing
endfunction

let s:Commands = {}

function! Cmd2#commands#New()
  let commands = copy(s:Commands)
  return commands
endfunction

function! s:Commands.Module(module)
  let self.module = a:module
  return self
endfunction

function! s:Commands.Run(...)
  if a:0
    let result = a:1
  else
    let result = self.module.state.result
  endif
  if !len(result)
    return
  endif
  let self.mapping = result.node.value
  let self.flags = get(self.mapping, 'flags', '')
  " capital since there might be a funcref
  let self.cmd = get(self.mapping, 'command', '')
  let self.type = get(self.mapping, 'type', '')
  let self.ccount = self.flags =~# 'C' ? (result.ccount == 0 ? 1 : result.ccount)
        \ : self.flags =~# 'c' ? result.ccount
        \ : ''
  let self.old_view = winsaveview()
  let [self.vstart, self.vend, self.vpos, self.vmode] = self.VisualPre()
  call winrestview(self.old_view)
  call self.HandleType()
  call self.Vflag()
  call self.Pflag()
  call self.Rflag()
endfunction

function! s:Commands.VisualPre()
  if self.flags =~# 'v' && g:Cmd2_visual_select
    let [vstart, vend, vpos, vmode] = Cmd2#util#SaveVisual()
    return [vstart, vend, vpos, vmode]
  else
    return [-1, -1, -1, -1]
  endif
endfunction

function! s:Commands.Vflag()
  if self.flags =~# 'v' && g:Cmd2_visual_select
    let cursor_pos = getpos('.')
    call Cmd2#util#RestoreVisual(self.vstart, self.vend, self.vpos, self.vmode)
    call setpos(".", cursor_pos)
  endif
endfunction

function! s:Commands.Pflag()
  if self.flags =~# 'p'
    call winrestview(self.old_view)
  endif
endfunction

function! s:Commands.Rflag()
  if self.flags =~# 'r'
    let g:Cmd2_reenter = 1
    let g:Cmd2_reenter_key = get(self.mapping, 'reenter', '')
  endif
endfunction

function! s:Commands.HandleType()
  if empty(self.cmd) || empty(self.type)
    " skip
    let g:Cmd2_output = ""
  elseif self.type == 'literal'
    call self.HandleLiteral()
  elseif self.type == 'text'
    call self.HandleText()
  elseif self.type == 'line'
    call self.HandleLine()
  elseif self.type == 'function'
    call self.HandleFunction()
  elseif self.type == 'snippet'
    call self.HandleSnippet()
  elseif self.type == 'normal'
    call self.HandleNormal()
  elseif self.type == 'normal!'
    call self.HandleNormal()
  elseif self.type == 'remap'
    call self.HandleRemap()
  endif
endfunction

function! s:Commands.HandleLiteral()
  if !len(self.ccount)
    let g:Cmd2_output = self.cmd
  else
    let g:Cmd2_output = repeat(self.cmd, self.ccount)
  endif
endfunction

function! s:Commands.HandleText()
  execute "set opfunc=Cmd2#functions#GetContents"
  " normal (no !) to allow custom text obj remaps
  execute "normal g@" . self.ccount . self.cmd
endfunction

function! s:Commands.HandleLine()
  execute "set opfunc=Cmd2#functions#GetLines"
  " normal (no !) to allow custom text obj remaps
  execute "normal g@" . self.ccount . self.cmd
endfunction

function! s:Commands.HandleFunction()
  if len(self.ccount)
    call call(self.cmd, [self.ccount])
  else
    call call(self.cmd, [])
  endif
endfunction

function! s:Commands.HandleSnippet()
  let snippet = substitute(self.cmd, g:Cmd2_snippet_cursor_replace, g:Cmd2_snippet_cursor, "g")
  let offset = match(snippet, g:Cmd2_snippet_cursor)
  if offset == -1
    let g:Cmd2_output = snippet
    return
  endif
  if offset == 0
    let before = ""
  else
    let before = snippet[0 : offset - 1]
  endif
  let after = snippet[offset + strlen(g:Cmd2_snippet_cursor) : -1]
  let g:Cmd2_pending_cmd[0] .= before
  let g:Cmd2_pending_cmd[1] = after . g:Cmd2_pending_cmd[1]
endfunction

function! s:Commands.HandleNormal()
  let bang = self.bang ? '!' : ''
  execute "normal" . bang . " " . self.ccount . self.cmd
endfunction

let g:Cmd2_remap_depth = 0

function! s:Commands.HandleRemap()
  let g:Cmd2_remap_depth += 1
  if g:Cmd2_remap_depth > g:Cmd2_max_remap_depth
    return
  endif
  let node = Cmd2#util#FindNode(self.cmd, g:Cmd2_mapping_tree)
  if !empty(node)
    call self.Run({'node': node, 'ccount': self.ccount})
  endif
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo

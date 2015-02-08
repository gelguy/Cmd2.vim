# Cmd2.vim
Power up your Vim's cmdline mode

* Fuzzy completion for search
* Line numbers
* Current words
* Snippets

## Overview
**Cmd2.vim** is a Vim plugin which enhances Vim's cmdline mode. It provides a submode where mappings, shortcuts, custom functions and extensions can be defined. A good comparison is `<C-R>`, which prompts for a target register and inserts its contents. Triggering Cmd2 will result in a similar prompt, except you can use predefined or custom functions to handle the input.

At a higher level, Cmd2 provides a framework to create extensions which require cmdline input. One such extension is Cmd2Complete which provides fuzzy completion for search in wildmenu style. The rendering of the UI and handling of the input is handled by the framework, but can be further customised - for example to create a CtrlP/Unite style menu instead.

## Basic Usage
### Sample .vimrc settings
For a quick start, copy and paste these into your .vimrc. The following section will describe how to write a mapping and describe its components. Note: the mapping of `<C-S>` is not universal as different terminals have different sets of control keys.
``` vim
let g:Cmd2_cmd_mappings = {
      \ 'iw': {'command': 'iw', 'type': 'text', 'flags': 'Cpv'},
      \ 'ap': {'command': 'ap', 'type': 'line', 'flags': 'pv'},
      \ '^': {'command': '^', 'type': 'normal!', 'flags': 'r'},
      \ 's': {'command': 's/###/###/g', 'type': 'snippet'},
      \ 'S': {'command': 'cmd2#functions#CopySearch', 'type': 'function'},
      \ 'b': {'command': 'cmd2#functions#Back', 'type': 'function', 'flags': 'r'},
      \ 'e': {'command': 'cmd2#functions#End', 'type': 'function', 'flags': 'r'},
      \ "CF": {'command': function('cmd2#ext#complete#Main'), 'type': 'function'},
      \ "CB": {'command': function('cmd2#ext#complete#Main'), 'type': 'function'},
      \ 'w': {'command': 'cmd2#functions#Cword', 'type': 'function', 'flags': 'Cr'},
      \ "\<Plug>Cmd2Tab": {'command': "cmd2#functions#TabForward", 'type': 'function', 'flags': 'C'},
      \ "\<Plug>Cmd2STab": {'command': "cmd2#functions#TabBackward", 'type': 'function', 'flags': 'C'},
      \ "\<Tab>": {'command': "\<Plug>Cmd2Tab", 'type': 'remap', 'flags': 'C'},
      \ "\<S-Tab>": {'command': "\<Plug>Cmd2STab", 'type': 'remap', 'flags': 'C'},

      \ }

let g:Cmd2_options = {
      \ '_complete_ignorecase': 1,
      \ '_complete_uniq_ignorecase': 0,
      \ '_quicksearch_ignorecase': 1,
      \ '_complete_start_pattern': '\<\(\k\+\(_\|\#\)\)\?',
      \ '_complete_fuzzy': 1,
      \ }

cmap <C-S> <Plug>Cmd2
cmap <expr> <Tab> cmd2#ext#complete#InContext() ? "\<Plug>Cmd2CF" : "\<Tab>"
cmap <expr> <S-Tab> cmd2#ext#complete#InContext() ? "\<Plug>Cmd2CB" : "\<S-Tab>"
```
## Creating a mapping
To create a mapping, create the corresponding entry in the `g:Cmd2_cmd_mappings` dictionary. The key cannot start with a digit as that will be confused with the current count input. Mappings will be generated when the plugin is initialised and cannot be changed without restarting Vim.

The dictionary key is the key combination to input. The dictionary entry is composed of entries which are described as follows:
#### `type`
How the command will be handled. There are 8 different types, `literal`, `text`, `line`, `normal`, `normal!`, `snippet`, `remap` and`function`. What they do and their corresponding commands will be described under the `command` section.
####`command`
The input to handle. Each type expects a different form of command, as follows:
* `literal`

  The exact keys to feed to the cmdline. Useful for abbreviations. For example, `help` will result in the text `help`. Special keys are accepeted, such as `"\<BS>"` which will enter the backspace command at the point it is fed.

* `text`

  A motion command/text-obj. Takes the motion command (or text-obj) and uses an opfunc to get the text inside the text-obj. For example, `iw` will result in the current inner-word under the cursor (an alternative to `<cword>`).

* `line`

  A motion command/text-obj. Takes the motion command (or text-obj) and uses an opfunc to get the start and end lines of the text-obj. Useful for setting ranges when already in the cmdline. For example, `ap` will result in the start and end lines of the paragraph around the cursor.

* `normal` `normal!`

  A normal mode command. Executes the normal or normal! command. For example, `^` will move the cursor to the start of the sentence the cursor is currently at.

* `snippet`

  A snippet - text with jump targets which the users can jump to. The jump targets are defaulted to be `g:Cmd2_snippet_cursor_replace`. The default is `'###'`. The jump targets are rendered as `g:Cmd2_snippet_cursor`. The default is `≡`. The first target is automatically jumped to. For example, `s/###/###/g` results in the text `s//≡/g` with the cursor after the first `/`. The user can then use the `cmd2#functions#TabForward` function to jump forward to the next target.

* `remap`

  A Cmd2 mapping key. Triggers the corresponding entry in the mappings. Remap depth is limited by `g:Cmd2_max_remap_depth`. Remaps are useful this skips the feeding of keys using `getchar()`. Some mappings might be long such as `\<Plug>Cmd2TabForwards` and the remap reduces the delay when using a `cmap`.

* `function

  A string or a funcref. If a string, needs to be the name of a function. The function is called. The only argument passed to it is the current `ccount`, depending on the `c` flag. More details about writing custom functions can be found under the section.

#### `flags`
Setting these flags will determine the behaviour before, during and after an action is performed.

* **count** `c` `C`

  Similar to `v:count` and `v:count1`. Setting `c` will pass the current count passed to Cmd2. When there is no count, it is defaulted to `0`. With `C`, the count is default as `1`. When both flags are set, `C` will have the higher priority. Note that of the predefined functions, only `normal`, `normal!` and `literal` will accept count.

* **reenter** `r`

  After completing the action, the keys `\<Plug>Cmd2` are fed, triggering Cmd2 again. This is convenient for functions which do not want to exit Cmd2, e.g. manipulating the cmd cursor position with `cmd2#functions#End`. `g:Cmd2_reenter_key` can be defined which will feed the keys after reentering Cmd2.

* **position** `p`

  Restore the buffer cursor position to where it was before Cmd2 was triggered. Useful for functions which might change the cursor position, such as `line` commands.

* **visual** `v`

  Restore the visual selection when Cmd2 was triggered, if there was one. Not all functions might want to do this, as the cursor position will be moved to where the cursor was in the visual selection.

## Writing a custom function
The custom function takes 0 or 1 arguments, depending on whether the `c` flag is set. In practice, it is best to use a variadic function, which can accept any number of arguments.
``` vim
function! cmd2#functions#Cword(...)
  let ccount = get(a:000, 0, 1)
```

If the function is defined locally i.e. in a script, it can be passed to mapping dictionary using a funcref.

The contents of the cmdline and the position of the cursor can be manipulated using the following exposed global variables. `g:Cmd2_pending_cmd` is a length-2 list, with the first element containing the cmdling substring before the cursor, and the second after the cursor. `g:Cmd2_output` is the string which will be placed after the cursor.

For example, if the `g:Cmd2_pending_cmd` is `['foo', 'bar']` and `g:Cmd2_output` is `baz`, then the final state of the cmdline will be `foobazbar` with the cursor after `z`.

To manipulate the cursor position, `g:Cmd2_pending_cmd` will need to be modified accordingly.

Example:
``` vim
function! cmd2#functions#CopySearch(...)
  let cmd = g:Cmd2_pending_cmd[0] . g:Cmd2_pending_cmd[1]
  let matchstr = matchlist(cmd, '\vs/(.{-})/')
  if !empty(matchstr[1])
    let g:Cmd2_output = matchstr[1]
  endif
endfunction
```
This function leaves `g:Cmd2_pending_cmd` unmodified, and outputs the keyword between `s/{keyword}/`.

## Options
Cmd2 options can be set by defining the `g:Cmd2_options` dictionary in your .vimrc.

Below are the possible options, their default setting and description.

* `buffer_cursor_hl`: `cmd2#init#BufferCursorHl()`

  The hlgroup to use to highlight the current cursor position in the buffer. Note that when Vim enters cmdline-mode, the cursor disappears from the buffer as it moves to the cmdline. `cmd2#init#BufferCursorHl()` is used to create the `Cmd2Cursor` hlgroup, which links to `Cursor` if the hlgroup exists or reverse otherwise.

* `buffer_cursor_show`: `1`

  Boolean to toggle whether to highlight the current cursor position in the buffer.

* `cursor_blink`: `1`

  Boolean to toggle whether the cursor on the cmdline blinks. Since the rendering of the cmdline is done with `echo`, it may result in flickering depending on the refresh rate of VIM itself. Turning off the `cursor_blink` only redraw the cmdline once per input, resulting in less to no flickering.

*  `cursor_blinkwait`: `700` | `cursor_blinkon`: `400` | `cursor_blinkoff`: `250`

  The behaviour of how the cmdline cursor blinks. `cursor_blinkwait` is the delay before the cursor starts blinking, `cursor_blinkon` is the time the cursor is shown and `cursor_blinkoff` is the time the cursor is not shown. The times are in msec. In gVim, the default behaviour of the cursor out of Cmd2 can be found using `&guicursor`. See `:h guicursor`.

* `cursor_hl`: `cmd2#init#CursorHl()`

  The hlgroup to use to highlight the cmdline cursor when it is shown. `cmd2#init#BufferCursorHl()` is used to create the `Cmd2Cursor` hlgroup, which links to `Cursor` if the hlgroup exists or reverse otherwise.

* `cursor_text`: `'_'`

  The text of the cmdline cursor. Can be multibyte.

* `max_remap_depth`: `20`

  The maximum number of remaps. See `remap`.

* `loop_sleep`: `20`

  The time to sleep in between each input/render loop. The time is in msec. A lower time will result in more responsiveness. 0 is accepted. Changing the sleep time can also affect the flickering of the cmdline (may be better or worse, the effect is uncertain).

* `preload`: `0`

  Whether to preload the plugin instead of waiting for autoloading. Preloading will take up more time during startup but autoloading will result in a delay when using Cmd2 for the first time.

* `snippet_cursor`: `'≡'`

  The string to show when rendering the snippet jump target. See `snippet`.

* `snippet_cursor_hl`: `'Title'`

  The hlgroup to use to highlight the snippet jump targets.

* `snippet_cursor_replace`: `'###'`

  The string to use when defining jump targets in a snippet. See `snippet`.

* `timeoutlen`: `&timeoutlen`

  The time in milliseconds that is waited for the keyed input to complete. The timeout starts when the first non-digit key is entered.

* `menu_selected_hl`: `'WildMenu'`

  The hlgroup to use to highlight the selected item when `menu` is activated.

* `menu_hl`: `'StatusLine'`

  The hlgroup to use to highlight the unselected items and padding when `menu` is activated.

* `menu_next`: `'>'`

  The string used to indicate there is a next page in the menu when `menu` is activated. Can be multibyte.

* `menu_previous`: `'<'`

  The string used to indicate there is a previous page in the menu when `menu` is activated. Can be multibyte.

* `menu_more`: `'…'`

  The string used to append to a menu item if it is truncated because it is too long. Can be multibyte.

## Cmd2Complete extension
  **Cmd2Complete** is an extension built on Cmd2. It provides fuzzy completion for search in wildmenu style. Refer to the gif for an example. It can be mapped as a function using `cmd2#ext#complete#Main`. Once activated, the next and previous keys will cycle through the candidates, listed in wildmenu style.

  Options are defined in the same `g:Cmd2_options` dictionary. As an extension, the options are prepended with `_`. The options are lsited below.

* `_complete_ignorecase`: `0`

  Boolean to toggle whether to ignore case when looking for matches.

* `_complete_uniq_ignorecase`: `1`

  Boolean to toggle whether to ignore case when removing repeat matches. This is different from ignoring case while searching as we might want to keep the different casings of the same word as options. This value does not matter if `_complete_ignorecase` is not set.

* `_complete_pattern`: `'\k\*'`

  A pattern to use while searching. Note: `\V` or "very nomagic" is on so the characters have to be escaped accordingly. When fuzzy search is off, the pattern is appended to the end of the search string. When fuzzy search is on, the pattern is inserted between each character and then again at the end.

* `_complete_start_pattern`: `'\<'`

  A pattern to use while searching. Note: `\V` or "very nomagic" is on so the characters have to be escaped accordingly. The pattern is prepended at the start of the search string.

* `_complete_fuzzy`: `1`

  Boolean to set if fuzzy search is on.

* `_complete_next`: `"\<Tab>"`

  Key to enter to go to the next item in the menu.

* `_complete_previous`: `"\<S-Tab>"`

  Key to enter to go to the previous item in the menu.

* `_complete_generate`: `'cmd2#ext#complete#GenerateCandidates'`

  A string or a funcref. If a string, needs to be the name of a function. The function is called to generate the list of candidates. The function is passed 1 argument, which is the substring of the cmdline before the cursor. The function will have access to the global variables such as `g:cmd2_pending_cmd` if the argument is not enough. The list should be a list of strings, in the order they would appear in the menu. This means searching, sorting, uniq-ng and ranking should be done.

## FAQ

#### Flickering

  As Cmd2 renders the cmdline and menu using `echo`, there might be flickering. Changing the `g:Cmd2_loop_sleep` variable will have different effects depending on the terminal used. In general, a lower value should result in less flickering. Otherwise, setting `g:Cmd2_cursor_blink` to `0` will turn off the cursor blink, which will result in no re-rendering and hence no flickering.

#### Writing extensions

  To do.

## Similar plugins

* [vital-over](https://github.com/osyo-manga/vital-over)
* [pseudocl](https://github.com/junegunn/vim-pseudocl)
* [conomode.vim](http://www.vim.org/scripts/script.php?script_id=2388)



















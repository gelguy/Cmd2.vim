# Cmd2.vim
Power up your Vim's cmdline mode

* Autosuggest for search

  ![Cmd2Suggest](http://i.imgur.com/HVj8ko1.gif)

* Fuzzy search

  ![Cmd2Suggest](http://i.imgur.com/5hLHASu.gif)

* Much more

## Overview

**Cmd2.vim** is a Vim plugin which enhances Vim's cmdline mode. It provides a submode where mappings, shortcuts, custom functions and extensions can be defined. A good comparison is `<C-R>`, which prompts for a target register and inserts its contents. Triggering Cmd2 will result in a similar prompt, except you can use predefined or custom functions to handle the input.

**Cmd2Complete** and **Cmd2Suggest** provide fuzzy search completion, with Cmd2Suggest showing suggestions as you type.

### Cmd2Suggest

For **Cmd2Suggest**, add these mappings. The `<F12>` map can be changed to something else that is not used.

``` vim
  nmap : :<F12>     " for : mode (experimental)
  nmap / /<F12>

  cmap <F12> <Plug>(Cmd2Suggest)
```
A wildmenu-style menu will appear as you type your search. Press `<Tab>` and `<S-Tab>` to move through the menu and `<CR>` to accept the suggestion.

Cmd2Suggest uses Cmd2Complete for getting its completions. By default, fuzzy completion is not enabled. See **Cmd2CustomisingSearch** in the help docs to customise your search.

The default Cmd2Suggest will be slow in larger files. See **Cmd2OptimisingSearch** on how to optimise your search using Python, Ruby or other methods.

### Cmd2Complete

**Cmd2Complete** does the same fuzzy search completion, but on manual activation.

If you only want manual activation, add this to your .vimrc.
``` vim
    let g:Cmd2_options = {
          \ '_complete_ignorecase': 1,
          \ '_complete_uniq_ignorecase': 0,
          \ '_complete_fuzzy': 1,
          \ }

    cmap <expr> <Tab> Cmd2#ext#complete#InContext() ? "\<Plug>(Cmd2Complete)" : "\<Tab>"

    set wildcharm=<Tab>
```

Press `<Tab>` to trigger the fuzzy completion.

## FAQ

#### Choosing a cmap key

  Different terminals have different Control keys hence the `\<Plug>Cmd2` mapping may not be available in all terminals. If all else fails, using one of the Vim's default cmdline mappings will help solve the issue. See `:h c_CTRL-V` and onwards.

#### Flickering

  As Cmd2 renders the cmdline and menu using `echo`, there might be flickering. Changing the `g:Cmd2_loop_sleep` variable will have different effects depending on the terminal used. In general, a lower value should result in less flickering. Otherwise, setting `g:Cmd2_cursor_blink` to `0` will turn off the cursor blink, which will result in no re-rendering and hence no flickering.

#### Slow fuzzy matching

  The default fuzzy matcher uses Vim's inbuilt search() and match() functions to generate the list of candidates. The candidates are then sorted and uniq-ed with an unoptimised algorithm. This might result in a noticeable delay when dealing with large files. A way to fix this is to use set `g:Cmd2_complete_generate` to a custom function which is faster. Some possible ways to do this is to use Python or Lua, or use existing sources such as from neocomplete.

#### Putty mouse flickering

  In Putty, the cursor may flicker between insert text mode and pointer mode when Cmd2 is triggered. This is due to the cursor changing into pointer mode when a sleep command is given to Vim. To prevent this, change `g:Cmd2_loop_sleep` to `0`. This will stop Cmd2 from sleeping in between loops but may affect the cmdline flickering.

#### Esc key has to be pressed twice

  This is fixed by Vim patch 7.4.306. Please update Vim to the latest version. Alternatively, you can map another key to Esc using

  ``` vim
  cnoremap <key> <nop>
  ```

## Similar plugins

* [vital-over](https://github.com/osyo-manga/vital-over)
* [pseudocl](https://github.com/junegunn/vim-pseudocl)
* [conomode.vim](http://www.vim.org/scripts/script.php?script_id=2388)



















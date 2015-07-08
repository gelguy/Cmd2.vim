let s:save_cpo = &cpo
set cpo&vim

function! Cmd2#Autoload()
  call Cmd2#commands#Autoload()
  call Cmd2#functions#Autoload()
  call Cmd2#handle#Autoload()
  call Cmd2#init#Autoload()
  call Cmd2#loop#Autoload()
  call Cmd2#main#Autoload()
  call Cmd2#menu#Autoload()
  call Cmd2#module#Autoload()
  call Cmd2#render#Autoload()
  call Cmd2#tree#Autoload()
  call Cmd2#util#Autoload()

  call Cmd2#ext#complete#Autoload()
  call Cmd2#ext#suggest#Autoload()
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo

let s:save_cpo = &cpo
set cpo&vim

function! cmd2#Autoload()
  call cmd2#commands#Autoload()
  call cmd2#functions#Autoload()
  call cmd2#handle#Autoload()
  call cmd2#init#Autoload()
  call cmd2#loop#Autoload()
  call cmd2#main#Autoload()
  call cmd2#menu#Autoload()
  call cmd2#render#Autoload()
  call cmd2#tree#Autoload()
  call cmd2#util#Autoload()

  call cmd2#ext#complete#Autoload()
  call cmd2#ext#quicksearch#Autoload()
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo

let s:save_cpo = &cpo
set cpo&vim

function! cmd2#Autoload()
  call cmd2#commands#Autoload()
  call cmd2#init#Autoload()
  call cmd2#main#Autoload()
  call cmd2#render#Autoload()
  call cmd2#util#Autoload()
  call cmd2#tree#Autoload()
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo

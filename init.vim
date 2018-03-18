[==================================================]
" dark_powered.vim --- Dark powered mode of SpaceVim
" Copyright (c) 2016-2017 Wang Shidong & Contributors
" Author: Wang Shidong < wsdjeg at 163.com >
- vim-javacomplete2: Installing done.
- vim-mundo: Installing done.
"=============================================================================
- vim-snippets: Installing done.
- vimfiler.vim: Installing done.
- vimshell.vim: Installing done.
- yowish.vim: Installing done.
let g:spacevim_realtime_leader_guide = 1
let g:spacevim_enable_tabline_filetype_icon = 1
let g:spacevim_enable_statusline_display_mode = 0
let g:spacevim_enable_os_fileformat_icon = 1
let g:spacevim_buffer_index_type = 1
let g:spacevim_enable_vimfiler_welcome = 1
let g:spacevim_enable_debug = 1
" }}}

" SpaceVim Layers: {{{
call SpaceVim#layers#load('incsearch')
call SpaceVim#layers#load('autocomplete')
call SpaceVim#layers#load('chat')
call SpaceVim#layers#load('eheckers')
call SpaceVim#layers#load('default')
call SpaceVim#layers#load('git')
call SpaceVim#layers#load('ui')
call SpaceVim#layers#load('github')
call SpaceVim#layers#load('lang#c')
call SpaceVim#layers#load('lang#html')
call SpaceVim#layers#load('lang#elixir')
call SpaceVim#layers#load('lang#go')
call SpaceVim#layers#load('lang#haskell')
call SpaceVim#layers#load('lang#java')
call SpaceVim#layers#load('lang#javascript')
call SpaceVim#layers#load('lang#lua')
call SpaceVim#layers#load('lang#perl')
call SpaceVim#layers#load('lang#php')
call SpaceVim#layers#load('lang#python')
call SpaceVim#layers#load('lang#rust')
call SpaceVim#layers#load('lang#swig')
call SpaceVim#layers#load('lang#tmux')
call SpaceVim#layers#load('lang#vim')
call SpaceVim#layers#load('lang#xml')
call SpaceVim#layers#load('shell')   
call SpaceVim#layers#load('tools#screensaver')
" }}}



" ── jmangelson vimrc ──────────────────────────────────────────────────────

filetype on
autocmd BufRead,BufNewFile *.launch set filetype=xml
autocmd BufRead,BufNewFile *.world set filetype=xml

set background=dark
set number
set backspace=indent,eol,start
:imap <C-H> <C-W>
syntax on

" Italics in Gnome terminal
set t_ZH=[3m
set t_ZR=[23m

" True color in tmux
let &t_8f="\<Esc>[38;2;%lu;%lu;%lum"
let &t_8b="\<Esc>[48;2;%lu;%lu;%lum"
set termguicolors

:set tabstop=4
:set shiftwidth=4
:set expandtab
:set autoindent

set splitright
set splitbelow
set nofoldenable

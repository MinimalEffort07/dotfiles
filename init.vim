" Install vim-plug if not found
if empty(glob('~/.vim/autoload/plug.vim'))
  silent !curl -fLo ~/.vim/autoload/plug.vim --create-dirs
    \ https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
endif

" Run PlugInstall if there are missing plugins
autocmd VimEnter * if len(filter(values(g:plugs), '!isdirectory(v:val.dir)'))
  \| PlugInstall --sync | source $MYVIMRC
\| endif

call plug#begin()

Plug 'ycm-core/YouCompleteMe'
Plug 'bcicen/vim-vice'
Plug 'kutsan/zsh-system-clipboard'
Plug 'ycm-core/YouCompleteMe'

call plug#end()

" ------------------------------- YouCompleteMe Customisation ---------------------------
" Let clangd fully control code completion
let g:ycm_clangd_uses_ycmd_caching = 0
" Use installed clangd, not YCM-bundled clangd which doesn't get updates.
" let g:ycm_clangd_binary_path = exepath("clangd")

nnoremap <C-f> :YcmCompleter FixIt<CR>
nnoremap <C-g> :YcmCompleter GoTo<CR>
set completeopt-=preview
" ------------------------------- Misc Customisation ---------------------------

" Copies to to clipboard
set clipboard=unnamedplus

" Show file name in title
set title

" Color Scheme
colorscheme vice

" Syntax Highlighting
syntax on

" Line numbers
set number

" Number of spaces for a single tab.
set tabstop=4

" When indenting with '>' treat each indent as 4 spaces
set shiftwidth=4

" Turn tabs into spaces.
set expandtab

" Highlight search results
set hlsearch

" Markdown error pattern without the underscore
syn match markdownError "\w\@<=\w\@="

" ------------------------- Color Column Customisation -------------------------

" Set colour column to column 80
set cc=80

hi Bang ctermfg=White guifg=White
match Bang /\%>79v.*\%<81v/

" Set colour of colour column to blue
hi ColorColumn ctermbg=grey

" ------------------- Spell Color Customisation --------------------------------

" Set spell check language to Australian
set spell spelllang=en_au

" Customize incorrectly spelt words
hi clear SpellBad

hi SpellBad cterm=underline ctermfg=red

" Customize incorrectly capitalised words
hi clear SpellCap

hi SpellCap cterm=underline ctermfg=217

hi clear SpellLocal

" ------------------- Tab Color Customisation ---------------------------------

" Tab bar colour
hi TabLineFill ctermfg=232

" Inactive tab colours
hi TabLine ctermfg=093 ctermbg=232

" Active tab colours
hi TabLineSel ctermfg=255 ctermbg=093

" ----------- Normal Mode Custom Key Mappings ---------------------------------

" Save The File
nnoremap s :w<CR>

" Close the file, only works if there have been no changed made
nnoremap q :q<CR>

" Force close the file (without saving)
nnoremap q1 :q!<CR>

" Reload the vimrc
nnoremap r :source $MYVIMRC<CR>

" Open up the vimrc in a split pane
nnoremap ev :vsplit $MYVIMRC<CR>:let @/ = ""<CR>

" Select the current word
nnoremap <SPACE> viw

" Remove highlight from searched words
nnoremap <silent> <CR> :let @/ = ""<CR>

" Don't Jump to the next instance on use of '*'
nnoremap <silent> * :keepjumps normal! mi*`i<CR>

" Open a terminal in vertically split pane
nnoremap tt :let $tdir=expand('%:p:h')<CR>:vsplit<CR>:terminal<CR>i<CR>cd $tdir<CR>clear<CR>

" Open a terminal in horizontally split pane
nnoremap tw :let $tdir=expand('%:p:h')<CR>:split<CR>:terminal<CR>i<CR>cd $tdir<CR>clear<CR>

" Move backward a split
nnoremap <C-b> <ESC><CR>wW

" Move forward a split
nnoremap <C-n> <ESC><CR>ww

" Start the command to open a new tab
nnoremap <C-t> :tabe

" Start the command to open a new vsplit
nnoremap <C-i> :vsplit

" Start the command to open a new split
" nnoremap <C-o> :split

" Copy highlighted term to global clipboard
nnoremap <C-c> *gn"*y:let @/ = ""<CR>

" Create SED to clear all trailing white space
nnoremap <C-d> :%s/ \+$//gc<CR>

" Format file in accordance to vim guidelines for linux kernel developement
nnoremap <C-k> :set tabstop=8 softtabstop=8 shiftwidth=8 noexpandtab<CR>:retab!<CR>

" ----------- Insert Mode Custom Key Mappings ---------------------------------

" 'jk' to enter normal mode
inoremap jk <ESC>

inoremap JK <ESC>

" ----------- Visual Mode Custom Key Mappings ---------------------------------

" Toggle visual mode
vnoremap <SPACE> v

" Copy selection to global clipboard
vnoremap <C-c> "*y

" ----------- Terminal mode Custom Key Mappings -------------------------------

" Move back one tab
tnoremap <C-b> <C-\><C-N>:tabp<CR>

" Enter vim mode
tnoremap <ESC><ESC> <C-\><C-N>

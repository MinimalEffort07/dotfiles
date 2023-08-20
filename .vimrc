call plug#begin()

" Plugins
Plug 'preservim/nerdtree'
Plug 'junegunn/fzf'

call plug#end()

" Syntax Highlighting
syntax on

" Line numbers
set number                          

" Distance between edge of window and line number. 
set numberwidth=2                   

" Text Display
set shiftwidth=0                    

" Number of spaces for a single tab. 
set tabstop=4                       

" Turn tabs into spaces. 
set expandtab                       

" Highlight search results
set hlsearch 

" Display lines as wrapped in vim but don't actually change file. 
set wrap                            

" Wrap the line at a word boundary, don't break a word. 
set linebreak                       

let g:loaded_matchparen=1

" Set colour column to column 80
set cc=80

" Change vim dir when enter new buffer
set autochdir

" Set colour of colour column to blue
hi ColorColumn ctermbg=blue guibg=lightgrey

" Set spell check language to Australian 
set spell spelllang=en_au

" Customize incorrectly spelt words
hi clear SpellBad
hi SpellBad cterm=underline ctermfg=red

" Customize incorrectly capitalised words
hi clear SpellCap
hi SpellCap cterm=underline ctermfg=217

hi clear SpellLocal

" Set style for gVim
hi SpellBad gui=undercurl

" Tab Colour Customisation

" Tab bar colour
hi TabLineFill ctermfg=232

" Inactive tab colours
hi TabLine ctermfg=093 ctermbg=232

" Active tab colours
hi TabLineSel ctermfg=255 ctermbg=093

" Enable FZF
set rtp+=/opt/homebrew/opt/fzf

" Open FZF search in center of current windows
let g:fzf_layout = { 'window': { 'width': 0.9, 'height': 0.6, 'relative': v:true } }

" Open up FZF file in new tab
let g:fzf_action = { 'enter': 'tab split' }

" ----------- Normal Mode Custom Key Mappings ---------------------------------

" Save The File
nnoremap s :w<CR>                      

" Close the file, only works if there have been no changed made
nnoremap q :q<CR>

" Force close the file (without saving)
nnoremap q1 :q!<CR>

" Reload the vimrc
nnoremap <silent> r :source $MYVIMRC<CR>

" Move the current line down one line
nnoremap - :m+<CR>

" Move the current line up one line
nnoremap = :m-2<CR> 

" Open up the vimrc in a split pane
nnoremap ev :split $MYVIMRC<CR> 

" Select the current word
nnoremap <SPACE> viw

" Go to the beginning of the line 
nnoremap H 0

" Go to the end of the line
nnoremap L $

" Remove highlight from searched words 
nnoremap <silent> <CR> :let @/ = ""<CR>

" Don't Jump to the next instance on use of '*'
nnoremap * :keepjumps normal! mi*`i<CR>

" Normal Mode Plugin Control Mappings
nnoremap pi :PlugInstall<CR>

" Move to last letter of word
nnoremap w e

" Open a terminal in a new tab
nnoremap tt :let $tdir=expand('%:p:h')<CR>:tab terminal<CR>cd $tdir<CR>clear<CR>

" Move back one tab
nnoremap <C-b> :tabp<CR>

" Move forward one tab
nnoremap <C-n> :tabn<CR>

" Start the command to open a new tab
nnoremap <C-t> :tabe 

" Copy highlighted term to global clipboard
nnoremap <C-c> gn"*y

" Toggle insert paste mode
nnoremap ~ :set paste!<CR>:set paste?<CR>

" Terminal Grep text
nnoremap <C-g> gn"*y<ESC>:let $tdir=expand('%:p:h')<CR>:tab term<CR>cd $tdir<CR>clear<CR>gr `pbpaste`<CR>

" Silence '*' bind
nnoremap <silent> * *

" Open FZF windows
nnoremap <C-f> :FZF<CR>

" ----------- Insert Mode Custom Key Mappings ---------------------------------

" 'jk' to enter normal mode
inoremap jk <ESC>

" ----------- Visual Mode Custom Key Mappings ---------------------------------

" Surround word in curly brackets
vnoremap { bvi{<ESC>wea}<ESC>

" Surround word in single quotes
vnoremap ' bvi'<ESC>wea'<ESC>

" Surround word in square brackets
vnoremap [ bvi[<ESC>wea]<ESC>

" Surround word in parentheses
vnoremap ( bvi(<ESC>wea)<ESC>

" Surround word in double quotes
vnoremap " bvi"<ESC>wea"<ESC>

" Surround word in angled brackets 
vnoremap < bvi<<ESC>wea><ESC>

" Toggle visual mode
vnoremap <SPACE> v

" Convert selection to uppercase
vnoremap u ~gv

" Indent to the right
vnoremap <C-l> > 

" Move to last letter of word
vnoremap w e

" Copy selection to global clipboard
vnoremap <C-c> "*y

" Terminal Grep text
vnoremap <C-g> "*y<ESC>:let $tdir=expand('%:p:h')<CR>:tab term<CR>cd $tdir<CR>clear<CR>gr `pbpaste`<CR>

" ----------- Terminal mode Custom Key Mappings -------------------------------

" Move back one tab
tnoremap <C-b> <C-\><C-N>:tabp<CR>

" Move forward one tab
tnoremap <C-n> <C-\><C-N>:tabn<CR>

" Enter vim mode
tnoremap <C-l> <C-\><C-N>

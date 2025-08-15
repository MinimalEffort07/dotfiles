-- Enable syntax highlighting
vim.opt.syntax = "on"

-- Display line numbers
vim.opt.number = true

-- Display adjacent lines numbers as relative offsets
vim.opt.relativenumber = true

-- Tab == 4 spaces
vim.opt.tabstop = 4

-- Shift index == 4 spaces
vim.opt.shiftwidth = 4

-- Always turn tabs into spaces
vim.opt.expandtab = true

-- Highlight my search results
vim.opt.hlsearch = true

-- Highlight search results as I type them
vim.opt.incsearch = true

-- Create a different coloured column at column 100
vim.opt.colorcolumn:append('100')

-- Set spelling to Australian
vim.opt.spelllang:prepend('en_au')

-- Don't wrap lines
vim.opt.wrap = false

-- Enables 24-bit RGB color in the TUI
vim.opt.termguicolors = true

-- Cause vim to start scolling text in window once there is 8 lines left at top or bottom of screen
vim.opt.scrolloff = 20

-- If this many milliseconds nothing is typed the swap file will be written to disk
vim.opt.updatetime = 50

-- Case-insesitive search
vim.opt.ignorecase = true

-- Override 'ignorecase' if search pattern contains uppercase characters
vim.opt.smartcase = true

-- The signcolumn is the column which holds neovim signs. See :h signs
vim.opt.signcolumn = 'yes'

-- Wait this many milliseconds after part of mapping is pressed for the rest of the mapping
vim.opt.timeoutlen = 300

-- When a make a vertical split, create the new window to the right
vim.opt.splitright = true

-- When a make a horizontal split, create the new split below the current split
vim.opt.splitbelow = true

-- Lightly highlight the line your cursor is on.
vim.opt.cursorline = true

-- When on, Vim will change the current working directory whenever you open a file
vim.opt.autochdir= true

-- Disable mouse supprt (Helpful to stop accidental mousepad touches from moving curser around file)
vim.opt.mouse = ""

vim.o.ff = 'unix'

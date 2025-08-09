-- Insert Mode Mappings
vim.keymap.set('i', 'jk', '<ESC>', { desc = "Enter normal mode" })
vim.keymap.set('i', 'JK', '<ESC>', { desc = "Enter normal mode" })

-- Normal Mode Mappings
vim.keymap.set('n', 'Q', ':q<CR>', { desc = "Quit if there is no unsaved changes" })
vim.keymap.set('n', 'q1', ':q!<CR>', { desc = "Force quit without saving" })
vim.keymap.set('n', 's', ':w<CR>', { desc = "Save buffer" })
vim.keymap.set('n', '<CR>', ':nohlsearch<CR>', { desc = "Unhighlight search results", noremap = false })
vim.keymap.set('n', '*', ':keepjumps normal! mi*`i<CR>',
    { silent = true, desc = "Stays at first selection when using '*'" })
vim.keymap.set('n', '<C-d>', '<C-d>zz', { desc = "Move down half a page but keep cursor in the center of page" })
vim.keymap.set('n', '<C-u>', '<C-u>zz', { desc = "Move up half a page but keep cursor in the center of page" })
vim.keymap.set('n', '<leader>p', '\"+p')
vim.keymap.set('n', 'g1', ':1tabn<cr>', { desc = "Open tab1", noremap = true })
vim.keymap.set('n', 'g2', ':2tabn<cr>', { desc = "Open tab2", noremap = true })
vim.keymap.set('n', 'g3', ':3tabn<cr>', { desc = "Open tab3", noremap = true })
vim.keymap.set('n', 'g4', ':4tabn<cr>', { desc = "Open tab4", noremap = true })
vim.keymap.set('n', 'g5', ':5tabn<cr>', { desc = "Open tab5", noremap = true })
vim.keymap.set('n', 'g6', ':6tabn<cr>', { desc = "Open tab6", noremap = true })
vim.keymap.set('n', 'g7', ':7tabn<cr>', { desc = "Open tab7", noremap = true })
vim.keymap.set('n', 'g8', ':8tabn<cr>', { desc = "Open tab8", noremap = true })
vim.keymap.set('n', 'g9', ':9tabn<cr>', { desc = "Open tab9", noremap = true })
vim.keymap.set('n', 'g0', ':10tabn<cr>', { desc = "Open tab10", noremap = true })


-- Visual Mode Mappings
vim.keymap.set('v', '<SPACE>', 'v')
vim.keymap.set('v', '<leader>y', '\"+y')

-- Select Mode Mappings

-- Delete selected text into the 'black hole register' and print from the 'unnamed register'
-- meaning the delete doesn't overwrite what you have previsouly yanked.
vim.keymap.set('x', '<leader>p', '\"_dp')

-- This is where you enable features that only work
-- if there is a language server active in the file
vim.api.nvim_create_autocmd('LspAttach', {
    desc = 'LSP actions',
    callback = function(event)
        local opts = { buffer = event.buf }

        vim.keymap.set('n', 'K', function() vim.lsp.buf.hover() end, opts)
        vim.keymap.set('n', 'gd', function() vim.lsp.buf.definition() end, opts)
        vim.keymap.set('n', 'gD', function() vim.lsp.buf.declaration() end, opts)
        vim.keymap.set('n', 'gi', function() vim.lsp.buf.implementation() end, opts)
        vim.keymap.set('n', 'go', function() vim.lsp.buf.type_definition() end, opts)
        vim.keymap.set('n', 'gr', function() vim.lsp.buf.references() end, opts)
        vim.keymap.set('n', 'gs', function() vim.lsp.buf.signature_help() end, opts)
        vim.keymap.set('n', '<F2>', function() vim.lsp.buf.rename() end, opts)
        vim.keymap.set({ 'n', 'x' }, '<F3>', function() vim.lsp.buf.format({ async = true }) end, opts)
        vim.keymap.set('n', '<F4>', function() vim.lsp.buf.code_action() end, opts)
    end,
})

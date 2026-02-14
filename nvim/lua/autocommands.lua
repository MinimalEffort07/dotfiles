-- Briefly highlight text when you yank it
vim.api.nvim_create_autocmd('TextYankPost', {
    desc = 'Highlight when yanking (copying) text',
    group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
    callback = function()
        vim.highlight.on_yank()
    end,
})

-- Remove trailing whitespace from lines when you save a buffer
vim.api.nvim_create_autocmd({ "BufWritePre" }, {
    pattern = { "*.c", "*.h", "*.py", "*.psm1", "*.ps1" },
    callback = function(ev)
        local current_line = vim.api.nvim_win_get_cursor(0)
        vim.cmd('%s/ *$//g')
        vim.api.nvim_win_set_cursor(0, current_line)
    end
})

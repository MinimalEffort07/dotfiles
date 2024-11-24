-- Create an event handler for the FileType autocommand
vim.api.nvim_create_autocmd('FileType', {
    -- This handler will fire when the buffer's 'filetype' is "python"
    pattern = { 'c', 'cpp' },
    callback = function(args)
        vim.lsp.start({
            name = 'clangd-language-server',
            cmd = { 'clangd', '--background-index', '--clang-tidy', '--completion-parse=auto', '--completion-style=detailed', '--pretty' },
            -- Set the "root directory" to the parent directory of the file in the
            -- current buffer (`args.buf`) that contains either a "*.sln, ..." Files that share a root
            -- directory will reuse the connection to the same LSP server.
            root_dir = vim.fs.root(args.buf, { '*.sln', '*.vcproj', '*.vcxproj', 'Makefile' }),
        })
    end,
})

-- Create an event handler for the FileType autocommand
vim.api.nvim_create_autocmd('FileType', {
    -- This handler will fire when the buffer's 'filetype' is "python"
    pattern = { 'toml' },
    callback = function(args)
        vim.lsp.start({
            name = 'alacritty-language-server',
            cmd = { 'python', 'C:\\Users\\Min\\projects\\minimaleffort\\alacrittyls\\alacritty.py' },
            -- Set the "root directory" to the parent directory of the file in the
            -- current buffer (`args.buf`) that contains either a "*.sln, ..." Files that share a root
            -- directory will reuse the connection to the same LSP server.
            root_dir = vim.fs.root(args.buf, { 'alacritty.toml' }),
        })
    end,
})

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
    pattern = { "*.c", "*.h", "*.py" },
    callback = function(ev)
        local current_line = vim.api.nvim_win_get_cursor(0)
        vim.cmd('%s/ *$//g')
        vim.api.nvim_win_set_cursor(0, current_line)
    end
})

vim.api.nvim_create_autocmd('LspAttach', {
    callback = function(args)
        local client = vim.lsp.get_client_by_id(args.data.client_id)
        if client == nil then return end


        if client.supports_method('textDocument/completion') then
            -- Enable auto-completion
            vim.lsp.completion.enable(true, client.id, args.buf, { autotrigger = false })
        end

        if client.supports_method('textDocument/inlayHint') then
            -- Enable inlay_hints
            vim.lsp.inlay_hint.enable(true)
        end
        if client.supports_method('textDocument/codeLens') then
            -- Enable codeLens
            vim.api.nvim_create_autocmd('BufEnter', {
                callback = function()
                    vim.lsp.codelens.refresh({ bufnr = 0 })
                end
            })
            -- autocmd BufEnter,CursorHold,InsertLeave <buffer> lua vim.lsp.codelens.refresh({ bufnr = 0 })
        end
        if client.supports_method('textDocument/formatting') then
            -- Format the current buffer on save
            vim.api.nvim_create_autocmd('BufWritePre', {
                buffer = args.buf,
                callback = function()
                    vim.lsp.buf.format({ bufnr = args.buf, id = client.id })
                end,
            })
        end
    end,
})

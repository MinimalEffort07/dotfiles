require('config.lazy')
require('keybinds')
require('autocommands')
require('options')

vim.cmd("colorscheme tokyonight")


-- nvm-cmp Completion Engine
-- The language servers know what values are valid after say a object.<potential values> however they don't
-- display them to the buffer for you, that is what a completion enginer is for like nvim-cmp.
local cmp = require("cmp")
cmp.setup({
    window = {
        completion = cmp.config.window.bordered({
          winhighlight = "Normal:CmpPmenu,CursorLine:CmpSel,Search:None",
        }),
        documentation = cmp.config.window.bordered(),
    },
    mapping = cmp.mapping.preset.insert({}),
    sources = cmp.config.sources({
        { name = 'nvim_lsp' },
    }),
    {
        { name = 'buffer' }
    }
})
local capabilities = require("cmp_nvim_lsp").default_capabilities()

vim.lsp.config('lua_ls', {
    capabilities = capabilities,
    settings = {
        Lua = {
            diagnostics = {
                globals = { 'vim' },
            },
            completion = {
                displayContext = 1,
            },
            workspace = {
                checkThirdParty = false,
                library = vim.tbl_filter(function(path)
                    return not path:match("after")
                end, vim.api.nvim_get_runtime_file("", true)),
            },
        },
    },
})
vim.lsp.enable('lua_ls')

vim.lsp.config('clangd', {
    -- cmd = {vim.env.USERPROFILE .. '\\repos\\zls\\zig-out\\bin\\zls'},
    capabilities = capabilities,
})
vim.lsp.enable('clangd')


vim.lsp.config('zls', {
    -- cmd = {vim.env.USERPROFILE .. '\\repos\\zls\\zig-out\\bin\\zls'},
    capabilities = capabilities,
})
vim.lsp.enable('zls')


vim.lsp.config('pyright', {
    -- cmd = {vim.env.USERPROFILE .. '\\.venv\\Scripts\\pyright-langserver.exe', "--stdio"},
    capabilities = capabilities,
})
vim.lsp.enable('pyright')

vim.lsp.config('clangd', { capabilities = capabilities })
vim.lsp.enable('clangd')

vim.lsp.config('typescript-language-server', { capabilities = capabilities })
vim.lsp.enable('typescript-language-server')

vim.lsp.config("powershell_es", {
    capabilities = capabilities,
    bundle_path = "~/tools/PowerShellEditorServices",
})
vim.lsp.enable("powershell_es")

vim.lsp.config("neocmake", { capabilities = capabilities})
vim.lsp.enable("neocmake")

require("fzf-lua").setup({"hide",})

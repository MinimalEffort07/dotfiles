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
        completion = cmp.config.window.bordered(),
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

vim.lsp.config('pyright', { capabilities = capabilities })
vim.lsp.enable('pyright')

vim.lsp.config('lua_ls', {
    capabilities = capabilities,
    on_init = function(client)
        if client.workspace_folders then
            local path = client.workspace_folders[1].name
            if
                path ~= vim.fn.stdpath('config')
                and (vim.uv.fs_stat(path .. '/.luarc.json') or vim.uv.fs_stat(path .. '/.luarc.jsonc'))
            then
                return
            end
        end

        client.config.settings.Lua = vim.tbl_deep_extend('force', client.config.settings.Lua, {
            runtime = {
                version = 'LuaJIT',
                -- Tell the language server how to find Lua modules same way as Neovim
                -- (see `:h lua-module-load`)
                path = {
                    'lua/?.lua',
                    'lua/?/init.lua',
                },
            },
            -- Make the server aware of Neovim runtime files
            workspace = {
                checkThirdParty = false,
                -- Tells lua_ls where to look for require files
                library = {
                    vim.env.VIMRUNTIME,
                    -- Needed to enable "go to defintion" on the require("*") files above. Otherwise
                    -- lua_ls won't know where to look for require files.
                    vim.fn.stdpath("config")
                }
            }
        })
    end,
    settings = {
        Lua = {}
    }
})
vim.lsp.enable('lua_ls')

vim.lsp.config('clangd', { capabilities = capabilities })
vim.lsp.enable('clangd')

require 'lspconfig'.powershell_es.setup {
    bundle_path = "~/tools/PowerShellEditorServices",
}

vim.lsp.enable("neocmake")

require("fzf-lua").setup({"hide",})

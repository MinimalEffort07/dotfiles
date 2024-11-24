require('config.lazy')
require('keybinds')
require('autocommands')
require('options')

vim.cmd("colorscheme cyberdream")

require('lspconfig').pyright.setup({})

require 'lspconfig'.lua_ls.setup {
    on_init = function(client)
        client.config.settings.Lua = vim.tbl_deep_extend('force', client.config.settings.Lua, {
            -- Tell language server which version of Lua you're using. LuaJIT for Neovim)
            runtime = { version = 'LuaJIT' },
            -- Make the server aware of Neovim runtime files
            workspace = {
                checkThirdParty = false,
                library = { vim.env.VIMRUNTIME }
            }
        })
    end,
    settings = {
        Lua = {}
    }
}

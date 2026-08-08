return {
    {
        'nvim-telescope/telescope.nvim', version = '*',
        dependencies = {
            'nvim-lua/plenary.nvim',
            -- optional but recommended
            { 'nvim-telescope/telescope-fzf-native.nvim', build = 'make' },
        },
        opts = {
            defaults = {
                layout_strategy = 'vertical',
                layout_config = {
                    vertical = {
                        width = 0.99,
                        height = 0.99,
                        preview_height = 0.7,
                        mirror = false,
                    },
                },
            },
        },
    },
}

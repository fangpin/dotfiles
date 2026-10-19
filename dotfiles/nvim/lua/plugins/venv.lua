
return {
  "linux-cultist/venv-selector.nvim",
  dependencies = { "neovim/nvim-lspconfig", "nvim-telescope/telescope.nvim" },
  opts = {
    -- Your configuration for venv-selector.nvim can go here.
    -- For example:
    -- name = {
    --   "venv",
    --   ".venv",
    --   "env",
    --   ".env"
    -- }
  },
  keys = {
    { "<leader>v", desc = "Virtual Env" },
    { "<leader>vs", "<cmd>VenvSelect<cr>", desc = "Select VirtualEnv" },
    { "<leader>vc", "<cmd>VenvSelectCached<cr>", desc = "Select VirtualEnv (cached)" },
  },
}

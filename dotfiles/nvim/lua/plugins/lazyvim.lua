return {
  {
    "kdheepak/lazygit.nvim",
    config = function()
      -- 指定 lazygit 的路径
      vim.g.lazygit_floating_window_winblend = 0
      vim.g.lazygit_floating_window_scaling_factor = 0.9
      vim.g.lazygit_use_neovim_remote = true
      vim.g.lazygit_path = "/usr/local/bin/lazygit" -- 确保路径正确
    end,
  },
}

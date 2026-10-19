-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
vim.keymap.set("i", "fd", "<Esc>", { noremap = true, silent = true })
vim.keymap.set("n", "fd", "<Esc>", { noremap = true, silent = true })

-- macOS: Command+V 粘贴 (添加以下内容)
if vim.fn.has("macunix") == 1 then
  local function paste_in_terminal()
    local content = vim.fn.getreg("+")
    vim.api.nvim_paste(content, true, -1)
  end

  vim.keymap.set("n", "<D-v>", '"+p', { noremap = true, silent = true, desc = "Paste from clipboard (normal)" })
  vim.keymap.set("i", "<D-v>", "<C-r>+", { noremap = true, silent = true, desc = "Paste from clipboard (insert)" })
  vim.keymap.set("v", "<D-v>", '"+P', { noremap = true, silent = true, desc = "Paste from clipboard (visual)" })
  vim.keymap.set("c", "<D-v>", "<C-r>+", { noremap = true, silent = true, desc = "Paste from clipboard (command)" })
  vim.keymap.set(
    "t",
    "<D-v>",
    paste_in_terminal,
    { noremap = true, silent = true, desc = "Paste from clipboard (terminal)" }
  )
end

-- ~/.config/nvim/lua/config/keymaps.lua
local misc = require("config.misc")

-- 复制当前文件的相对路径（含文件名）
vim.keymap.set("n", "<leader>fp", misc.copy_relative_path_with_filename, {
  desc = "Copy relative path with filename to clipboard",
  silent = true,
  noremap = true,
})

if vim.g.neovide then
  vim.keymap.set({ "n", "v" }, "<c-=>", ":lua vim.g.neovide_scale_factor = vim.g.neovide_scale_factor + 0.1<cr>")
  vim.keymap.set({ "n", "v" }, "<c-->", ":lua vim.g.neovide_scale_factor = vim.g.neovide_scale_factor - 0.1<cr>")
  vim.keymap.set({ "n", "v" }, "<c-0>", ":lua vim.g.neovide_scale_factor = 1<cr>")
  vim.g.neovide_input_macos_cmd = true
end

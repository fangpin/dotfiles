-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
vim.opt.relativenumber = false
vim.opt.wrap = true

-- swap file
vim.opt.swapfile = false

-- python
-- LSP Server to use for Python.
-- Set to "basedpyright" to use basedpyright instead of pyright.
-- vim.g.lazyvim_python_lsp = "pyright"
-- Set to "ruff_lsp" to use the old LSP implementation version.
-- vim.g.lazyvim_python_ruff = "ruff"

-- vscode
-- vim.g.vscode = true
--

-- -- 保存原始 notify 函数
-- local original_notify = vim.notify
--
-- -- 自定义 notify，过滤掉 Codeium 的通知
-- vim.notify = function(msg, level, opts)
--   if type(msg) == "string" and msg:match("Codeium") then
--     return
--   end
--   original_notify(msg, level, opts)
-- end
--
-- -- 可选：关闭 Codeium 的状态提示
-- vim.g.codeium_disable_status_prompt = 1

vim.opt.clipboard = "unnamedplus"

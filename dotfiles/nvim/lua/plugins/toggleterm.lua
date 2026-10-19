return {
  "akinsho/toggleterm.nvim",
  opts = {
    direction = "float",
    float_opts = {
      border = "curved",
    },
    size = function(term)
      if term.direction == "float" then
        return math.floor(vim.o.lines * 0.5)
      end
      return 10
    end,
  },
}

return {
  copy_relative_path_with_filename = function()
    local path = vim.api.nvim_buf_get_name(0) -- 获取当前 buffer 的完整路径
    if not path or path == "" then
      print("当前缓冲区没有关联文件")
      return
    end

    -- 获取相对路径（相对于当前工作目录）
    local relpath = vim.fn.fnamemodify(path, ":.")
    if relpath == "" then
      print("无法获取相对路径")
      return
    end

    -- 根据平台选择复制命令
    local copy_cmd = {
      Darwin = "pbcopy",
      Linux = "xclip -selection clipboard",
      Windows = "clip",
    }

    local sysname = vim.loop.os_uname().sysname
    local cmd = copy_cmd[sysname]

    if not cmd then
      print("不支持的操作系统：" .. sysname)
      return
    end

    local handle = io.popen(cmd, "w")
    if handle then
      handle:write(relpath)
      handle:close()
      print("已复制相对路径到剪贴板: " .. relpath)
    else
      print("复制失败，请检查剪贴板工具是否安装")
    end
  end,
}

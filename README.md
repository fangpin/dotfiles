# dotfiles

用于初始化 macOS 和 Debian/Ubuntu 开发环境的个人配置仓库。仓库只保存适合公开分享的通用设置；账号、凭据、项目历史、私有仓库地址和机器专用配置都应留在本机。

## 初始化

macOS：

```bash
./bootstrap-mac.sh
```

Debian 12/bookworm：

```bash
./bootstrap-debian12.sh
```

其他 Debian/Ubuntu：

```bash
./bootstrap-debian.sh
```

脚本会安装常用开发工具，并恢复仓库中经过筛选的 shell、Git、SSH、Neovim、Cursor、Agents、Codex、TraeX、Claude、Ghostty、Karabiner 和系统设置。需要登录、授权或包含个人身份的配置仍需在新机器上单独完成。

## 公开仓库边界

以下内容不得提交：

- API key、token、cookie、密码和认证缓存；
- SSH 私钥、公钥以及机器专用主机配置；
- Git 用户名、邮箱、凭据、私有 URL rewrite 和内部 hook；
- 私有仓库地址、项目历史、工作区路径和内部服务域名；
- AI 工具的会话、memory、数据库、日志、插件缓存和运行状态；
- 未经人工确认可公开的 skills、rules、hooks 和 MCP 配置。

`.gitignore` 已覆盖常见密钥文件和运行目录，但忽略规则不能替代提交前审查。建议每次推送前运行测试和敏感信息扫描。

## 配置同步

查看或恢复配置：

```bash
./sync-dev-configs.sh status
./sync-dev-configs.sh restore
```

批量 `backup` 只处理有明确白名单或脱敏规则的配置。Codex、TraeX、Claude 和 Ghostty 的自动回写已关闭，因为这些文件可能混入项目历史、内部地址和凭据；需要更新时，请手工修改仓库模板并审查差异。

Cursor 只同步 `AGENTS.md`、`argv.json` 和 `blocklist`。Agents 只同步顶层 instruction 文件。skills、hooks、MCP 配置、commands、rules 和运行数据默认留在本机。

## Git 和 Go 仓库清单

`sync-gitconfig.sh backup` 只导出少量通用 Git 设置，不会复制用户身份、凭据、URL rewrite、代理、证书绕过或 hooks 路径。

`sync-go-src-repos.sh backup` 只导出本机白名单中的公开仓库。先创建：

```text
~/.config/dotfiles/public-go-remotes.txt
```

每行填写一个允许公开的完整 remote URL。也可以通过 `PUBLIC_GO_REPOS_ALLOWLIST` 指定其他白名单文件。

## SSH 配置和私钥

仓库中的 `dotfiles/ssh/config` 只包含安全的通用设置。主机名、用户名和跳板机配置应写入被忽略的 `~/.ssh/config.local`。

SSH 私钥和公钥都不进入仓库。若确实需要迁移，可用下面的脚本把加密副本写到仓库外的私有目录：

```bash
./sync-ssh-key.sh backup
./sync-ssh-key.sh restore
```

默认目录是 `~/.local/share/dotfiles-private/ssh`，可用 `DOTFILES_PRIVATE_DIR` 覆盖。加密文件仍应放在受访问控制的私有存储中，不应上传到公开 GitHub 仓库。

## 单项脚本

- `sync-zsh-config.sh`：保存脱敏后的 zsh 模板，并在恢复时沿用本机凭据；
- `sync-gitconfig.sh`：导出通用 Git 白名单配置；
- `sync-go-src-repos.sh`：同步显式允许公开的 Go 仓库清单；
- `sync-nvim-config.sh`：同步 Neovim 配置，排除本机运行目录；
- `sync-cursor-config.sh`：同步少量 Cursor 白名单文件；
- `sync-agents-config.sh`：同步顶层 instruction 文件，不复制 skills；
- `sync-lark-channel-config.sh`：恢复人工审查过的 Lark Channel 配置，自动备份关闭；
- `sync-ai-app-configs.sh`：恢复人工维护的 AI 应用模板；
- `sync-karabiner-config.sh`：同步 Karabiner 配置；
- `sync-macos-settings.sh`：同步白名单内的 macOS 设置；
- `sync-ssh-key.sh`：在仓库外加密备份或恢复 SSH key。

## 已经泄露过的密钥

从当前工作树删除密钥并不能撤销 Git 历史中的泄露。只要密钥曾进入公开提交，就应立即轮换或吊销；如需彻底清理历史，再单独使用 `git filter-repo`，并在确认影响后强制推送所有相关引用。

# Personal Agent Instructions

- 每次确认代码改动完毕后，默认自动 commit、push，并创建对应代码托管平台的 MR/PR；除非用户在当次任务中明确要求不要 commit、push 或创建 MR/PR。
- commit、push 和创建 MR/PR 前仍需先完成必要验证，并确保提交只包含本次任务相关改动。
- 启动子代理时不要尝试切换模型，也不要主动传显式 model override；默认继承并使用与主代理相同的模型，除非用户在当次任务中明确要求使用不同模型。
- 新建 git 分支时一律以 `pin/` 开头（例如 `pin/<topic>`），不要使用 `feat/`、`fix/` 等前缀；这是个人习惯，仅约束本地建分支操作，不需要写进任何仓库的 AGENTS.md。

# claude-codex-code-review

在 Claude Code 里安装一个项目级 `/codex-review` 命令，让你可以用 Codex CLI 审查 Claude 刚写完的代码，再由 Claude 读取 review 结果并按你的选择修复问题。

典型流程：

1. 你在 Claude Code 里让 Claude 写代码。
2. 写完后手动运行 `/codex-review`。
3. Codex CLI review 当前项目的未提交改动。
4. review 结果保存到 `.ai-review/codex-review.md`。
5. Claude 读取结果，列出问题，并询问你要修复哪些。
6. 你确认后，Claude 只修复选中的问题。

## 安装

### 使用 curl

在目标项目根目录执行：

```bash
curl -fsSL https://raw.githubusercontent.com/lkkwxy/claude-codex-claude-codex-review-claude/main/scripts/install.sh | bash
```

注意：`curl | bash` 必须使用 `raw.githubusercontent.com` 地址，不能使用 GitHub 页面里的 `blob/main` 地址。

### 使用 npx

发布到 npm 后，可以在目标项目根目录执行：

```bash
npx claude-codex-code-review install
```

也可以指定安装目录：

```bash
npx claude-codex-code-review install -- --target-dir /path/to/project
```

如果需要覆盖已有文件：

```bash
npx claude-codex-code-review install -- --force
```

## 使用

安装后，在目标项目里打开 Claude Code，运行：

```text
/codex-review
```

也可以临时传入策略参数：

```text
/codex-review --mode severity --auto-fix-severities P0,P1
```

## 安装内容

安装器会写入这些文件：

```text
.claude/commands/codex-review.md
scripts/codex-review.sh
.codex-review.yml
.gitignore
```

运行 `/codex-review` 后，会生成：

```text
.ai-review/codex-review.md
.ai-review/codex-review.log
.ai-review/effective-config.env
```

`.ai-review/` 会被加入 `.gitignore`。

## 配置

默认配置文件是 `.codex-review.yml`：

```yaml
mode: ask
review_scope: uncommitted
max_fix_rounds: 1
auto_fix_severities: []
```

配置优先级：

1. `/codex-review` 命令参数
2. `.codex-review.yml`
3. 内置默认值

如果没有 `.codex-review.yml`，也没有传任何参数，会使用以下默认值：

```yaml
mode: ask
review_scope: uncommitted
max_fix_rounds: 1
auto_fix_severities: []
```

### 参数说明

```text
--mode ask|auto|severity
--review-scope uncommitted
--max-fix-rounds 1
--auto-fix-severities P0,P1
```

`mode` 含义：

- `ask`：默认模式。每次 review 后都询问你是否修复、修复哪些。
- `auto`：自动修复 Codex 明确指出的 actionable findings。
- `severity`：只自动修复 `auto_fix_severities` 中指定级别的问题，其他问题继续询问。

当前 `review_scope` 只支持 `uncommitted`，也就是 review staged、unstaged 和 untracked changes。

## 依赖

使用前需要本机已经安装并登录：

- Git
- Claude Code
- Codex CLI

可以用下面的命令检查 Codex CLI：

```bash
codex --help
```

## 设计原则

- Codex review 阶段只审查，不修改代码。
- Claude 修复阶段只处理 Codex 明确指出的问题。
- 默认不自动修复，先由用户判断。
- 不自动 commit，最终提交仍由开发者确认。
- 最多执行配置允许的修复轮次，避免自动循环。

## 发布到 npm

包名：

```text
claude-codex-code-review
```

发布前检查：

```bash
npm test
npm pack --dry-run
```

发布：

```bash
npm publish
```

如果 npm 要求 2FA 或 token，请按 npm 当前账号策略配置 security key 或 granular access token。

# 1. 消息分段

# 简介

## 功能说明

让 Telegram bot 一次回复变成多条短消息，而不是一整段长消息。两条消息之间还能显示"对方正在输入..."，使对话节奏更接近真人。

## 效果对比

启用前——一整条：

```
[bot] 哦你来啦我刚还在想你呢今天怎么样
```

启用后——分四条，段间停顿可配置（停顿期间显示"正在输入..."）：

```
[bot] 哦
[bot] 你来啦
[bot] 我刚还在想你呢
[bot] 今天怎么样
```

## 实现方式

本模块通过修改官方 Telegram 插件的源代码（`server.ts`）实现，让插件在接到 Claude 的回复时按空行（`\n\n`）拆分文本，每段作为独立 Telegram 消息发出。这种修改方式称为"打补丁"，不会替换整个文件，只是插入几行代码。

# 安装

## 前置要求

需先完成官方 Telegram 插件的安装，并确认 bot 能正常收发文字消息。

## 步骤一：应用补丁

补丁脚本会先在原文件同目录生成 `.bak` 备份，再修改 `server.ts`。脚本可重复执行——已经打过的话会自动跳过，不会重复修改。

**Mac / Linux：**
```bash
python3 1-message-split/apply.py \
  ~/.claude/plugins/marketplaces/claude-plugins-official/external_plugins/telegram/server.ts
```

**Windows（PowerShell）：**
```powershell
python 1-message-split\apply.py "$env:USERPROFILE\.claude\plugins\marketplaces\claude-plugins-official\external_plugins\telegram\server.ts"
```

## 步骤二：在 bot 配置中开启功能

bot 的配置文件位于 `~/.claude/channels/<bot 名>/access.json`。打开该文件，在 JSON 对象中追加以下字段：

```json
{
  "splitOnParagraph": true,
  "paragraphDelay": 600
}
```

字段说明：

- `splitOnParagraph`：分段总开关。设为 `false` 或不写时行为与未打补丁一致
- `paragraphDelay`：两段之间的停顿时长（毫秒），停顿期间显示"正在输入..."。建议取值 400 至 800 之间。设为 0 时段落连续发出，不显示停顿状态

## 步骤三：在 bot 的 CLAUDE.md 中加入提示词

这一步告诉 Claude 写回复时要用空行分段。

通过项目根目录的 `install.sh` 一键安装时，本步骤已自动完成（追加至 `~/.claude/channels/<bot>/CLAUDE.md`，仅追加不修改原有内容）。

如果是手动逐个模块安装，则需将 [`CLAUDE-snippet.md`](./CLAUDE-snippet.md) 中的内容整段复制到 bot 的 `CLAUDE.md` 文件末尾。

## 重启 bot 使配置生效

按你运行 bot 的方式重启它（一般是结束当前 tmux 会话或对应进程，让其自动重启）。

# 使用

## 调用方式

补丁仅修改服务端行为，不引入新参数。Claude 写回复时只需注意以空行分隔语义独立的段落，插件会自动拆分发送。

## 卸载

执行恢复脚本，将代码还原至备份状态：

```bash
bash 1-message-split/revert.sh /path/to/server.ts
```

或更简单的办法——将 `access.json` 中的 `splitOnParagraph` 改为 `false`，即可关闭功能而无需还原源码。

## 故障排查

**输出 `no changes (already patched)`**。表示补丁已应用，属正常情况，无需重复执行。

**消息仍以单条形式发出**。检查 `access.json` 中是否正确写入 `splitOnParagraph: true`，以及 bot 是否已重启。

**报错 `error: ... not found`**。`server.ts` 路径填写有误，请核对官方插件的实际安装位置。

**官方插件升级后补丁失效**。上游代码可能发生变更。本补丁依赖字符串匹配定位修改位置，对版本较为敏感。遇此情况可在 issue 中反馈，或自行修改 `apply.py` 中的匹配字符串。

# 开源协议

本模块作为 [Claude TG Patch](../) 的一部分发布，采用 [MIT 协议](../LICENSE)。

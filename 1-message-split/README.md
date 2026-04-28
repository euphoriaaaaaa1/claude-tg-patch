# 1. Message Split

# 简介

## 功能说明

为官方 telegram plugin 的 reply 工具增加段落分发能力。打补丁后，claude 在文本中以空行（`\n\n`）分隔的多个段落，会被 server 拆分为多条独立的 Telegram 消息逐条发出。两条消息之间可设置等待间隔，期间向用户显示"对方正在输入..."状态，使对话节奏更接近真人。

## 行为对比

未启用：

```
[bot] 哦你来啦我刚还在想你呢今天怎么样
```

启用后（每段独立消息，段间停顿可配置）：

```
[bot] 哦
[bot] 你来啦
[bot] 我刚还在想你呢
[bot] 今天怎么样
```

# 安装

## 前置条件

需先完成官方 telegram plugin 的部署并确认其能够正常收发文本消息。

## 操作步骤

### 第一步：应用补丁

`apply.py` 通过字符串匹配修改 telegram plugin 的 `server.ts`。脚本幂等，可重复执行；首次运行将在原文件同目录生成 `.bak` 备份。

```bash
# macOS / Linux
python3 1-message-split/apply.py \
  ~/.claude/plugins/marketplaces/claude-plugins-official/external_plugins/telegram/server.ts
```

```powershell
# Windows PowerShell
python 1-message-split\apply.py "$env:USERPROFILE\.claude\plugins\marketplaces\claude-plugins-official\external_plugins\telegram\server.ts"
```

### 第二步：开启功能开关

在 bot 的 `access.json`（路径通常为 `~/.claude/<bot 名>/access.json`）中追加以下字段：

```json
{
  "splitOnParagraph": true,
  "paragraphDelay": 600
}
```

`paragraphDelay` 为段间等待时间，单位毫秒，建议取值 400 至 800 之间。设为 0 时段落连续发出，不显示输入状态。

### 第三步：补充 prompt 规则

在 bot 的 `CLAUDE.md` 末尾追加以下内容，约束 claude 的回复格式：

```markdown
回复以空行分段，每段不超过 30 字，单次最多 3 至 5 段，使用一次 reply 调用完成。
```

完成后重启 bot 使配置生效。

# 使用

## 调用方式

补丁仅修改服务端行为，不引入新的工具或参数。claude 写入 reply 时只需注意以空行分隔语义独立的段落即可，server 会自动拆分发送。

## 卸载

```bash
bash 1-message-split/revert.sh /path/to/server.ts
```

或在 `access.json` 中将 `splitOnParagraph` 设为 `false` —— 后者无需还原 server.ts 即可关闭功能。

## 故障排查

**输出为 `no changes (already patched)`**。表示补丁已应用，非异常。

**消息仍以单条形式发出**。检查 access.json 中是否正确写入 `splitOnParagraph: true`，以及 bot 是否已完成重启。

**报错 `error: ... not found`**。server.ts 路径错误，请核对官方 plugin 的实际安装位置。

**plugin 升级后补丁失效**。上游字符串可能已变更。本补丁依赖字符串匹配，对版本敏感，可在 issue 中反馈或自行修改 `apply.py` 中的 selector。

# 开源协议

本模块作为 [Claude TG Patch](../) 的一部分发布，采用 [MIT License](../LICENSE)。

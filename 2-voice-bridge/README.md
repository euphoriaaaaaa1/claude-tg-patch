# 2. Voice Bridge

# 简介

## 功能说明

提供 Telegram bot 与语音消息之间的双向桥接，包含两个独立的能力。

**入站方向**。用户在 Telegram 发送 voice message 时，server 调用本地部署的 SenseVoice 模型完成转写，结果包含中文文本与情绪标签（HAPPY、SAD、ANGRY 等）。claude 收到的输入为普通文本，附带情绪元数据。

**出站方向**。claude 调用 reply 工具时附加 `as_voice: true` 参数后，server 将文本送至 Fish Audio S2 接口合成 mp3，再调用 Telegram sendVoice 发送。支持以下能力：

- 段落拆分：与 [1-message-split](../1-message-split) 配合使用时，每段文本对应一条独立语音
- 行内情绪标签：在文本中嵌入 `[叹气]`、`[温柔地]` 等标记，由 Fish S2 解析
- 双语模式：同一回复中同时包含中文文字气泡与日文（或其他语言）语音气泡

## 架构概览

```
Telegram → 官方 telegram plugin → claude (worker)
                                       │
                       ┌───────────────┴────────────────┐
                       ▼                                ▼
              MCP voice-bridge                 reply(as_voice=true)
                       │                                │
                       └────────────┐    ┌──────────────┘
                                    ▼    ▼
                              server_http.py (FastAPI, 7788)
                                    │
                       ┌────────────┴────────────┐
                       ▼                         ▼
              SenseVoice (本地)           Fish Audio (远端)
              语音转文字                   文字转语音
```

`server_http.py` 常驻于本机 7788 端口，多个 bot 可共享同一个实例，从而共用 SenseVoice 模型避免重复加载。

# 安装

## 凭证准备

**Fish Audio API key**。在 [fish.audio](https://fish.audio) 注册并完成充值，S2 模型按字符计费。在右上角菜单进入 API 页面生成 key。

**Fish Audio 音色 id**。在主页 voice library 试听并选定音色，详情页 URL 形如 `https://fish.audio/m/<音色 id>`，末段即为所需值。

**Telegram bot token**。沿用官方 telegram plugin 已有的 token，或通过 [@BotFather](https://t.me/BotFather) 新建。

## 操作步骤（macOS / Linux）

### 第一步：创建 Python 虚拟环境

```bash
cd 2-voice-bridge
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
```

依赖包含 torch 与 funasr，体积较大，初次安装耗时较长。

### 第二步：写入配置

```bash
cp .env.example .env
# 编辑 .env，填入 FISH_AUDIO_API_KEY 与 TELEGRAM_BOT_TOKEN
```

### 第三步：启动服务

```bash
chmod +x start.sh
./start.sh start
curl http://127.0.0.1:7788/health   # 应返回 {"ok": true, ...}
```

首次启动会从 ModelScope 下载 SenseVoice 模型至本地 `models/` 目录，体积约 1GB。如需走代理可在 `.env` 中设置 `HTTPS_PROXY`。

### 第四步：为 telegram plugin 应用补丁

```bash
.venv/bin/python apply_patch.py \
  ~/.claude/plugins/marketplaces/claude-plugins-official/external_plugins/telegram/server.ts
```

补丁为 reply 工具新增 `as_voice`、`voice_emotion`、`voice_instruct` 三个参数。

### 第五步：注册 MCP server 至 bot

将 `mcp-snippet.json` 中的 `voice-bridge` 段合并入 bot 的 `.mcp.json`。由于 JSON 不支持 `~` 路径展开，必须填写绝对路径：

```json
{
  "mcpServers": {
    "voice-bridge": {
      "command": "/Users/yourname/claude-tg-patch/2-voice-bridge/.venv/bin/python",
      "args": ["/Users/yourname/claude-tg-patch/2-voice-bridge/server.py"],
      "env": {}
    }
  }
}
```

### 第六步：在 access.json 中指定音色

```json
{ "voiceId": "在 fish.audio 选取的音色 id" }
```

未设置该字段时，`as_voice=true` 将被忽略并降级为文字回复。

### 第七步：同步 prompt 模板

```bash
.venv/bin/python sync_snippet.py ~/.claude/channels/<bot 名>/CLAUDE.md
```

将 voice-bridge 相关的提示词追加至 bot 的 CLAUDE.md（以 HTML 注释包裹，可重复执行覆盖更新）。

完成后重启 bot。

## 操作步骤（Windows PowerShell）

```powershell
cd 2-voice-bridge
python -m venv .venv
.venv\Scripts\pip install -r requirements.txt

copy .env.example .env
notepad .env

# Windows 不使用 start.sh，直接前台运行（或以 Start-Process 后台运行）
.venv\Scripts\python.exe server_http.py
```

补丁与 snippet 同步：

```powershell
.venv\Scripts\python.exe apply_patch.py "$env:USERPROFILE\.claude\plugins\marketplaces\claude-plugins-official\external_plugins\telegram\server.ts"
.venv\Scripts\python.exe sync_snippet.py "$env:USERPROFILE\.claude\channels\<bot 名>\CLAUDE.md"
```

`mcp-snippet.json` 中路径改为 Windows 绝对路径形式（注意双反斜杠）：

```json
"command": "C:\\Users\\yourname\\claude-tg-patch\\2-voice-bridge\\.venv\\Scripts\\python.exe",
"args": ["C:\\Users\\yourname\\claude-tg-patch\\2-voice-bridge\\server.py"]
```

# 使用

## 调用方式

claude 通过 reply 工具的扩展参数控制语音输出。

```json
// 单一语音消息
{ "chat_id": "...", "text": "今天好累呀。", "as_voice": true }

// 携带情绪标签
{ "chat_id": "...", "text": "[叹气] 又加班。", "as_voice": true, "voice_emotion": "SAD" }

// 双语模式：text 显示为中文文字气泡，voice_text 朗读为日文语音
{
  "chat_id": "...",
  "text": "今天好累呀。",
  "voice_text": "今日はとても疲れたよ。",
  "as_voice": true
}
```

`sync_snippet.py` 已将上述用法的判断规则注入 CLAUDE.md，多数情况下 claude 自行判断使用文字或语音回复。完整规范见 [CLAUDE-voice-reply-snippet.md](./CLAUDE-voice-reply-snippet.md)。

## 故障排查

**`start.sh: Permission denied`**。执行 `chmod +x start.sh` 赋予执行权限。

**`.venv/bin/python: No such file`**。虚拟环境未创建，重新执行第一步。

**`/health` 接口不响应**。查看 `logs/http_server.out`，多数情况下是 SenseVoice 模型下载尚未完成或下载失败。可在 `.env` 中设置 `HTTPS_PROXY` 走代理，或从 ModelScope 手动下载至 `models/` 目录。

**`as_voice=true` 不生效**。确认 access.json 中的 `voiceId`、`.mcp.json` 中的 voice-bridge 注册项均已配置，并已重启 bot。

**`apply_patch.py` 执行后语音功能无变化**。可能上游 plugin 已升级且字符串选择器失效，需手动调整补丁。

# 开源协议

本模块作为 [Claude TG Patch](../) 的一部分发布，采用 [MIT License](../LICENSE)。

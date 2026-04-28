# 2. 收发语音

# 简介

## 功能说明

让 Telegram bot 能听语音、能发语音。两个方向的能力互相独立，可单独使用。

**收语音**。用户在 Telegram 给 bot 发送语音消息时，本地服务自动调用 [SenseVoice](https://github.com/FunAudioLLM/SenseVoice) 模型完成语音转文字（ASR），输出包含中文文本和情绪识别结果（如开心、悲伤、愤怒）。Claude 收到的是普通文字消息，附带情绪信息可作语气调整参考。

**发语音**。Claude 在调用回复工具时附带 `as_voice: true` 参数，本地服务会将文本送至 [Fish Audio](https://fish.audio) 的 S2 模型完成文字转语音（TTS），合成 mp3 后通过 Telegram 发送。

附加能力：

- **段落拆分**：与 [1-message-split](../1-message-split) 配合时，每个段落对应一条独立的语音消息
- **行内情绪标签**：在文本中嵌入 `[叹气]`、`[温柔地]` 等标记，由 Fish Audio 解析为对应语气
- **双语模式**：同一回复可同时包含中文文字气泡和日文（或其他语言）语音气泡

## 工作原理简述

```
Telegram 收到语音
   ↓
官方 Telegram 插件
   ↓
经由本仓库提供的 MCP 服务（MCP 是 Claude 调用外部工具的标准协议）
   ↓
转发到本机 7788 端口的 HTTP 服务
   ↓
两条路径：
  - 本地 SenseVoice 模型 → 转写
  - 远程 Fish Audio 接口 → 合成
```

本机 HTTP 服务常驻不退出，多个 bot 共用同一份 SenseVoice 模型，避免重复加载占用内存。

# 安装

## 准备 API 密钥

**Fish Audio 密钥**。访问 [fish.audio](https://fish.audio) 注册账号并完成充值，按合成的字符数计费。在右上角菜单进入 API 页面生成密钥。

**Fish Audio 音色 id**。在主页 voice library 中试听并选定一个音色，详情页 URL 形如 `https://fish.audio/m/<这一段就是音色 id>`，末段即为所需值。

**Telegram bot token**。沿用官方 Telegram 插件已有的 token，或通过 [@BotFather](https://t.me/BotFather) 新建。

## 操作步骤（macOS / Linux）

### 步骤一：创建独立的 Python 环境

新建一个独立环境（venv），所需依赖只装在这个目录里，不影响系统 Python：

```bash
cd 2-voice-bridge
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
```

依赖中包含 PyTorch 和 funasr，体积较大，初次安装耗时较长。

### 步骤二：写入配置

```bash
cp .env.example .env
# 用编辑器打开 .env，填入 FISH_AUDIO_API_KEY 与 TELEGRAM_BOT_TOKEN
```

### 步骤三：启动本地服务

```bash
chmod +x start.sh
./start.sh start
curl http://127.0.0.1:7788/health   # 应返回 {"ok": true, ...}
```

首次启动会从 ModelScope 自动下载 SenseVoice 模型至本地 `models/` 目录，体积约 1GB。如网络访问受限，可在 `.env` 中设置 `HTTPS_PROXY` 走代理。

### 步骤四：为官方 Telegram 插件应用补丁

补丁会为 Claude 的回复工具新增 `as_voice`、`voice_emotion`、`voice_instruct` 三个参数，使其支持语音输出：

```bash
.venv/bin/python apply_patch.py \
  ~/.claude/plugins/marketplaces/claude-plugins-official/external_plugins/telegram/server.ts
```

### 步骤五：在 bot 中注册 MCP 服务

将 `mcp-snippet.json` 中的 `voice-bridge` 段合并入 bot 的 `.mcp.json` 文件。由于 JSON 格式不支持 `~` 路径展开，需填写完整绝对路径：

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

### 步骤六：在 access.json 中指定音色

打开 bot 的 `access.json`（位于 `~/.claude/channels/<bot 名>/access.json`），追加：

```json
{ "voiceId": "你在 fish.audio 选的音色 id" }
```

未设置该字段时，即使 Claude 标记为语音输出也会自动降级为文字回复。

### 步骤七：同步提示词到 bot 的 CLAUDE.md

让 Claude 知道何时使用语音、如何使用情绪标签：

```bash
.venv/bin/python sync_snippet.py ~/.claude/channels/<bot 名>/CLAUDE.md
```

该命令会以 HTML 注释包裹的形式追加提示词段落，可重复执行覆盖更新，不影响你已有内容。

### 重启 bot

按你运行 bot 的方式重启使其重新加载配置。

## 操作步骤（Windows / PowerShell）

```powershell
cd 2-voice-bridge
python -m venv .venv
.venv\Scripts\pip install -r requirements.txt

copy .env.example .env
notepad .env

# Windows 没有 start.sh，前台直接运行（关闭终端服务也会停）
.venv\Scripts\python.exe server_http.py
```

补丁与 snippet 同步：

```powershell
.venv\Scripts\python.exe apply_patch.py "$env:USERPROFILE\.claude\plugins\marketplaces\claude-plugins-official\external_plugins\telegram\server.ts"
.venv\Scripts\python.exe sync_snippet.py "$env:USERPROFILE\.claude\channels\<bot 名>\CLAUDE.md"
```

`mcp-snippet.json` 中路径换成 Windows 形式（注意双反斜杠）：

```json
"command": "C:\\Users\\yourname\\claude-tg-patch\\2-voice-bridge\\.venv\\Scripts\\python.exe",
"args": ["C:\\Users\\yourname\\claude-tg-patch\\2-voice-bridge\\server.py"]
```

# 使用

## Claude 调用语音的方式

```json
// 普通语音
{ "chat_id": "...", "text": "今天好累呀。", "as_voice": true }

// 携带情绪
{ "chat_id": "...", "text": "[叹气] 又加班。", "as_voice": true, "voice_emotion": "SAD" }

// 双语：text 显示为中文文字气泡，voice_text 朗读为日文语音
{
  "chat_id": "...",
  "text": "今天好累呀。",
  "voice_text": "今日はとても疲れたよ。",
  "as_voice": true
}
```

`sync_snippet.py` 已将上述使用规则注入 CLAUDE.md，多数场景下 Claude 会自行判断采用文字还是语音回复。完整规则详见 [CLAUDE-voice-reply-snippet.md](./CLAUDE-voice-reply-snippet.md)。

## 故障排查

**`start.sh: Permission denied`**。脚本缺少执行权限，运行 `chmod +x start.sh` 添加。

**`.venv/bin/python: No such file`**。Python 独立环境未创建，回到步骤一。

**`/health` 接口无响应**。查看 `logs/http_server.out` 日志。多数情况下是 SenseVoice 模型下载尚未完成或下载失败。可在 `.env` 中设置 `HTTPS_PROXY` 走代理，或从 ModelScope 手动下载至 `models/` 目录。

**`as_voice: true` 不生效**。逐项确认：`access.json` 中是否填了 `voiceId`、`.mcp.json` 中是否注册了 voice-bridge、bot 是否已重启。

**应用补丁后语音功能仍无变化**。可能官方插件已升级且字符串匹配位置变更，需手动调整 `apply_patch.py`。

# 开源协议

本模块作为 [Claude TG Patch](../) 的一部分发布，采用 [MIT 协议](../LICENSE)。

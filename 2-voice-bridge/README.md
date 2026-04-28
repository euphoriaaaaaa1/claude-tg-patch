# 2. Voice Bridge

让 bot 能听语音、能发语音。

## 干啥的

两件事：

**听语音**：用户在 Telegram 给 bot 发 voice message，server 后台调本地 SenseVoice 模型转写成中文（带情绪标签），claude 看到的就是普通文字加一句情绪元数据。

**发语音**：claude 在 reply 里多传一个 `as_voice: true`，server 把文本送到 Fish Audio S2 合成 mp3，再用 Telegram sendVoice 发出去。支持行内情绪标签（`今天好累呀。[叹气] 但看到你就好了。`）和双语模式（中文文字气泡 + 日文语音气泡）。

跟 message-split 配合用，每段都能变成独立的语音消息。

## API key 在哪拿

**Fish Audio**：去 fish.audio 注册，充几刀，右上角 API 生成 key。S2 按字符算钱，1 万字符约 $0.5，先充 $5 够用很久。音色去主页 voice library 试听挑一个，详情页 URL `https://fish.audio/m/<这一段就是 voice_id>`。

**Telegram bot token**：你已经在跑官方 plugin 的话直接复用现成的；没有的话 Telegram 找 @BotFather 走 `/newbot`。

## 装（mac / Linux）

```bash
cd 2-voice-bridge
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt    # torch + funasr 比较重，慢

cp .env.example .env
# 编辑 .env 填 FISH_AUDIO_API_KEY 和 TELEGRAM_BOT_TOKEN

chmod +x start.sh
./start.sh start                              # 第一次启动会下 SenseVoice 模型 ~1GB
curl http://127.0.0.1:7788/health             # 应回 {"ok": true, ...}
```

然后给官方 telegram plugin 打补丁，加 `as_voice` 等参数：

```bash
.venv/bin/python apply_patch.py \
  ~/.claude/plugins/marketplaces/claude-plugins-official/external_plugins/telegram/server.ts
```

把 voice-bridge 注册进 bot 的 `.mcp.json`（每个 bot 一份）。JSON 不认 `~`，得写绝对路径：

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

bot 的 access.json 加 `voiceId`：

```json
{ "voiceId": "你在 fish.audio 选的音色 id" }
```

让 claude 知道何时用语音：

```bash
.venv/bin/python sync_snippet.py ~/.claude/<bot 名>/CLAUDE.md
```

会自动追加两段说明（用 HTML 注释包起来，可以反复跑覆盖更新），告诉 claude 什么时候该 `as_voice=true`、情绪标签怎么用、群聊里怎么收敛。

重启 bot，发语音消息试。

## 装（Windows PowerShell）

```powershell
cd 2-voice-bridge
python -m venv .venv
.venv\Scripts\pip install -r requirements.txt

copy .env.example .env
notepad .env

# 没有 start.sh，前台跑（或者用 Start-Process 后台）
.venv\Scripts\python.exe server_http.py
```

补丁脚本和 sync_snippet 一样跑：

```powershell
.venv\Scripts\python.exe apply_patch.py "$env:USERPROFILE\.claude\plugins\marketplaces\claude-plugins-official\external_plugins\telegram\server.ts"
.venv\Scripts\python.exe sync_snippet.py "$env:USERPROFILE\.claude\<bot 名>\CLAUDE.md"
```

`mcp-snippet.json` 路径换成 Windows 绝对路径（注意双反斜杠）：

```json
"command": "C:\\Users\\yourname\\claude-tg-patch\\2-voice-bridge\\.venv\\Scripts\\python.exe",
"args": ["C:\\Users\\yourname\\claude-tg-patch\\2-voice-bridge\\server.py"]
```

## 调用例子

```json
// 普通语音
{ "chat_id": "...", "text": "今天好累呀。", "as_voice": true }

// 带情绪
{ "chat_id": "...", "text": "[叹气] 又加班。", "as_voice": true, "voice_emotion": "SAD" }

// 双语：中文文字 + 日文语音
{
  "chat_id": "...",
  "text": "今天好累呀。",
  "voice_text": "今日はとても疲れたよ。",
  "as_voice": true
}
```

bot 的 CLAUDE.md 已经被 sync_snippet 注入了规则，多数情况下 claude 自己会判断。手动控制看 `CLAUDE-voice-reply-snippet.md`。

## 不工作怎么办

`start.sh: Permission denied` → `chmod +x start.sh`。

`.venv/bin/python: No such file` → 没建 venv。

`/health` 不通 → 看 `logs/http_server.out`，多半是 funasr 模型还在下或下载失败。墙内可以加 `HTTPS_PROXY` 走代理，或者从 ModelScope 手动下到 `models/`。

`as_voice=true` 没反应 → access.json 没 voiceId / .mcp.json 没注册 voice-bridge / bot 没重启。

`apply_patch.py` 跑完语音功能没动 → 上游 plugin 升级了，可能要手改 patch 里的 selector。

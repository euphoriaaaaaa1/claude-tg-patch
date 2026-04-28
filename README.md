# Claude TG Patch

给 [Claude Code](https://docs.claude.com/en/docs/claude-code) 官方 telegram plugin 加三个东西：消息拆段、收发语音、生图发图。

写出来是因为我自己用了几个月觉得还行，洗掉私人内容后开源出来。原本是给三个 bot 拼起来的本地小系统，单机自用工程，没做 multi-tenant 也没 CI。

---

## 三个模块各干啥

**[1-message-split](./1-message-split/)**
官方 plugin 默认一条 reply 发一整段，长得很像机器人。这个 patch 让 claude 用空行分段，发出来变成多条独立短消息，中间还能插"对方正在输入..."。装完聊起来像真人很多。

**[2-voice-bridge](./2-voice-bridge/)**
让 bot 会发语音、能听语音。语音转文字走 SenseVoice 本地推理（带情绪识别），文字转语音走 Fish Audio S2。第一次装要下 ~1GB 模型，之后纯本机调用，只有 TTS 走外网。

**[3-skill-novelai](./3-skill-novelai/)**
让 claude 自己挑场景、调 NovelAI 出图发图。说"自拍一张"它知道用竖屏 832×1216，说"远处录我"它知道用横屏。说"再来一张换个动作"会复用上一张的 seed，房间和床基本不变。

---

## 怎么装

每个模块独立。建议顺序：先 message-split（5 分钟、立刻见效），再 novelai-skill（10 分钟、要先有 NovelAI 账号），最后 voice-bridge（30 分钟、最重）。

懒人版：clone 下来填 5 个 key 跑一行：

```bash
git clone https://github.com/euphoriaaaaaa1/claude-tg-patch.git ~/projects/claude-tg-patch
cd ~/projects/claude-tg-patch

NOVELAI_TOKEN="..." \
FISH_AUDIO_KEY="..." \
FISH_VOICE_ID="..." \
TELEGRAM_BOT_TOKEN="..." \
BOT_NAME="你bot文件夹名" \
bash install.sh
```

`install.sh` 跑完会打印剩下三个手动步骤（access.json / .mcp.json / CLAUDE.md 要怎么改），照着粘贴就行。这三步不能自动是因为它们是你 bot 的私有 JSON 配置，盲覆盖会炸。

mac 和 Linux 直接跑。Windows 用 Git Bash 或 WSL 也能跑同一个脚本。

---

## 几个 key 在哪拿

**Telegram bot token**：你已经在用官方 telegram plugin 的话直接复用现成的；没有的话 Telegram 找 @BotFather 走 `/newbot` 流程拿到。

**Fish Audio**：去 fish.audio 注册，充几刀（S2 按字符计费，1 万字符约 $0.5），右上角 API 生成 key。音色在主页 voice library 试听挑一个，详情页 URL 末段就是 voice_id。

**NovelAI**：国区直接订阅会卡支付，**走某宝买现成账号比较省心**（搜"NovelAI 订阅 / 高级账号"），档位选 Tablet ($15/月) 起步，免费档不能生图。买到账号后登录 https://novelai.net，**怎么找 token 不用死记**——直接问 AI："NovelAI 怎么拿 persistent API token"，AI 会告诉你点哪几个菜单。token 形如 `pst-...`，复制下来填到上面就行。

---

## 跑通之后大概像这样

```
你：在干嘛
bot：在床上躺着       ← 三条独立消息，中间各 600ms
     你呢
     刚还在想你

你：（发了条语音）我有点累
bot：识别成 SAD 情绪 → 回复 + 发了一段语音

你：来张自拍
bot：[NovelAI 出图，自动竖屏 832×1216]

你：再来一张换个角度
bot：同一个房间和床，只换姿势
```

---

## 已知坑

官方 telegram plugin 升级时如果改了内部字符串，patch 脚本会打不上——这套是基于 server.ts 的字符串匹配做的，比较脆。出问题就 issue。

Fish Audio 和 NovelAI 都收费，自己买账号。

claude CLI 的 OAuth token 长期续命有自己的坑（worker 进程 env 冻结这一类），不在这个仓库范围内，自己折腾。

License: MIT。

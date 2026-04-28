# Claude TG Patch

# 简介

## 项目用途

为 Claude Code 官方的 [Telegram 插件](https://docs.claude.com/en/docs/claude-code) 增加三项功能：消息分段发送、收发语音消息、由 NovelAI 生成并发送图片。三项功能彼此独立，可按需选装其中一个或多个。

代码源自一个长期运行的本地多 bot 系统，去除私人内容后开源。属单机自用工程，不包含自动化部署或多用户支持。

## 三项功能

**消息分段**（[1-message-split](./1-message-split/)）。官方插件默认每次回复发出一条完整长消息，看起来比较机械。装上本模块后，Claude 在回复中以空行划分段落，插件会将其拆分为多条独立 Telegram 消息逐条发出，段与段之间还能显示"对方正在输入..."提示，更接近真人聊天节奏。

**收发语音**（[2-voice-bridge](./2-voice-bridge/)）。两个方向均支持。

- 收：用户向 bot 发送 Telegram 语音消息时，本地部署的 SenseVoice 模型自动将其转写为中文文字，并附带情绪识别结果（开心、悲伤、愤怒等）一并交给 Claude
- 发：Claude 回复时若标记为语音输出，本地服务会调用 Fish Audio 的语音合成接口生成音频，再通过 Telegram 发回

**画图发图**（[3-skill-novelai](./3-skill-novelai/)）。一个 Claude 用户级技能（skill），让 Claude 在判断用户希望接收图像时，自行选择合适的图片比例（自拍用竖屏、远景用横屏）、撰写英文 prompt、调用 NovelAI 生成图像并发送。续图请求会自动复用上一张的随机种子（seed），使房间陈设、灯光等保持一致。

# 安装

## 前置要求

- 已安装 Claude Code 命令行工具，并完成登录（`claude /login`）
- 已部署官方 Telegram 插件，bot 能正常收发文字消息
- 系统已安装 Python（3.10 或以上版本）和 Bun
- 操作系统：macOS、Linux 或 Windows 均可

## 准备 API 密钥

按照所选模块的不同，需要预先获取相应的密钥（API key），用于调用第三方服务。

**Telegram bot token**。已在使用官方 Telegram 插件的话，沿用现有 token 即可。否则在 Telegram 中搜索 [@BotFather](https://t.me/BotFather)，向其发送 `/newbot` 命令，按引导创建 bot，最后会获得形如 `1234567890:AAH...` 的 token，请妥善保存。

**Fish Audio 密钥与音色 id**（仅"收发语音"模块需要）。访问 [fish.audio](https://fish.audio) 注册账号并完成充值（按合成的字符数计费，几美元可用很久）。在右上角菜单进入 API 页面，生成密钥并保存。在主页 voice library 中试听并选定一个音色，详情页 URL 末段即为音色 id（例如 `https://fish.audio/m/<这一段就是音色 id>`），同样保存。

**NovelAI 账号与密钥**（仅"画图"模块需要）。NovelAI 官方支付渠道在国内使用受限，建议在淘宝（即"某宝"）搜索"NovelAI 订阅"或"NovelAI 高级账号"购买现成账号。订阅档位需为 Tablet（每月 15 美元）或更高，免费档位不提供图像生成。Tablet 档每月可生成约 100 至 150 张图。

获得账号后登录 [novelai.net](https://novelai.net)，需要在 Account 设置中获取持久 API 密钥（persistent API token）。**具体点击路径直接询问淘宝商家即可**——卖你账号的商家有现成的图文步骤。最终拿到的密钥形如 `pst-...`，保存留存。

## 一键安装

将上述密钥填入命令对应位置后，在终端中执行：

```bash
git clone https://github.com/euphoriaaaaaa1/claude-tg-patch.git ~/projects/claude-tg-patch
cd ~/projects/claude-tg-patch

NOVELAI_TOKEN="pst-..." \
FISH_AUDIO_KEY="fa-..." \
FISH_VOICE_ID="..." \
TELEGRAM_BOT_TOKEN="..." \
BOT_NAME="你 bot 在 ~/.claude/channels/ 下的目录名" \
bash install.sh
```

`BOT_NAME` 填写 bot 配置目录的名字。例如 bot 的配置文件位于 `~/.claude/channels/bot2/`，则填 `bot2`。

脚本会自动完成的事项：

- 为官方 Telegram 插件应用补丁（添加分段发送和语音参数支持）
- 在系统中安装"画图"技能并写入 NovelAI 密钥
- 创建独立的 Python 环境（不会影响系统 Python），下载语音识别模型（约 1GB，首次较慢）
- 启动本地语音服务
- 在 bot 的 `CLAUDE.md` 末尾追加相关使用规则（仅追加，不修改原有内容）

## 仍需手动完成的步骤

部分配置涉及对 bot 已有 JSON 文件的合并，自动处理可能覆盖你已写过的内容，因此需要手动操作。脚本结束时会精确打印待粘贴的内容。

1. 在 bot 的 `access.json` 中追加几个配置字段（控制分段开关、语音音色等）
2. 在 bot 的 `.mcp.json` 中追加一段 MCP 服务配置（MCP 是 Claude 调用外部工具的标准协议，这里登记的是本地语音服务的位置）

按打印提示复制粘贴即可。改完重启 bot（结束其进程令其自动重启）使配置生效。

# 使用

## 装完之后的对话效果

```
你：在干嘛
bot：在床上躺着            ← 三条独立消息，段间停顿约 600 毫秒
     你呢
     刚还在想你

你：（发语音）我有点累
bot：识别为 SAD 情绪 → 安慰回复 + 同时以语音形式发出

你：来张自拍
bot：自动选择竖屏 832×1216，调用 NovelAI 生成图像并发送

你：再来一张换个角度
bot：保留同一房间和床，仅替换姿态
```

## 各模块详细说明

每个模块在自己的目录下有独立 README，覆盖手动安装、参数调整、故障排查等：

- [1-message-split/README.md](./1-message-split/README.md)
- [2-voice-bridge/README.md](./2-voice-bridge/README.md)
- [3-skill-novelai/README.md](./3-skill-novelai/README.md)

## 已知限制

官方 Telegram 插件如果发布大版本更新，本仓库的补丁脚本可能失效——补丁通过匹配源代码中的字符串实现，对官方版本敏感。遇此情况欢迎在 issue 中反馈或自行修改脚本中的匹配位置。

Fish Audio 与 NovelAI 均为收费服务，账号与额度需自行准备。

Claude Code 自身的登录凭证长期续期问题（运行一段时间后突然 401 之类）不在本仓库覆盖范围内。

# 开源协议

本项目采用 [MIT 协议](./LICENSE)。简言之：可任意使用、修改、分发，作者不对使用结果负责。

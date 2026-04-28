# Claude TG Patch

# 简介

## 项目概述

本仓库为 [Claude Code](https://docs.claude.com/en/docs/claude-code) 官方的 telegram plugin 提供三项扩展，分别处理消息分段发送、语音的双向收发，以及由 NovelAI 完成的图像生成与发送。三个模块相互独立，可按需启用其中任意一个或多个。

代码源自一个长期运行于本地的 Telegram 多 bot 系统，剔除私有人设、密钥与路径后开源。本项目为单机自用工程，不包含自动化部署、多租户支持与持续集成。

## 模块组成

- **[1-message-split](./1-message-split/)** —— 在官方 reply 工具的回复链路中插入分段逻辑：claude 在文本中以空行划分段落，server 据此拆分为多条独立 Telegram 消息逐条发出，段间可加入"对方正在输入..."提示，模拟自然的对话节奏。

- **[2-voice-bridge](./2-voice-bridge/)** —— 提供语音消息的双向桥接。入站方向调用本地部署的 SenseVoice 模型完成语音转文字（含情绪识别），出站方向调用 Fish Audio S2 接口完成文字转语音。

- **[3-skill-novelai](./3-skill-novelai/)** —— 一个 Claude Code 用户级 skill。claude 在判断用户希望接收图像时，自行选择图片比例、撰写英文 prompt、调用 NovelAI 生成图像并通过 Telegram 发送。续图请求会自动复用上一张的 seed，以保持场景一致性。

# 安装

## 环境要求

- 已安装 Claude Code CLI 并完成登录（`claude /login`）
- 已部署官方 telegram plugin 且能正常收发文本消息
- Python 3.10 或以上版本
- Bun（telegram plugin 自身依赖）
- 操作系统：macOS、Linux 或 Windows（Windows 建议使用 Git Bash 或 WSL）

## 凭证准备

根据所启用模块的不同，需要预先获取相应的 API 凭证。

**Telegram bot token**。若已运行官方 telegram plugin，沿用现有 token 即可；否则在 Telegram 中向 [@BotFather](https://t.me/BotFather) 发送 `/newbot` 命令，按引导创建 bot 并保存返回的 token。

**Fish Audio API key 与音色 id**（仅 voice-bridge 需要）。访问 [fish.audio](https://fish.audio) 完成注册并充值，S2 模型按字符计费。在右上角菜单进入 API 页面生成 key。音色在主页 voice library 选择，详情页 URL 末段即为音色 id。

**NovelAI 凭证**（仅 novelai-skill 需要）。NovelAI 官方支付渠道在国内使用受限，建议在某宝（淘宝）搜索"NovelAI 订阅"或类似关键词购买现成账号，订阅档位需为 Tablet（$15/月）或更高。

获得账号后登录 [novelai.net](https://novelai.net) 即可获取 persistent API token。具体操作步骤无需查阅文档——直接询问任意 AI 助手"NovelAI 怎么获取 persistent API token"，对方会指明 Account 页面下的相应入口。token 形如 `pst-...`，复制留存。

## 一键脚本

将上述凭证填入命令对应位置后执行：

```bash
git clone https://github.com/euphoriaaaaaa1/claude-tg-patch.git ~/projects/claude-tg-patch
cd ~/projects/claude-tg-patch

NOVELAI_TOKEN="pst-..." \
FISH_AUDIO_KEY="fa-..." \
FISH_VOICE_ID="..." \
TELEGRAM_BOT_TOKEN="..." \
BOT_NAME="你 bot 在 ~/.claude/ 下的目录名" \
bash install.sh
```

脚本依次完成：补丁打入 telegram plugin、novelai-skill 拷贝至用户级 skill 目录并写入凭证、voice-bridge 创建 Python 虚拟环境并启动 HTTP 服务（首次运行下载 SenseVoice 模型约 1GB）。

## 手动步骤

以下三项配置涉及对用户已有 JSON 文件的合并，自动化处理可能造成既有内容丢失，因此需手动完成。脚本结束时会按当前路径精确打印待粘贴的内容。

1. 在 bot 的 `access.json` 中追加 `splitOnParagraph`、`paragraphDelay`、`voiceId` 三个字段。
2. 在 bot 的 `.mcp.json` 中合并 voice-bridge 的 MCP server 注册项。
3. 在 bot 的 `CLAUDE.md` 末尾追加发图与语音相关的提示词。

完成上述配置后重启 bot 即可生效。

# 使用

## 模块协同效果

三个模块同时启用后，Telegram 端的对话表现示例如下。

```
用户：在干嘛
bot ：在床上躺着            ← 三条独立消息，段间停顿约 600ms
      你呢
      刚还在想你

用户：（语音）我有点累
bot ：识别为 SAD 情绪 → 生成回复并以语音形式发出

用户：来张自拍
bot ：自动选择 portrait 比例（832×1216），调用 NovelAI 生成图像并发送

用户：再来一张换个角度
bot ：复用上一张 seed，保持房间与光照一致，仅替换姿态
```

## 模块详细说明

各模块的调用方式、参数说明、调试技巧详见对应目录下的 README。

- [1-message-split/README.md](./1-message-split/README.md)
- [2-voice-bridge/README.md](./2-voice-bridge/README.md)
- [3-skill-novelai/README.md](./3-skill-novelai/README.md)

## 已知限制

官方 telegram plugin 升级时若内部字符串发生变更，本仓库的 patch 脚本可能失效。该 patch 基于 server.ts 的字符串匹配，对上游版本敏感。如遇此情况，欢迎在 issue 中反馈或提交修复。

Fish Audio 与 NovelAI 均为收费服务，账号与额度需自行准备。

claude CLI 的 OAuth token 长期续期问题（worker 进程环境变量冻结导致的 401 等情形）超出本仓库范围，需另行解决。

# 开源协议

本项目采用 [MIT License](./LICENSE)。详见 LICENSE 文件。

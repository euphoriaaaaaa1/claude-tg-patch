# 3. 画图发图

# 简介

## 功能说明

让 Claude 调用 [NovelAI](https://novelai.net) 生成图片并通过 Telegram 发送。本模块提供一个 Claude 用户级技能（"skill"——Claude 的可复用工具包），装上后 Claude 在判断用户希望接收图像时会自动调用它。

## 三项核心能力

**自动选择图片比例**。根据用户的措辞，Claude 自行从四种预设中挑选合适的尺寸：

- 自拍 / 全身 / 竖屏构图 → portrait（832×1216）
- 远景 / 横屏构图 → landscape（1216×832）
- 特写 / 头像 → square（1024×1024）
- 横躺全身 / 极宽景 → wide（1536×640）

**续图保持一致性**。当用户说"再来一张"、"换个动作"等续图请求时，技能会自动复用上一次生成所用的随机种子（seed，可理解为"画面起点"）。同一个 seed 加上相似的 prompt，能让画面里的房间陈设、灯光、构图保持稳定，仅替换姿态或表情。

**内容评级控制**。`detect_nsfw` 函数根据 `intermediate.json` 中的 `nsfw` 或 `rating` 字段判断是否启用成人内容前缀。默认关键词检测列表为空，需要时可在 `prompt_builder.py` 中自行填入。

# 安装

## 准备 NovelAI 账号与密钥

获得账号后登录 [novelai.net](https://novelai.net)，需要在 Account 设置中获取持久 API 密钥（persistent API token）。**具体点击路径直接询问淘宝商家即可**——卖你账号的商家有现成的图文步骤。最终拿到的密钥形如 `pst-...`。

## 操作步骤

### macOS / Linux

将技能整体复制到 Claude 的用户级技能目录：

```bash
mkdir -p ~/.claude/skills
cp -r 3-skill-novelai ~/.claude/skills/novelai-skill
cd ~/.claude/skills/novelai-skill
cp .env.example .env.local
nano .env.local      # 填入 NOVELAI_BEARER_TOKEN
```

### Windows / PowerShell

```powershell
$skillDir = "$env:USERPROFILE\.claude\skills"
New-Item -ItemType Directory -Force $skillDir | Out-Null
Copy-Item -Recurse 3-skill-novelai "$skillDir\novelai-skill"
cd "$skillDir\novelai-skill"
copy .env.example .env.local
notepad .env.local
```

Claude 命令行工具在启动时会自动扫描 `~/.claude/skills/` 目录，无需手动注册。

### 让 bot 知道使用本技能

通过项目根目录的 `install.sh` 一键安装时，本步骤已自动完成（追加至 bot 的 `CLAUDE.md`，仅追加不修改原有内容）。

如选择手动安装，将 [`CLAUDE-snippet.md`](./CLAUDE-snippet.md) 中的内容整段复制至 bot 的 `CLAUDE.md` 末尾即可，路径为 `~/.claude/channels/<bot 名>/CLAUDE.md`。该片段约束 Claude 在何时调用、传什么参数、如何处理续图请求等。

Windows 的对应路径为 `%USERPROFILE%\.claude\skills\novelai-skill`，命令使用 `python` 而非 `python3`。

## 风格定制（强烈建议）

`assets/default_config.json` 中的 `positive_prefix` 字段控制全局风格前缀。出厂配置仅包含基础质量词，生成结果较为平淡。建议追加几个 NovelAI v4.5 支持的艺术家标签，使画风更鲜明：

```json
"positive_prefix": "5::best quality, masterpiece, very aesthetic, detailed::, 1.5::artist:艺术家A::, 1.2::artist:艺术家B::, year 2025"
```

具体艺术家选择可参考 NovelAI 官方支持列表，或询问 AI 助手获取常用组合（如 kantoku、wlop、redjuice 等）。权重数值取值范围 0.5 至 2.0。

如需固定特定角色的外貌（即"角色锚点"），可参阅 NovelAI 文档中的 character anchor 与 character LoRA 用法。

# 使用

## Claude 内部调用方式

技能通过命令行脚本调用 NovelAI API。Claude 会按以下形式构造命令：

**新场景（首次或场景变更）**

```bash
python3 ~/.claude/skills/novelai-skill/scripts/generate_novelai_image.py \
  --intermediate /tmp/agent1/intermediate.json \
  --config ~/.claude/skills/novelai-skill/assets/default_config.json \
  --ratio portrait \
  --agent-name agent1 \
  --session-name <chat_id>
```

`intermediate.json` 内容示例：

```json
{ "prompt": "1girl, sitting in cafe, warm window light, 1.2::smiling::" }
```

**续图（保持场景一致性）**

在新场景命令基础上添加 `--reuse-seed`，并修改 `intermediate.json`：

```json
{ "mode": "revise", "revision_instruction": "looking at camera, hand near chin" }
```

技能会自动沿用上一次的 prompt 主体，并将 `revision_instruction` 追加至末尾。

## prompt 撰写规范

详见 `SKILL.md`。要点摘录：

- 使用英文 booru 风格 tag（即用下划线连接的简短词组），不使用中文
- 按"画面简述 → 角色 → 服装 → 表情动作 → 环境 → 镜头"的层次组织
- 不重复 `positive_prefix` 中已有的内容
- 不写负面词（由 `negative_prefix` 自动拼接）

## 故障排查

**HTTP 401 Unauthorized**。密钥错误或过期，重新生成。

**HTTP 429 或额度报警**。账号在其他位置同时生图，或 Anlas 额度已耗尽。前者脚本会自动重试 3 次，后者需等待下月或升级订阅。

**图像风格平淡**。`positive_prefix` 中未追加艺术家标签，请参考"风格定制"小节。

**续图房间仍发生变化**。检查 Claude 是否实际传入 `--reuse-seed` 参数（看脚本调用日志）。上一次生成必须成功才能复用其 seed。

**中文 prompt 生成偏差**。NovelAI 是英文模型，prompt 必须使用英文 booru tag。详见 SKILL.md 中的撰写规范。

## 卸载

```bash
# macOS / Linux
rm -rf ~/.claude/skills/novelai-skill

# Windows / PowerShell
Remove-Item -Recurse -Force "$env:USERPROFILE\.claude\skills\novelai-skill"
```

# 开源协议

本模块作为 [Claude TG Patch](../) 的一部分发布，采用 [MIT 协议](../LICENSE)。

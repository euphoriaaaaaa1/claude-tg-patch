# 3. NovelAI Skill

# 简介

## 功能说明

一个 Claude Code 用户级 skill。装载后，claude 在判断用户希望接收图像时，自行完成英文 prompt 撰写、调用本仓库提供的脚本生成图像，并通过 Telegram 发送至当前会话。

## 核心特性

**场景感知的尺寸选择**。skill 暴露 `--ratio` 参数与四种预设：portrait（832×1216，自拍/全身/竖屏构图）、landscape（1216×832，远景/横屏构图）、square（1024×1024，特写/默认）、wide（1536×640，宽景）。claude 根据用户措辞自动选择，无需手动指定。

**续图一致性**。当用户表达"再来一张"、"换个动作"等续图意图时，skill 通过 `--reuse-seed` 参数复用上一次生成所用的 seed，并在 prompt 层面沿用上一次的环境描述，使房间陈设、灯光、构图保持稳定。

**显式触发的内容评级**。`detect_nsfw` 函数根据 intermediate.json 中的 `nsfw` 或 `rating` 字段判定，默认关键词列表为空。如需启用关键词自动检测，可在 `prompt_builder.py` 中填入。

# 安装

## 凭证准备

NovelAI 官方支付渠道在国内可能无法直接订阅，建议在某宝（淘宝）搜索"NovelAI 订阅"或类似关键词购买现成账号。订阅档位需为 Tablet（$15/月）或更高，免费档位不提供图像生成。Tablet 档每月提供 1000 Anlas，约可生成 100 至 150 张图。

获得账号后登录 [novelai.net](https://novelai.net)，**获取 persistent API token 的具体路径无需另行查阅文档**，直接询问任意 AI 助手"NovelAI 怎么获取 persistent API token"，对方会指明 Account 设置中的相应入口。token 形如 `pst-...`。

## 操作步骤

### macOS / Linux

```bash
mkdir -p ~/.claude/skills
cp -r 3-skill-novelai ~/.claude/skills/novelai-skill
cd ~/.claude/skills/novelai-skill
cp .env.example .env.local
nano .env.local       # 填入 NOVELAI_BEARER_TOKEN
```

### Windows PowerShell

```powershell
$skillDir = "$env:USERPROFILE\.claude\skills"
New-Item -ItemType Directory -Force $skillDir | Out-Null
Copy-Item -Recurse 3-skill-novelai "$skillDir\novelai-skill"
cd "$skillDir\novelai-skill"
copy .env.example .env.local
notepad .env.local
```

Claude CLI 在启动时自动扫描 `~/.claude/skills/` 目录，无需额外注册。

### 配置 bot 调用

在 bot 的 `CLAUDE.md` 末尾追加调用规则：

```markdown
## 发图
- 用户表达获取图像意图时，调用 ~/.claude/skills/novelai-skill 完成生成
- 必须传入 --ratio：自拍/全身使用 portrait；远景/录像使用 landscape；特写使用 square
- 续图请求（"再来一张"、"换个动作"等）必须传入 --reuse-seed，并在 intermediate.json 中设 mode=revise
- 生成成功后仅发送图像与 1 至 2 句简短回复，不以文字描述代替图像
```

Windows 路径替换为 `%USERPROFILE%\.claude\skills\novelai-skill`，命令使用 `python` 而非 `python3`。

## 风格定制

`assets/default_config.json` 中的 `positive_prefix` 字段控制全局风格前缀。出厂值仅包含基础质量词，生成结果偏淡。建议追加 NovelAI v4.5 支持的艺术家标签：

```json
"positive_prefix": "5::best quality, masterpiece, very aesthetic, detailed::, 1.5::artist:艺术家A::, 1.2::artist:艺术家B::, year 2025"
```

具体艺术家选取可参考 NovelAI 官方支持列表，或询问 AI 助手获取常用组合（kantoku、wlop、redjuice 等）。权重数值取值范围 0.5 至 2.0。

如需锁定特定角色，参考 NovelAI 文档中的 character anchor 与 character LoRA 用法。

# 使用

## 调用方式

claude 内部按以下形式调用脚本：

**新场景（首次或场景变更）**

```bash
python3 ~/.claude/skills/novelai-skill/scripts/generate_novelai_image.py \
  --intermediate /tmp/agent1/intermediate.json \
  --config ~/.claude/skills/novelai-skill/assets/default_config.json \
  --ratio portrait \
  --agent-name agent1 \
  --session-name <chat_id>
```

intermediate.json 内容：

```json
{ "prompt": "1girl, sitting in cafe, warm window light, 1.2::smiling::" }
```

**续图（保持场景一致性）**

在新场景命令基础上添加 `--reuse-seed`，并修改 intermediate.json：

```json
{ "mode": "revise", "revision_instruction": "looking at camera, hand near chin" }
```

skill 会自动沿用上一次的 prompt 主体，并在末尾追加 `revision_instruction`。

## prompt 撰写规范

详见 `SKILL.md`。要点：使用英文 booru 风格 tag、按"画面简述 + 角色 + 服装 + 表情动作 + 环境 + 镜头"的层次组织、不重复 positive_prefix 中已有的内容、不写负面词。

## 故障排查

**HTTP 401**。token 错误或已过期，重新生成。

**HTTP 429 或额度报警**。账号在其他位置同时生成图像，或 Anlas 已用尽。前者会自动重试 3 次，后者需等待下月或升级订阅。

**生成结果风格平淡**。`positive_prefix` 未追加艺术家标签，参考"风格定制"小节。

**续图房间仍发生变化**。检查 claude 是否实际传入 `--reuse-seed` 参数；上一次生成必须成功才能复用 seed。

**中文 prompt 生成偏差**。NovelAI 为英文模型，prompt 必须使用英文 booru tag，参考 SKILL.md 中的撰写规范。

## 卸载

```bash
# macOS / Linux
rm -rf ~/.claude/skills/novelai-skill

# Windows PowerShell
Remove-Item -Recurse -Force "$env:USERPROFILE\.claude\skills\novelai-skill"
```

# 开源协议

本模块作为 [Claude TG Patch](../) 的一部分发布，采用 [MIT License](../LICENSE)。

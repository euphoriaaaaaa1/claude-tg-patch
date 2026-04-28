# 3. NovelAI Skill

让 claude 调 NovelAI 出图发图。

## 干啥的

claude 用户级 skill。装好之后，用户在 Telegram 跟 bot 说"自拍一张"，claude 自己写 prompt、调脚本、出图、发回聊天。

会自动按场景挑尺寸：自拍/全身用竖图 832×1216，远景/录像用横图 1216×832，特写用方图 1024×1024。

会自动锁 seed：用户说"再来一张换个动作"时，复用上一张的 seed，房间和床基本不变，只换动作。

## 拿 NovelAI 账号和 token

国区直接 NovelAI 官网订阅会卡支付。**走某宝买现成账号比较省心**——搜"NovelAI 订阅" / "NovelAI 高级账号"那种，档位至少 Tablet ($15/月)，免费档不能生图。Tablet 给 1000 Anlas/月，约够生 100-150 张图。

账号买到手后登录 https://novelai.net，**怎么找 persistent API token 不用查教程**——直接问 AI："NovelAI 怎么拿 persistent API token"，AI 会告诉你点 Account 哪个菜单。token 形如 `pst-...`，复制下来。

## 装

```bash
# mac / Linux
mkdir -p ~/.claude/skills
cp -r 3-skill-novelai ~/.claude/skills/novelai-skill
cd ~/.claude/skills/novelai-skill
cp .env.example .env.local
nano .env.local        # 填 NOVELAI_BEARER_TOKEN
```

```powershell
# Windows
$skillDir = "$env:USERPROFILE\.claude\skills"
New-Item -ItemType Directory -Force $skillDir | Out-Null
Copy-Item -Recurse 3-skill-novelai "$skillDir\novelai-skill"
cd "$skillDir\novelai-skill"
copy .env.example .env.local
notepad .env.local
```

claude CLI 启动时自动扫 `~/.claude/skills/`，不用注册。

## 让 bot 用它

bot 的 CLAUDE.md 末尾加一段：

```markdown
## 发图
- 用户要图（自拍 / 照片 / 来一张...），调 ~/.claude/skills/novelai-skill 出图
- 必传 --ratio：自拍/全身用 portrait，远景用 landscape，特写用 square
- 续图（"再来一张" / "换个动作"）必传 --reuse-seed，intermediate.json 里设 mode=revise
- 生图成功后只发图 + 1-2 句简短回复，不要文字描述代替发图
```

Windows 用户路径换成 `%USERPROFILE%\.claude\skills\novelai-skill`，命令用 `python` 不是 `python3`。

## 调风格（强烈建议）

`assets/default_config.json` 的 `positive_prefix` 现在只有基础质量词，出图风格寡淡。要好看必须自己加艺术家。

打开那个 json，改成类似：

```json
"positive_prefix": "5::best quality, masterpiece, very aesthetic, detailed::, 1.5::artist:你喜欢的艺术家::, 1.2::artist:第二个::, year 2025"
```

NovelAI v4.5 支持的艺术家清单官网有，也可以问 AI 让它推荐几个常用的（kantoku、wlop、redjuice 那一类）。数字是权重，0.5-2.0 之间。

想锁角色看 NovelAI 文档里的 character anchor / character LoRA 用法。

## 怎么调用（claude 内部跑的命令）

```bash
# 新场景
python3 ~/.claude/skills/novelai-skill/scripts/generate_novelai_image.py \
  --intermediate /tmp/agent1/intermediate.json \
  --config ~/.claude/skills/novelai-skill/assets/default_config.json \
  --ratio portrait \
  --agent-name agent1 \
  --session-name <chat_id>

# 续图（保持房间一致）
python3 ~/.claude/skills/novelai-skill/scripts/generate_novelai_image.py \
  --intermediate /tmp/agent1/intermediate.json \
  --config ~/.claude/skills/novelai-skill/assets/default_config.json \
  --ratio portrait \
  --reuse-seed \
  --agent-name agent1 \
  --session-name <chat_id>
```

intermediate.json 长这样：

```json
// 新场景
{ "prompt": "1girl, sitting in cafe, warm window light, 1.2::smiling::" }

// 续图
{ "mode": "revise", "revision_instruction": "looking at camera, hand near chin" }
```

claude 自己写 prompt，按 SKILL.md 里的规范走（英文 booru tag、有层次、不重复 prefix 那些）。

## 不工作怎么办

报 401 → token 错或过期，重新生成。

报 429 / quota → 你账号在别处也在生图，或者 Anlas 用光了，等下个月。

出图风格寡淡 → 默认 prefix 没艺术家，看上面"调风格"。

续图房间还是变 → 看看 claude 是不是真传了 `--reuse-seed`；上一张要先成功才能复用 seed。

中文 prompt 出图歪 → NovelAI 是英文模型，prompt 必须英文 booru tag。SKILL.md 里有写法规范。

## 卸

```bash
rm -rf ~/.claude/skills/novelai-skill
```

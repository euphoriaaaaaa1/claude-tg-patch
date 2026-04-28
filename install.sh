#!/usr/bin/env bash
# 一键安装脚本：装好三个模块 + 填好 .env / .env.local。
# 仅自动化能自动化的部分；access.json 和 .mcp.json 因为是你 bot 私有配置，
# 需要你自己合并（脚本最后会打印精确指令）。
#
# 用法：
#   1. 编辑下面的 USER CONFIG 段，填进 4 个 key + 1 个 bot 名
#   2. 跑 bash install.sh
#
# macOS / Linux 通用。Windows 用 Git Bash 或 WSL 跑同一脚本即可。

set -euo pipefail

# ═══════════════════════ USER CONFIG（只改这一段） ═══════════════════════

# ── 必填（如果你装对应模块）──
NOVELAI_TOKEN=""           # NovelAI 持久 token，从 novelai.net Account → Get Persistent API Token
FISH_AUDIO_KEY=""          # Fish Audio API key，fish.audio → API → Generate Key
FISH_VOICE_ID=""           # 你在 fish.audio 选好的音色 id（详情页 URL 末段）
TELEGRAM_BOT_TOKEN=""      # @BotFather 给的 1234567890:AA... 形式 token
BOT_NAME=""                # 你 bot 在 ~/.claude/ 下的目录名，如 mybot

# ── 可选（一般不用改）──
TELEGRAM_PLUGIN_DIR="$HOME/.claude/plugins/marketplaces/claude-plugins-official/external_plugins/telegram"

# ── 装哪些模块（true / false）──
INSTALL_MESSAGE_SPLIT=true
INSTALL_NOVELAI=true
INSTALL_VOICE_BRIDGE=true   # ⚠️ 第一次装会下 ~1GB SenseVoice 模型，慢

# ═════════════════════════════════════════════════════════════════════════
# 下面别动

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
say() { printf "\033[1;36m▶ %s\033[0m\n" "$*"; }
warn() { printf "\033[1;33m⚠ %s\033[0m\n" "$*"; }
ok() { printf "\033[1;32m✓ %s\033[0m\n" "$*"; }
fail() { printf "\033[1;31m✗ %s\033[0m\n" "$*"; exit 1; }

# 校验
[ -z "$BOT_NAME" ] && fail "BOT_NAME 必填（你 bot 在 ~/.claude/ 下的目录名）"
[ ! -f "$TELEGRAM_PLUGIN_DIR/server.ts" ] && \
  fail "找不到 telegram plugin server.ts: $TELEGRAM_PLUGIN_DIR/server.ts。装好官方 telegram plugin 再来"
BOT_DIR="$HOME/.claude/$BOT_NAME"
[ ! -d "$BOT_DIR" ] && warn "$BOT_DIR 不存在，等下打印的"下一步"步骤需要你确认 bot 目录在哪"

# ─── 模块 1: message-split ──────────────────────────────────────────────
if [ "$INSTALL_MESSAGE_SPLIT" = true ]; then
  say "[1/3] message-split"
  python3 "$REPO_DIR/1-message-split/apply.py" "$TELEGRAM_PLUGIN_DIR/server.ts"
  ok "patch 已应用到 telegram plugin"
fi

# ─── 模块 3: novelai-skill ──────────────────────────────────────────────
if [ "$INSTALL_NOVELAI" = true ]; then
  say "[2/3] novelai-skill"
  [ -z "$NOVELAI_TOKEN" ] && fail "NOVELAI_TOKEN 没填"
  mkdir -p "$HOME/.claude/skills"
  rm -rf "$HOME/.claude/skills/novelai-skill"
  cp -r "$REPO_DIR/3-skill-novelai" "$HOME/.claude/skills/novelai-skill"
  cat > "$HOME/.claude/skills/novelai-skill/.env.local" <<EOF
NOVELAI_BEARER_TOKEN=$NOVELAI_TOKEN
EOF
  chmod 600 "$HOME/.claude/skills/novelai-skill/.env.local"
  ok "skill 装到 ~/.claude/skills/novelai-skill"
fi

# ─── 模块 2: voice-bridge ──────────────────────────────────────────────
if [ "$INSTALL_VOICE_BRIDGE" = true ]; then
  say "[3/3] voice-bridge"
  [ -z "$FISH_AUDIO_KEY" ] && fail "FISH_AUDIO_KEY 没填"
  [ -z "$TELEGRAM_BOT_TOKEN" ] && fail "TELEGRAM_BOT_TOKEN 没填"
  cd "$REPO_DIR/2-voice-bridge"
  if [ ! -d .venv ]; then
    say "建 Python venv（首次）"
    python3 -m venv .venv
  fi
  say "装依赖（可能要几分钟，torch 和 funasr 大）"
  .venv/bin/pip install -q -r requirements.txt
  cat > .env <<EOF
FISH_AUDIO_API_KEY=$FISH_AUDIO_KEY
TELEGRAM_BOT_TOKEN=$TELEGRAM_BOT_TOKEN
NO_PROXY=127.0.0.1,localhost
EOF
  chmod 600 .env
  say "patch telegram plugin 加 as_voice 参数"
  .venv/bin/python apply_patch.py "$TELEGRAM_PLUGIN_DIR/server.ts"
  say "启动 voice-bridge HTTP 服务（首次会下 SenseVoice 模型 ~1GB）"
  ./start.sh start || warn "启动失败看 logs/http_server.out"

  if [ -d "$BOT_DIR" ] && [ -f "$BOT_DIR/CLAUDE.md" ]; then
    say "同步 CLAUDE.md 提示词"
    .venv/bin/python sync_snippet.py "$BOT_DIR/CLAUDE.md"
  fi
fi

# ─── 收尾：打印手动步骤（不可自动） ─────────────────────────────────────
echo ""
echo "════════════════════════════════════════════════════════════════════"
say "自动部分完成。剩下这些必须你手动改（涉及合并你 bot 已有 JSON 配置）："
echo ""

if [ -n "$BOT_DIR" ]; then
  echo "1. 编辑 $BOT_DIR/access.json 加这几个字段："
  cat <<EOF
   {
     "splitOnParagraph": true,
     "paragraphDelay": 600,
     "voiceId": "$FISH_VOICE_ID"
   }
EOF
  echo ""
  echo "2. 编辑 $BOT_DIR/.mcp.json 把这一段并入 mcpServers："
  cat <<EOF
   {
     "mcpServers": {
       "voice-bridge": {
         "command": "$REPO_DIR/2-voice-bridge/.venv/bin/python",
         "args": ["$REPO_DIR/2-voice-bridge/server.py"],
         "env": {}
       }
     }
   }
EOF
  echo ""
  echo "3. 在 $BOT_DIR/CLAUDE.md 末尾加发图规则（让 claude 用 novelai-skill）："
  echo "   见 ~/.claude/skills/novelai-skill/README.md '让 bot 知道用这个 skill' 段"
  echo ""
  echo "4. 重启你的 bot（kill tmux session 让 dispatcher / claude 重新拉起）"
fi

echo ""
ok "完成。健康检查："
echo "   curl http://127.0.0.1:7788/health    # voice-bridge 应返回 {\"ok\": true}"

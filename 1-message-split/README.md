# 1. Message Split

让 bot 一次回复发多条短消息，不要一整段堆在一起。

## 干啥的

官方 telegram plugin 默认是 claude 写啥就一条消息发啥，长得像 chatbot。打这个 patch 之后，claude 在 reply 里用空行分段，server 自动拆成多条独立 Telegram 消息逐条发，中间还能插"对方正在输入..."。

效果对比：原本

```
[bot] 哦你来啦我刚还在想你呢今天怎么样
```

变成

```
[bot] 哦
[bot] 你来啦
[bot] 我刚还在想你呢
[bot] 今天怎么样
```

聊起来人味浓很多。

## 装

两步。先把官方 plugin 跑通了再来。

**第一步**：跑 patch

```bash
# mac / Linux
python3 1-message-split/apply.py \
  ~/.claude/plugins/marketplaces/claude-plugins-official/external_plugins/telegram/server.ts

# Windows PowerShell
python 1-message-split\apply.py "$env:USERPROFILE\.claude\plugins\marketplaces\claude-plugins-official\external_plugins\telegram\server.ts"
```

会生成同目录的 `server.ts.bak` 备份。脚本幂等可以反复跑。

**第二步**：bot 的 `access.json`（一般在 `~/.claude/<bot 名>/access.json`）加两个字段：

```json
{
  "splitOnParagraph": true,
  "paragraphDelay": 600
}
```

`paragraphDelay` 是段间毫秒等待（期间显示"正在输入..."），400-800 之间随你。设 0 就立即连发。

最后在 bot 的 CLAUDE.md 提醒 claude 怎么写：

```markdown
回复用空行分段，每段 < 30 字，最多 3-5 段，一次 reply 调用发完。
```

重启 bot 就能看到效果。

## 卸

`bash 1-message-split/revert.sh /path/to/server.ts`，或者把 `splitOnParagraph` 改回 false。

## 不工作怎么办

`apply.py` 跑完输出 `no changes (already patched)` 是正常的，已经打过了。

消息还是一整条 → 检查 access.json 有没有写 `splitOnParagraph: true`，bot 重启了没。

报 `error: ... not found` → server.ts 路径写错了。

官方 plugin 升级后 patch 失效 → 上游字符串可能变了，本 patch 是字符串匹配的。提 issue 或者自己改 apply.py 里的 selector。

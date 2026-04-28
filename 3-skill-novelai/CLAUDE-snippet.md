<!-- NOVELAI-SKILL-START · 由 install.sh 注入；删除整段即移除规则 -->

## 发图

用户表达获取图像意图时（自拍、照片、来一张等），调用 `~/.claude/skills/novelai-skill` 完成生成。

调用约束：

- 必须传入 `--ratio`：自拍/全身用 `portrait`；远景/录像用 `landscape`；特写/头像用 `square`；横躺全身或宽景用 `wide`
- 续图请求（"再来一张"/"换个动作"/"换个表情"等）必须传入 `--reuse-seed`，并在 intermediate.json 中设置 `"mode": "revise"`，仅在 `revision_instruction` 字段中描述本次改动
- 用户明确表达切换场景（"去客厅"/"出门"/"换衣服"）时，不传 `--reuse-seed`，重新写完整 prompt
- 生成成功后只发送图像与 1 至 2 句简短回复，不以文字描述代替图像
- prompt 必须使用英文 booru 风格 tag，禁止中文

详细规范见 `~/.claude/skills/novelai-skill/SKILL.md`。

<!-- NOVELAI-SKILL-END -->

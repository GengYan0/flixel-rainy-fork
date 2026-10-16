# P4 — blend 状态切换跳过（设计中，需先验证）

## 动机

`FlxDrawQuadsItem.render()` 每个 batch 都调用 `camera.canvas.graphics.overrideBlendMode(blend)`，blend 为 null 时也调用。
若 openfl 每次都重设 GL 状态，相邻 NORMAL 批次就是纯浪费。

## 不确定性

- openfl 若按 draw call 粒度提交 blend，跳过无收益
- 若有脏标记优化，同样无收益
- 若确实每 call 重设 GL 状态，才值得做，且必须跟踪"上一 batch 是否设过 override"，防止 ADD 泄漏到后续 NORMAL 批次

## 验证

RenderDoc 抓帧：对比连续 NORMAL batch 之间是否存在多余 `glBlendFunc`。
有 → 实现（带 `_blendOverrideActive` 跟踪 + clearDrawStack 重置）；无 → 关闭并记录结论。

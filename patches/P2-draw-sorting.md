# P2 — draw item 排序减少断批（设计中）

## 动机

批合并键是 (graphic, colored, hasColorOffsets, blend, antialiasing, shader)，按 sprite 绘制顺序线性合并：
A 图集 → B 图集 → A 图集 = 3 个 batch。按 atlas 聚类重排可压到 2 个。

## 设计约束

- 只做稳定排序（stable sort），同 atlas 内 item 相对顺序不变，保证层级正确
- 排序键：graphic 指针/id；仅对 TILES 重排，TRIANGLES 保持原位
- 开关化：`FlxCamera.sortDrawItems:Bool`，默认 false，A/B 验证后决定默认值
- 排序在 draw stack 收集阶段做一次/帧，数据量 = batch 数（通常 10-40），插入排序足够

## 验证

A/B 同场景开关对比 `FlxFrameStats.percentileRender` 与 `drawCalls`。
若 render 段占帧时间 < 5%，此 patch 无意义，直接关闭并记录结论。

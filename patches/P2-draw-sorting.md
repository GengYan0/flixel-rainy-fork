# P2 — draw item 排序减少断批（已落地，默认关）

## 动机

批合并键是 (graphic, colored, hasColorOffsets, blend, antialiasing, shader)，按 sprite 绘制顺序线性合并：
A 图集 → B 图集 → A 图集 = 3 个 batch。按 atlas 聚类重排可压到 2 个。

## 设计约束

- 只做稳定排序（stable sort），同 atlas 内 item 相对顺序不变，保证层级正确
- 排序键：graphic 指针/id；仅对 TILES 重排，TRIANGLES 保持原位
- 开关化：`FlxCamera.sortDrawItems:Bool`，默认 false，A/B 验证后决定默认值
- 排序在 draw stack 收集阶段做一次/帧，数据量 = batch 数（通常 10-40），插入排序足够

## 已落地实现（2026-10-18）

`FlxCamera.sortDrawItems`（public static，默认 false）+ `stableSortDrawStack()`：

- 插入排序，batch 数 10-40 时 O(n²) 常数最优
- 只重排 TILES；TRIANGLES 是锚点保持原位
- 同 graphic 稳定序（引用比较，无 id/key 依赖）
- **回看窗口限位 `SORT_LOOKBACK = 8`**：最多往回找 8 项找同类，找不到就保持原位。
  原因：不限窗口时"从不重复的 graphic"会被拉到队首，跨图集层叠关系被大改；
  限窗后视觉扰动被限制在邻近项。
- draw stack 每帧完全重建（FlxCamera 724-725 行先置 null），render 前重排安全
- 每帧分配一个临时 Array（batch 数量级），开了才有、关了零开销

## 验证（仍然要做）

A/B 同场景开关对比 `FlxFrameStats.percentileRender` 与 `drawCalls`。
若 render 段占帧时间 < 5%，此 patch 无意义，保持关闭并记录结论。
开启方式：hscript 或代码里 `flixel.FlxCamera.sortDrawItems = true;`

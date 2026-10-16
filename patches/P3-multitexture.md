# P3 — multi-texture batching（设计中）

## 动机

2D 渲染器减少 draw call 的终极手段：一个 batch 混用多张贴图（Ceramic 4.1 实测每批 8 张，顶点带 textureSlot 属性）。
散图场景 draw call 可从 ~40 压到 ~10。

## 设计

1. `FlxDrawQuadsItem` 扩展：新增 textureSlots（每顶点 1 个 slot 值）
2. 新 shader 变体：8 个 sampler2D + 顶点 slot 属性
3. `startQuadBatch` 合并逻辑：当前 batch 贴图数 < 8 时新贴图进当前 batch，满则 flush
4. 退化保护：仅对默认 shader 生效，自定义 shader 走原路径

## 风险

- shader 分支取纹理在旧 GPU 上有兼容问题（if 链 vs 纹理数组），需目标机型实测
- openfl `drawQuads` 顶点布局固定，textureSlot 需扩展数据布局 —— 这可能需要连 openfl 一起 fork（rainy-openfl 的 drawQuads 扩展就是这个前置）

## 决策门槛

P2 与引擎侧 atlas 合并完成后，render 段仍占帧时间 > 15% 才启动。

# P1 — FlxFrameStats 帧时间统计（基线 v6.2.0）

## 动机

性能优化的第一纪律：先测量，后动刀。没有帧时间分解，所有"优化"都是盲调。
上游只有 `#if FLX_DEBUG` 下的粗粒度 flixelUpdate/flixelDraw 计时，release 构建不可用；
draw call 计数器（`FlxDrawBaseItem.drawCalls`）存在但只在 debug 路径消费。

本 patch 把三段计时 + draw call 统计变成 release 可用、零每帧分配的常驻能力。

## 改动

新增 `flixel/system/FlxFrameStats.hx`；修改 `flixel/FlxGame.hx`（10 处插入，无删除）。

| 字段 / 方法 | 说明 |
|---|---|
| updateMS / drawMS / renderMS / totalMS | 上一帧各段耗时（ms） |
| drawCalls | 上一帧 draw call 数（直通 FlxDrawBaseItem.drawCalls） |
| frameCount | 累计帧数 |
| beginFrame / endFrame(drawCalls) | 帧级包裹，beginFrame 重置累加器 |
| beginUpdate/endUpdate、beginDraw/endDraw、beginRender/endRender | 段级包裹，可重入累加（fixed timestep 一帧多 step 正确求和） |
| percentileUpdate/Draw/Render/Total(p) | 512 帧窗口分位数（p=0.5 即 p50） |
| maxTotal() | 窗口内最大帧时间 |
| enabled | false 时全部调用直通返回 |

分段定义（对齐 FlxGame 主循环）：

| 段 | 覆盖范围 |
|---|---|
| update | updateElapsed + updateInput + preUpdate 信号 + sound/plugins + state.tryUpdate + cameras.update + postUpdate 信号 |
| draw | cameras.lock + plugins.draw + state.draw（CPU 侧提交） |
| render | cameras.render()（draw item 遍历 + drawQuads 下发） |
| total | onEnterFrame 入口到 endFrame |

### FlxGame.hx 插入点（10 处）

1. import `flixel.system.FlxFrameStats`
2. onEnterFrame：`_total = ticks` 之后 `beginFrame()`
3. update()：`switchState` 判断之后 `beginUpdate()`
4. update()：末尾 `endUpdate()`
5. draw()：`cameras.lock()` 之后 `beginDraw()`
6. draw()：state/plugins 绘制之后 `endDraw()`
7. draw()：renderTile 分支内 `cameras.render()` 前后 `beginRender/endRender`
8. draw()：`postDraw` 信号之后 `endFrame(FlxDrawBaseItem.drawCalls)`

## 成本

每帧 6 次 `Lib.getTimer()`（原生调用，百纳秒量级），合计 < 1μs/帧；环形缓冲写入 5 个预建数组槽，零分配。
对 240fps（4.17ms 预算）占比 < 0.03%。

## 验收（先定义失败信号）

| 信号 | 判定 |
|---|---|
| 开启后 totalMS 与关闭时差 > 0.1ms | fail：计时本身成了瓶颈 |
| fixed timestep 下 updateMS 不随 step 次数线性增长 | fail：累加逻辑错误 |
| 512 帧填满后 percentileTotal(0.99) 与 maxTotal 收敛 | pass |
| 切 state / 暂停 / 调试器暂停后统计不错位 | pass |

## 引擎侧接入（rainy.* 命名空间）

F3 覆盖层（250ms 节流刷新，避免每次排序）：

    final p50 = flixel.system.FlxFrameStats.percentileTotal(0.5);
    final p99 = flixel.system.FlxFrameStats.percentileTotal(0.99);
    final mx = flixel.system.FlxFrameStats.maxTotal();
    final dc = flixel.system.FlxFrameStats.drawCalls;

帧率封顶（可配置，不封顶档位）：

    FlxG.drawFramerate = fpsCap;
    FlxG.updateFramerate = 60;

注意：`FlxG.drawFramerate = 0` 时内部 `_maxAccumulation = 2000/0 - 1` 会得到 Infinity（flixel 已知问题），
引擎侧必须保留已有的内部 cap 1000 保护，不要把 0 直接透传。

## 验证状态

- 已完成：10 个插入点与 6.2.0 源码逐行核对；符号引用核对通过
- 未完成：接入引擎后的编译与实机采样（需 `haxelib dev rainy-flixel` 后重建）

# rainy-flixel

HaxeFlixel 6.2.0 的 Rainy 构建。6.2.0 的 API 全部保留，另加帧时间测量、相机渲染节流、
图层合成、文本共享图集、精灵倾斜、图集格式注册和一个恢复的 `FlxTrail`。

haxelib 名仍是 `flixel`，依赖它的库按原名解析。

## 能力一览

| 能力 | 入口 | 默认 |
|---|---|---|
| 帧时间分解 + 百分位 | `FlxFrameStats` | 开 |
| 相机渲染节流 | `FlxCamera.renderInterval` | `1`（不节流） |
| 绘制项按纹理聚类 | `FlxCamera.sortDrawItems` | `false` |
| 图层合成（7 种混合模式） | `FlxCamera.renderLayerBlend()` | 有需求才走 |
| 文本共享图集 | `FlxText.textPager` | `null` |
| 精灵倾斜 | `FlxSprite.skewX` / `skewY` | `0` |
| 图集格式注册 | `FlxAtlasFrames.registerFormat()` | — |
| 拖尾 | `flixel.effects.FlxTrail` | — |

## 安装

```bash
haxelib dev flixel "D:/libs/rainy-flixel"
```

或者从仓库直接装：

```bash
haxelib git flixel https://github.com/GengYan0/flixel-rainy-fork
```

`haxelib git` 会把检出放到 `<haxelib>/git/flixel`。同名库只能装一份，先移除已发行的
`flixel` 版本。

配套的 `openfl` 与 `lime`：

```bash
haxelib git openfl https://github.com/GengYan0/openfl-rainy-fork
haxelib git lime    https://github.com/GengYan0/lime-rainy-fork
```

`extraParams.hxml` 定义了 `rainy_fork_flixel`，需要区分构建时可 `#if rainy_fork_flixel`。

## 1. 帧时间分解

`FlxFrameStats` 把一帧拆成 update / draw / render 三段，并保留 240 帧的滚动窗口算百分位。

| 字段 | 含义 |
|---|---|
| `updateMS` / `drawMS` / `renderMS` | 三段各自的耗时 |
| `totalMS` | 三段之和，只含引擎自身工作 |
| `periodMS` | 墙钟帧间隔，含呈现、驱动与限帧器休眠 |
| `drawCalls` | 本帧绘制调用数，每帧归零 |
| `percentilePeriod(0.99)` 等 | 指定百分位 |

`work 2.2 ms 却只有 170 fps` 这类问题看 `percentilePeriod`，不看 `totalMS`。

```haxe
// 每秒打一行
var acc = 0.0;
override function update(elapsed:Float)
{
	super.update(elapsed);
	acc += elapsed;
	if (acc < 1) return;
	acc = 0;

	trace('period p50=${FlxFrameStats.percentilePeriod(0.5)} p99=${FlxFrameStats.percentilePeriod(0.99)}');
	trace('work total=${FlxFrameStats.totalMS} draw=${FlxFrameStats.drawMS} calls=${FlxFrameStats.drawCalls}');
}
```

`FlxFrameStats.enabled = false` 关掉采集，计时点变成空调用，`drawCalls` 仍然正确归零。

## 2. 相机渲染节流

`renderInterval = N` 让相机每 N 帧渲染一次，其余帧保留上一张图像。

```haxe
var minimap = new FlxCamera();
minimap.renderInterval = 4;
FlxG.cameras.add(minimap, false);
```

`stepRenderDue()` 先推进 tick 再判断，所以 `renderInterval = 2` 的第一帧照常渲染
（先判断后推进会让 tick 0 落到「不是 2 的倍数」上，新相机开局是空白）。

## 3. 绘制项按纹理聚类

按 graphic 引用稳定重排绘制栈，把 `A -> B -> A` 的断批并成一条。

```haxe
FlxCamera.sortDrawItems = true;
```

默认关。它会改变绘制顺序，同 graphic 两次绘制之间夹了别的 graphic 且两者重叠时，遮挡关系
会翻过来。改之前先看 `percentileRender` 占整帧的比例，低于 5% 不值得冒险。

## 4. 图层合成

固定管线表达不了七种混合模式，因为它们需要在同一趟里同时拿到背景和前景两张纹理：
`COLOR_DODGE`、`COLOR_BURN`、`SOFT_LIGHT`、`HUE`、`SATURATION`、`COLOR`、`LUMINOSITY`。

相机遇到这类批次时自动分段：把已提交的内容快照成背景纹理，把该批次渲染成前景纹理，
再发一个全屏四边形采样两者。连续同模式的批次共用一趟，段与段的先后顺序保持不变。
不碰这七种模式的帧走原来的单趟路径，零开销。

```haxe
sprite.blend = BlendMode.SOFT_LIGHT;   // 直接写，相机会处理
```

全局开关：

```haxe
FlxCamera.layerBlendEnabled = false;   // 退回普通 source-over，用于 A/B
trace(FlxCamera.layerBlendUsed);       // 本帧是否真的跑了合成
```

`FlxLayerBlend.needsLayer(blend)` 可以在提交前问一句，`FlxLayerBlend.name(id)` 给调试面板用。

## 5. 文本共享图集

flixel 按 graphic 合批，每个自带位图的 `FlxText` 就是一次独立绘制。三十个 label 就是
三十次调用，而这些文字本可以共处一两张纹理。

`FlxText.textPager` 装一个 pager，文字仍走原来的栅格化路径、像素不变，只是画到哪张纹理
变了。两个入口：

- `find(key)` 在栅格化**之前**问，命中就整趟跳过 `TextField`；
- `store(key, source)` 在栅格化**之后**收到成品位图。

两者都可以返回 null 或拒绝，拒绝只损失内存收益，不影响文字显示。`FlxText` 无论如何
保留自己的画布。

```haxe
class MenuTextPager implements FlxTextPager
{
	var page:BitmapData;
	var frames:FlxFramesCollection;
	var slots = new Map<String, FlxTextPagerSlot>();
	var cursorX = 0;

	public function new(width:Int, height:Int)
	{
		page = new BitmapData(width, height, true, 0x00000000);
		frames = FlxAtlasFrames.fromBitmapAddSpacesAndBorders(FlxG.bitmap.add(page));
	}

	public function find(key:String):FlxTextPagerSlot
		return slots.get(key);

	public function store(key:String, source:BitmapData):FlxTextPagerSlot
	{
		if (cursorX + source.width > page.width) return null;
		page.copyPixels(source, source.rect, new Point(cursorX, 0));
		var frame = frames.addAtlasFrame(cursorX, 0, source.width, source.height, source.rect);
		cursorX += source.width;
		return slots.set(key, {frames: frames, index: frame.name == null ? 0 : 0});
	}
}

FlxText.textPager = new MenuTextPager(2048, 2048);
```

不走共享的 label（`pagerKey()` 返回 null）：带边框或阴影、带 `FlxTextFormat` 区间、含换行。
前三条没法用字符串表达成一个键，换行会随 `fieldWidth` 变。

`detachPager()` 在任何一次像素编辑前把 label 指回自己的画布，改过文字的 label 不会被同页
其他内容擦掉。命中的 label 从来没有本地画布，`oldWidth` 读作 0，直接走「新建 buffer」分支。

## 6. 精灵倾斜

`skewX` / `skewY` 单位是度，在 `prepareComplexMatrix` 里于原点平移与 `scale` 之间求切变。

```haxe
arrow.skewX = 12;    // 上下边保持水平，竖边倾斜
arrow.skewY = -6;
```

顺序有实际后果：放在 `scale` 之后，切变量会按屏幕像素算，非等比缩放的精灵倾角就不对；
放在 `rotateWithTrig` 之后，切变量按屏幕轴算，转过角度的箭头会斜到自己的边外面。

角度钳在 ±80°，正切在 90° 附近发散，再大会把精灵压成一条线。任一轴非零时 `draw()` 跳过
`drawSimple`，切变过的四边形没法 blit。不设 skew 的精灵只多一次比较。

## 7. 图集格式注册

内置 packer 之外的图集布局可以挂进来，内容包自带解析器即可，不用改库。

```haxe
FlxAtlasFrames.registerFormat('my_pack', function(source, description) {
	// description 是图集描述文件解析出来的对象
	var frames = FlxAtlasFrames.findFrame(source, FlxFrameCollectionType.ATLAS);
	var atlas = new FlxAtlasFrames(source);
	for (entry in description.frames)
		atlas.addAtlasFrame(entry.x, entry.y, entry.w, entry.h, entry.rect, entry.name, entry.angle, entry.flipX, entry.flipY);
	return atlas;
});

var atlas = FlxAtlasFrames.fromFormat('my_pack', 'assets/images/ui.png', parsedDescription);
```

`fromFormat` 未注册的名字返回 null，不会抛。

## 8. 拖尾

`FlxTrail` 是 5.x 移除的类，参数保持旧签名，老脚本 `new FlxTrail(sprite, null, 5, 3, 0.4, 1000)`
可以直接用。

```haxe
var trail = new FlxTrail(boyfriend, null, 6, 2, 0.5, 800);
add(trail);

trail.delay = 0.2;      // 过 0.2 秒才开始采样
trail.finish = true;    // 停止采样，已有副本自行淡出
```

## 边界

- `sortDrawItems` 会改绘制顺序，只有确认场景不依赖交叉遮挡时才开。
- 文本图集共享的是纹理，不是字形渲染结果。字体、大小、描边任何一种不同都是不同的键。
- `renderInterval > 1` 的相机上做屏幕空间效果（模糊、扭曲）会以低帧率步进。
- 倾斜是二维切变，不含透视。

改动逐条记录在 `RAINY-FORK.md`。

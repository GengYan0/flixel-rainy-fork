# P5 — 图集格式注册表（可插拔解析器）

## 问题

`FlxAtlasFrames` 的解析入口是硬编码的四个静态方法：
`fromSparrow` / `fromTexturePackerJson` / `fromTexturePackerXml` / `fromAseprite` / `fromLibGdx` /
`fromSpriteSheetPacker`。内容包想用自己的图集布局（自研打包器、加密描述、带附加属性的 JSON），
唯一办法是改引擎源码或改 flixel 本体。

## 改动

`flixel/graphics/frames/FlxAtlasFrames.hx` 顶部新增：

```haxe
typedef AtlasFormatParser = FlxGraphicAsset->Dynamic->FlxAtlasFrames;

static var formatRegistry:Map<String, AtlasFormatParser> = new Map();

public static function registerFormat(name:String, parser:AtlasFormatParser):Void
public static function hasFormat(name:String):Bool
public static function formatNames():Array<String>
public static function fromFormat(name:String, source:FlxGraphicAsset, description:Dynamic):FlxAtlasFrames
public static function clearFormats():Void
```

注册表是纯附加的：不注册任何名字时，行为与上游逐字节一致（没有任何既有调用点被改写）。

## 用法

Haxe 侧：

```haxe
FlxAtlasFrames.registerFormat('mygrid', function(source, description) {
    var frames = new FlxAtlasFrames(FlxGraphic.fromAsset(source));
    // 用自己的布局填 frames...
    return frames;
});
var atlas = FlxAtlasFrames.fromFormat('mygrid', 'images/foo.png', rawJsonOrPath);
```

hscript 侧（引擎已 `set('FlxAtlasFrames', ...)`）：

```haxe
FlxAtlasFrames.registerFormat('mygrid', function(source, description) {
    var frames = new flixel.graphics.frames.FlxAtlasFrames(
        flixel.graphics.FlxGraphic.fromAsset(source));
    return frames;
});
```

## 边界与未做

- `description` 是 `Dynamic`：调用方自己决定传路径字符串、文件内容还是已解析对象。
  注册的解析器必须自己处理"路径 vs 内容"——见引擎侧 `Paths.loadAtlasData` 的既有结论
  （把磁盘路径直接交给 flixel 资产抽象会静默解析成空 XML，然后在 `fromSparrow` 里崩 Null）。
- 未做：按 pack manifest 声明格式（`{"atlasFormat": "mygrid"}`）。那需要改引擎侧
  `Paths.getAtlas/getSparrowAtlas` 的派发链，属于引擎层决策，等格式真正出现再动。
- 未做：帧名冲突策略、注册表持久化。目前是进程内注册，重启后需重新注册。

## 验证

未编译（本轮按约定不跑构建）。改动为纯附加：新增 5 个静态函数 + 1 个 typedef + 1 个静态字段，
未触碰任何既有函数体。`FlxGraphicAsset` 经既有 `import flixel.system.FlxAssets` 可见（它是该模块的 abstract）。

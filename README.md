# rainy-flixel — 自有 flixel fork（6.2.0）

基于 HaxeFlixel/flixel 6.2.0（MIT）的自有 fork，与引擎 `F:\1.0.4\Project.xml` 固定版本一致。
上游：https://github.com/HaxeFlixel/flixel ｜ 上游版权与许可归 HaxeFlixel，fork 保留 MIT。

## 为什么 fork

flixel 6.2.0 上游核心已相当干净（draw item 对象池、矩阵/点位复用、无闭包迭代、内置 draw call 计数器）。
fork 的价值在测量与渲染器扩展，不在重写：

1. **测量**：帧时间分解（P1，已实现）——没有基线就没有优化归因
2. **渲染器扩展**：draw item 排序、多贴图批量（P2/P3）、sprite draw 预算（P4）
3. **稳定基座**：引擎侧（`rainy.*` 命名空间 + packs）需要一个不随上游漂移的 flixel

## 接入（三条硬约束，实测得出）

**1. haxelib 名必须保持 `flixel`，不能改成 `rainy-flixel`。**
`flixel-addons 4.0.2` 与 `haxeui-flixel 1.7.0` 的 haxelib.json 里都写着 `dependencies: { "flixel": "" }`。
一旦本 fork 换个名字，这两个库就会把上游 flixel 一起解析进 classpath，同一份 `flixel.*` 包出现两份定义。
身份用仓库目录名 `rainy-flixel` + description/releasenote 表达，不用 haxelib 名。

**2. haxelib.json 的 `version` 必须是纯 semver（本 fork 填 `6.2.0`）。**
写成 `6.2.0-rainy.1` 时 `haxelib dev` 解析不出，把版本报成 `0.0.0X` →
编译期 define 变成 `-D flixel=0.0.0X` → flixel-addons 的版本闸门
（`flixel/addons/system/macros/FlxAddonDefines.hx` → `FlxDefines.abortVersion`）直接失败，
报 `Type not found : FlxDefines` 与 `Flixel-Addons is not compatible with flixel versions older than 5.3.0`。
实测改成 `6.2.0` 后 define 恢复正常。

**3. 引擎 Project.xml 里不能给 flixel 钉版本。**
haxelib 的 dev 链接只接管「未钉版本」的解析（实测探针）：

| 引擎声明 | 解析结果 |
|---|---|
| `<haxelib name="flixel" version="6.2.0"/>` | `C:/HaxeToolkit/haxe/lib/flixel/6,2,0/`（上游，dev 链接被绕过） |
| `<haxelib name="flixel"/>` | `I:/WB/2026-10-17-04-51-28/flixel-fork/`（本 fork） |

回退语义：移除 dev 链接后，未钉版本解析到 haxelib 的 `.current`（当前是 6.2.0 上游），仍然可用。

### 接入 / 撤销

```powershell
# 接入
haxelib dev flixel "I:\WB\2026-10-17-04-51-28\flixel-fork"
# 撤销（回到上游 6.2.0）
haxelib dev flixel
```

对应引擎侧（`F:\1.0.4\Project.xml`）：

```xml
<haxelib name="flixel"/>
```

### 影响范围

dev 链接是**机器全局**的（写在 `C:\HaxeToolkit\haxe\lib\flixel\.dev`），但只影响「未钉版本」的解析。
实测 `-lib flixel:6.1.2` 仍然解析到 `haxelib/lib/flixel/6,1,2`，所以钉了版本的其它工程（如 CNE 用 6.1.2）不受影响。


## 目录

| 路径 | 说明 |
|---|---|
| `flixel/` | 上游 6.2.0 源码 + 自有补丁 |
| `patches/` | 每个补丁一份 md（动机 / 改动 / 验证） |
| `assets/` | 上游内置资源（include.xml 需要） |
| `haxelib.json` | `rainy-flixel`，版本 `6.2.0-rainy.N` |
| `upstream.json` | 上游仓库与 tag，供同步脚本读取 |

## Patch 状态

| ID | 状态 | 内容 | 文档 |
|---|---|---|---|
| P1 | 已实现 | FlxFrameStats：update/draw/render 三段计时、512 帧环形缓冲、p50/p99、draw call 暴露，零每帧分配 | `patches/P1-frame-stats.md` |
| P2 | 设计中 | draw item 按 atlas 聚类排序，减少断批 | `patches/P2-draw-sorting.md` |
| P3 | 设计中 | multi-texture batching：单批最多 8 贴图 + textureSlot 顶点属性 | `patches/P3-multitexture.md` |
| P4 | 设计中 | blend 状态切换跳过（需 RenderDoc 先验证） | `patches/P4-blend-skip.md` |

## 扩展点（怎么加新功能）

| 位置 | 可扩展内容 | 注意 |
|---|---|---|
| `flixel/FlxGame.hx` | 主循环分段插桩（P1 模式：begin/end 成对），已有 10 个调用点 | 新增插桩必须保持每帧零分配 |
| `flixel/system/FlxFrameStats.hx` | 新的统计维度（如纹理绑定数、sprite 数、GC 触发） | 复用环形缓冲与 percentile 逻辑，勿在采样路径分配 |
| `flixel/graphics/tile/*` | 批合并策略、draw item 字段扩展（P3 的前提） | 改动会影响所有渲染路径，必须跑完整游戏回归 |
| `flixel/FlxCamera.hx` | 相机渲染路径、draw stack 收集与排序 | 相机是最热路径之一，改前先量 |

加完功能的验证闸门：① 引擎 `lime build windows -release` 通过 ② 一首歌跑通（判定/脚本/相机/HUD）③ `FlxFrameStats` p99 不劣化。

## 上游同步

```
git remote add upstream https://github.com/HaxeFlixel/flixel.git
git fetch upstream --tags
git diff upstream/6.2.0 HEAD -- flixel/        # 查看自有改动
git checkout upstream/<新版本> -- flixel/       # 把补丁 rebase 到新上游
```

原则：自有 diff 最小化、每个 patch 独立提交、上游修复优先 merge。

## 验证状态

- 已完成：P1 的 10 个插入点与 6.2.0 源码逐行核对（行号与 6.1.2 一致）；FlxFrameStats 符号引用核对（`Lib.getTimer`、`FlxDrawBaseItem.drawCalls`、`FlxG.renderTile` 均存在）
- 未完成：接入引擎后的编译与实机帧时间采样（需切换 haxelib dev 并跑构建）

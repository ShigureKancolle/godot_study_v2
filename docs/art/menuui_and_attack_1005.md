# 赤金青玉菜单与攻击 1005

## 本次交付

- 菜单场景：`client/Prefab/Level/MenuUI.tscn`。保留 Node2D 根节点与三个按钮唯一名称，不添加菜单脚本或业务信号。
- 新菜单素材目录：`client/Prefab/CommonRes/UI/`，使用内置 image_gen 生成的原始 PNG，保留透明通道；菜单不再引用 CommonTexture 图片。
- `MenuPanel_CrimsonJade.png`：1942×809，赤金边框、青玉嵌饰、深紫底板。场景通过 AtlasTexture 取 Rect2(28,65,1886,661)，去掉画布空白，不修改原图像素。
- `MenuButton_Crimson.png`：1254×1254，红色按钮，用于重开与回到主界面。
- `MenuButton_Jade.png`：1254×1254，青玉按钮，用于继续。贴图保留半透明质感，场景在内盘下垫同色圆底，避免背景透过中心；悬停与按下沿用引擎样式调色。
- 菜单居中，宽度占视口 56%，高度占 39%；三个圆形按钮等宽；保持最近邻纹理采样。
- Panel 设置 top_level，使锚点使用视口尺寸，避免 Node2D 根节点的零尺寸导致菜单挤到左上角；仍保留根节点原有显示隐藏关系。相关依据：[Godot Control 布局实现](https://github.com/godotengine/godot/blob/4.6/scene/gui/control.cpp)、[CanvasItem 父节点及可见性实现](https://github.com/godotengine/godot/blob/4.6/scene/main/canvas_item.cpp)。

## 攻击 1005

- 配置源：`json_config/attack_config.json`，经 `py tools/sync_config.py` 同步至 `server/config/attack_config.json` 与 `client/config/attack_config.json`。
- 新场景：`client/Prefab/Effect/AttackEffect_1005.tscn`。
- 使用指定的 `Player_Attack_SectorSlashFX_1001.png` 原图，不修改该图，也不改变原 1001、1004 场景。
- `AttackInputController.ATTACK_ID` 改为 1005，左键使用新攻击。
- 判定：扇形半径 70、角度 120°。未指定的数值沿用 1001：命中 83ms、持续 583ms、冷却 600ms、伤害倍率 1.1、击退 80。
- 八帧切图沿用原图的 4列×2行，各帧 443×443。动画为 24 FPS，前六帧相对时长 2、后两帧 1，总计 583.33ms；主刀光从第二帧开始，约 83.33ms。

## Scale 节点校准

- 根节点保持单位缩放，位于玩家中心；现有 CombatPresenter 继续按 -atk_facing 设置根节点朝向。
- `Scale.scale = Vector2(0.192833282, 0.192833282)`。
- `Scale.rotation = -0.020789681` 弧度，约 -1.191161°，只校正美术的轻微不对称。
- `Scale/AnimatedSprite2D.position = Vector2(163.117113, 0)`，调整原贴图枢轴，使范围缩放完全交给父节点 Scale。
- 根据所有八帧 alpha≥128 的像素中心计算，变换后主体最大半径约 70.0000001，方位约 [-60°,60°]；不需要修改 120° 判定角度。
- alpha≥64 的次要边缘最大半径约 70.22，角度约 [-60.15°,60.25°]；极淡粒子和抗锯齿像素仍可能超出判定扇形，不能将每个非零透明像素视为命中边界。
- 这是素材几何核对，不是联网命中验收。

## 检查记录

环境：Windows，Godot 4.6.3，服务端 Python 3.14；图像静态检查使用工作区自带 Python、Pillow、NumPy。

| 检查 | 状态 | 命令与证据 |
| --- | --- | --- |
| 配置同步 | 通过 | `py tools/sync_config.py`；同步前核对配置源与两端一致，同步后三份攻击 JSON 内容相同 |
| 服务端读取 1005 | 通过 | 在 server 目录执行 `py -B -X utf8 -c "from game.model.config_loader import get_attack_config; print(get_attack_config(1005))"`；返回 SectorParams(radius=70.0, angle=2.0943951023931953) |
| 素材透明度与几何 | 通过 | 内存中读取 PNG 与八帧 alpha，未写入新验证脚本、未改动源图；三张菜单 PNG 均含全透明外部像素；刀光主体校准结果见上文 |
| 输入脚本解析 | 通过 | Godot `--headless --path client --check-only --script res://Scirpt/game/controller/AttackInputController.gd`；退出 0；日志 `.tmp/attack1005_input_parse.log` |
| 新攻击场景加载 | 通过 | Godot `--headless --path client res://Prefab/Effect/AttackEffect_1005.tscn --quit-after 2`；退出 0，无场景或脚本加载阻塞；日志 `.tmp/attack1005_startup.log` |
| 菜单纹理导入 | 通过 | Godot `--headless --editor --path client --import`；三张 PNG 完成导入；日志 `.tmp/menuui_crimson_import.log` |
| 菜单静态画面 | 通过 | Godot `--path client res://Prefab/Level/MenuUI.tscn --rendering-method gl_compatibility --audio-driver Dummy --resolution 960x540 --write-movie D:/work2/godot_demo_v2/.tmp/menuui_crimson_final.png --quit-after 2`；以隐藏进程启动，退出 0，实际按项目逻辑尺寸输出 1152×648；查看 `.tmp/menuui_crimson_final00000001.png`，面板居中、三按钮完整且等宽，青玉内盘无背景漏出；日志 `.tmp/menuui_crimson_final.log` |
| 服务端启动 | 失败 | 在 server 目录执行 `py -B -X utf8 -`，标准输入包装 main.main 为 1.5 秒启动检查并预设临时端口；在路由注册阶段抛出 `ValueError: ClientMessageRouter.register pause_game_world not allowed`，尚未进入监听。来源为工作区已有的 server/app/bootstrap.py 第22行暂停路由注册；本次未修改暂停功能或协议生成物 |
| 游戏内命中、双客户端联调 | 未执行 | 本次按常规改动范围进行静态与启动检查，未进行阶段验收 |

Godot 启动还输出证书存储读取、MCP 注册文件写入权限和退出资源占用提示；编辑器导入期间也无法保存全局编辑器设置。资源导入和相关场景加载已完成，这些提示不计为功能验收通过的证据。

## 最终采用素材的生成提示词

工具：内置 image_gen。下列三条为实际入库素材的生成提示词；后续未采用的按钮尝试未接入项目。

### MenuPanel_CrimsonJade.png

```text
Use case: stylized-concept.
Asset type: one production-ready blank menu panel texture for a Godot pixel-art action RPG. Generate a single wide rectangular panel, width to height 2.5:1, front-facing orthographic, filling the canvas with only a very narrow transparent margin outside the decorative silhouette. Style must match a small pixel-art samurai hero wearing red/crimson lamellar armor, gold/brass trim, dark aubergine shadows, and luminous jade/teal magical flame. Clean stepped pixel clusters, crisp pixel edges, restrained detail that remains readable at 600 by 240 display pixels. Frame: deep crimson lacquer armor plates and narrow antique gold bevels, small geometric jade insets at corners, symmetrical and flat. Interior: very dark muted plum, subtle pixel grain, wide uninterrupted EMPTY center suitable for placing three large circular buttons in a horizontal row. Low ornament density. Top and bottom borders and side borders slim (about 6 percent of panel height), corners compact, no protruding large motifs. TRUE RGBA transparency outside the panel, fully opaque interior. No text, no characters, no buttons, no symbols in the center, no scene, no mockup, no checkerboard, no watermark, no blur. Canvas landscape around 1536x640. This is a new original asset, not an alteration of the existing beige panel.
```

### MenuButton_Crimson.png

```text
Use case: stylized-concept.
Asset type: one production-ready blank circular button texture for a Godot pixel-art action RPG menu. Generate ONE centered perfectly round button, front-facing flat orthographic, occupying 94 percent of a square canvas with TRUE RGBA transparent corners and outside. Style must match a small pixel-art samurai hero wearing red/crimson lamellar armor, gold/brass trim, dark aubergine shadows, and jade/teal magic. Use clean crisp stepped pixel clusters, small controlled palette and hard-edged highlights, legible at 110x110 pixels. Button design: narrow antique brass outer rim, dark plum outer shadow, deep crimson lacquer inner disk, subtle beveled ring and tiny symmetric jade studs at north/south/east/west edge. Keep the center a calm EMPTY dark red disk for a Chinese text label later, no busy patterns. No icon, letters, text, character, weapon, watermark, environment, perspective, cast shadow outside the silhouette, blur, soft glow, or drawn checkerboard. One button only, not a sprite sheet. Pixel-art not vector, not photoreal. Square canvas.
```

### MenuButton_Jade.png

```text
Use case: stylized-concept.
Asset type: one production-ready blank circular button texture for a Godot pixel-art action RPG menu, primary continue action. Generate ONE centered perfectly round button, front-facing flat orthographic, occupying 94 percent of a square canvas with TRUE RGBA transparent corners and outside. Style must match a small pixel-art samurai hero wearing red/crimson lamellar armor, gold/brass trim, dark aubergine shadows, and luminous jade/teal magical flame. Use clean crisp stepped pixel clusters, small controlled palette and hard-edged highlights, legible at 110x110 pixels. Button design: narrow antique brass outer rim, dark plum outer shadow, saturated dark jade/teal inner disk, brighter mint edge bevel, tiny symmetric crimson studs at north/south/east/west edge. Keep the center a calm EMPTY dark jade disk for a Chinese text label later, no busy patterns. No icon, letters, text, character, weapon, watermark, environment, perspective, cast shadow outside the silhouette, blur, soft glow, or drawn checkerboard. One button only, not a sprite sheet. Pixel-art not vector, not photoreal. Square canvas.
```

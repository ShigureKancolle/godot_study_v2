# 固定寻路测试地图制图与导出

打开 `res://Tools/MapAuthoring/NavigationTestMap.tscn` 后，`Terrain` 是唯一逻辑地形层。首次打开空场景时，挂载的 `@tool` 脚本会生成基准地图；请保存一次场景，之后即可像普通 `TileMapLayer` 一样使用草地和水 tile 修改。检查器中的“重建基准地图”会清空手绘改动并恢复公式布局。

基准图沿用 v1 约定：`1 block = 2×2 tile`，`1 tile = 16×16 px`。总范围为 `68×44 block`，内部可移动范围为 `64×40 block`（`2048×1280 px`，约 3.2 个 `1152×720` 视口面积），四周各有 `2 block` 水边界，内部有三个按 block 对齐的水池。

TileSet 的草地 tile 带 `terrain_id=0`，水 tile 带 `terrain_id=4`。这里不保存 `blocked`：双端应继续用 `terrain_id` 查询各自同步得到的 `terrain_config.json`，避免出现两套可写通行规则。

## 手动导出

1. 在 Godot 中打开并保存 `NavigationTestMap.tscn`。
2. 在脚本编辑器打开 `ExportNavigationTestMap.gd`。
3. 执行编辑器脚本的“运行”（Godot 的 one-off `EditorScript` 入口）。
4. 输出面板出现 `[MapExporter] 导出成功` 后，在仓库根目录运行 `python tools/sync_config.py`，把公共 JSON 复制到 `server/config/` 和 `client/config/`。

导出器读取当前编辑场景中的 `Terrain`，按行排序 `get_used_cells()`，逐格通过 `get_cell_tile_data()` 读取 TileData 的 `terrain_id`。逐格检查通过后，同一个 `2×2 tile` block 只输出一个地形值，最终写入 `json_config/navigation_test_map.json`。因此 JSON 是制图场景的生成物，不应与场景同时手改。

## JSON 字段如何得到

- `map_id`、`map_version`：来自 `Terrain` 检查器属性；改变地图内容后应递增版本。
- `tile_size_px`：来自 `Terrain.tile_set.tile_size`。
- `block_size`：来自制图脚本的 v1 常量 `BLOCK_SIZE=2`。
- `cell_bounds`：来自 `Terrain.get_used_rect()`；最小值包含，最大值不包含。
- `block_bounds`：用 `cell_bounds / block_size` 得到；包含最小 block、排他的最大 block 和宽高。
- `coordinate_system.origin_cell_center_world_px`：由 `map_to_local(Vector2i.ZERO)` 取得格心，再用 `to_global()` 转成世界坐标。
- `terrain_encoding`：声明地形数组按 row-major 排列、值域是 `uint8`，并给出索引公式。
- `terrain_ids`：按 block 的 y 从小到大、同一行 x 从小到大保存；本图只有 `68×44=2992` 个值，不再重复保存 11968 组 tile 坐标。

双端读取某个 block `(block_x, block_y)` 时，先计算：

```text
local_x = block_x - block_bounds.min_inclusive.x
local_y = block_y - block_bounds.min_inclusive.y
index = local_y * block_bounds.size.x + local_x
terrain_id = terrain_ids[index]
```

Python 加载完成后建议把 `terrain_ids` 转成 `bytes` 或 `bytearray`，再释放原始 JSON 字典；客户端则把一个 block 的地形展开到对应的 `2×2 tile`。

格子 `(x,y)` 的左上角世界坐标是 `(x*tile_width, y*tile_height)`，格心是 `((x+0.5)*tile_width, (y+0.5)*tile_height)`。范围外和范围内未声明格子均按不可走处理。首版要求场景根和 `Terrain` 均保持原点、零旋转、零倾斜、单位缩放；要求完整矩形、普通 atlas tile、无替代 tile，并要求每个 `2×2 tile` block 的 `terrain_id` 一致。任何违反都会终止导出并在输出面板说明具体 cell 或属性。

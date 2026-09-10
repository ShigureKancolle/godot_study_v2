# 阶段 7 工作内容、完成进度与文件职责

本文区分当前实现与待实施方案，对应 [重建清单阶段 7](../V2_REBUILD_TODO.md#阶段-7实现最小-ai-和寻路)。进度依据为 2026-09-08 的工作区代码、现有自动测试及纯服务端探测；未进行 Godot 双客户端现场验收。

## 1. 当前结论与接下来的顺序

7A 的索敌、直线追逐、停止、转向和攻击主链路已实现。目标时序、状态标签、快照等已知问题记录在 [阶段 7 BUG](PHASE7_BUGS.md)，按用户取舍暂缓处理，不作为接摄像头或推进 7B 的阻碍。基础能力验收和联调仍需单独记录结果。7B 的障碍网格与寻路尚未接入。

| 顺序 | 工作 | 完成标志 |
| --- | --- | --- |
| 当前基础：7A 最小 AI | 空地图、直线追踪、`idle/chase/attack`、目标失效处理 | 主链路已有，剩余项见第 2 节 |
| 下一步：7A.5 摄像头 | 本地玩家跟随、绑定与清理、鼠标朝向验收 | 画面跟随本地角色，双客户端各自跟随 |
| 然后：7A 验收 | Codex 编写用例并执行专项测试和联调，按已接受的行为验收 | 记录通过项、实际失败项及已接受的暂缓问题 |
| 后续：7B 最小寻路 | 固定障碍网格、A*、路径跟随、预算和失效处理 | 敌人能绕墙，无路或预算不足时安全等待 |

摄像头接入不依赖寻路或地图碰撞，可以现在手写。具体文件、挂接顺序和验收见 [7A.5 摄像头工作方案](PHASE7_CAMERA_WORK_PLAN.md)。

7B 使用一张固定、有限的障碍测试地图，让绕墙和不可达场景可以重复验证。服务端执行可行走、移动碰撞和寻路查询；客户端读取同一配置显示障碍，联调时玩家应当看得见墙。它不是只在服务端存在的隐形地图，也不要求先恢复完整无限随机地图。

本阶段继续保持简单状态，不扩展巡逻、视锥、行为树、群体避让、返巢、远距离瞬移或生存刷怪。

### 1.1 验收与联调由谁执行

验收和联调统一由 **Codex 负责编写用例、准备必要测试脚本、执行并记录结果**，包括纯服务端规则、Godot 表现、双客户端与断线联调。业务代码继续由用户手写；验收任务不默认交给用户手测。

每项记录用例、运行方式、环境、预期结果、实际结果及必要证据，区分通过、失败、未执行、环境受限。受工具或环境限制无法验证的项目如实说明，不能用服务端单测通过代替客户端联调通过。当前请求是记录分工与暂缓项，不代表整套未执行联调已完成。

## 2. 7A 完成进度

“已实现”表示相应基础行为已有代码；已接受的暂缓问题单独引用 BUG，不等于当前基础能力失败。测试与联调状态按实际执行结果填写。文件名沿用当前实现，不要求为了匹配早期方案而改名。

| 编号 | 工作 | 状态 | 当前证据与剩余项 |
| --- | --- | --- | --- |
| 7A-01 | AI 参数与配置加载 | 基础已实现 | `json_config/ai_config.json`、`EntityAiConfig`、`get_entity_ai_config()` 已接入；语义校验记为 BUG-7-05，暂缓 |
| 7A-02 | AI 状态和目标组件 | 已实现 | `AIComponent` 保存字符串状态、配置名、目标 ID 和攻击意图间隔；当前不需要强行为状态加枚举 |
| 7A-03 | 装配敌人组件 | 已实现 | `create_enemy()` 根据 `ai_id` 添加 AI，移动速度来自实体配置；攻击朝向走已有 `CombatComponent.atk_facing` |
| 7A-04 | 索敌和目标保留 | 基础已实现 | 选择范围内最近活玩家，保留有效旧目标；等距离按插入顺序，BUG-7-02 暂缓 |
| 7A-05 | 直线追踪和无目标停止 | 已实现 | 产生 `MoveCommand`，由移动系统归一化；目标死亡或移除且无替代目标时能停止 |
| 7A-06 | 同 tick 应用 AI 命令 | 已实现 | `GameWorld.step()` 在 pipeline 更新前调用 `AICompSystem.decide()` 并逐条 dispatch |
| 7A-07 | 攻击距离、停止、转向、攻击 | 基础已实现 | 停止 → 转向 → 攻击链路有效；攻击等待状态标签记为 BUG-7-03，暂缓；进入/退出距离分离保留为可选设计 |
| 7A-08 | 目标失效与自身死亡 | 基础已实现 | 死亡/移除目标可当次停止或重选，自身死亡不产生新 AI 命令；超距重选时序记为 BUG-7-01，接受现状 |
| 7A-09 | 快照动画与 AI 状态 | 动画已实现，AI 投影暂缓 | 移动动画为 `run/idle`；客户端当前不消费 `ai_state`，空值记为 BUG-7-04 |
| 7A-10 | AI 和 pipeline 专项测试 | Codex 待补齐并执行 | 已有死亡追逐敌人停止同步测试；后续覆盖当前接受的基础行为，暂缓问题不要求先修复 |
| 7A-11 | 单玩家、双玩家联调 | Codex 待编写并执行 | 服务端基础行为探测通过；双客户端画面、朝向、真实断线重选尚未现场验收 |

### 2.1 已执行的核对

在 `server/` 运行：

```powershell
python -B -m unittest discover -s tests -v
```

结果：15 个现有测试全部通过，包括矩形碰撞、命令校验、死亡延迟移除、死亡和锁定后的停止事件。它们不是 15 个 AI 专项测试。

另外通过临时内存脚本直接推进 `GameWorld`，未启动 WebSocket、未新增测试源文件：

- 敌人当 tick 获得目标并推进移动；已有目标有效时不因另一名玩家更近而切换。
- 目标死亡或移除后，有其他玩家则当次重选，无其他玩家则停止。
- 单史莱姆使用当前配置攻击 1001，在玩家位于上下左右各 40 像素的独立场景中，推进 60 个 `1/30s` tick，均产生攻击，玩家血量由 100 降至 95。
- 超出脱战距离、攻击等待状态、等距离选择和快照 AI 状态的缺口均可复现。

临时探测只确认这些具体场景，不能代替持续回归测试或客户端联调。真实断线还需要验证网络清理最终确实移除了玩家。

### 2.2 暂缓问题与当前验收边界

具体复现条件、实际影响及未来可选修复见 [阶段 7 BUG 记录](PHASE7_BUGS.md)。普通超距重选晚一个 tick，当前约 33ms，接受现状。冷却期间保留超距目标的探测通过脚本直接移远目标触发；按当前参数，普通跑动不会在 600ms 内从 50px 攻击范围内跑出 600px 脱战范围。

攻击等待时的 `chase/idle` 标签与空 AI 快照目前不影响已有客户端移动和攻击显示。等距离选人依插入顺序可复现，不等于随机或每帧切换。上述事项以及配置语义校验都不列入当前必须修复的清单。

Codex 后续补齐当前基础行为的自动验收并执行联调，在结果中明确标注已接受的暂缓问题；用户决定修复后，再编写并执行对应修复回归。当前已为史莱姆和骷髅配置简单 AI，基础联调先保留一只敌人，减少干扰。

## 3. 7A 当前文件与职责

| 文件 | 当前职责 |
| --- | --- |
| `json_config/entity_config.json` | 保存实体能力、速度以及 `ai_id` |
| `json_config/ai_config.json` | 按 AI 配置名保存索敌、脱战、攻击距离、攻击间隔及攻击 ID |
| `server/game/model/config_loader.py` | 加载配置并构造 `EntityAiConfig`；语义校验改进暂缓，见 BUG-7-05 |
| `server/game/model/ai_component.py` | 保存 `state`、`config_name`、`state_target_id`、`atk_interval_ms` |
| `server/game/systems/ai_compsystem.py` | 读取 World，更新 AI 自身状态与计时，返回移动、转向和攻击命令 |
| `server/game/world.py` | 装配敌人及系统，在当前 tick 分发外部命令和 AI 命令 |
| `server/game/tick_pipeline.py` | 提供命令分发入口，依注册顺序更新系统 |
| `server/game/systems/comp_system.py` | 执行移动和攻击规则、更新坐标与血量、产生领域事件 |
| `server/game/systems/combat_compsystem.py` | 应用攻击朝向，推进攻击冷却 |
| `server/game/systems/death_system.py` | 产生死亡事件，按配置延迟移除 |
| `server/game/entity_projector.py` | 生成实体快照；AI 状态投影暂缓，见 BUG-7-04 |
| `server/tests/test_movement_stop_events.py` | 包含死亡追逐敌人停止、无新 AI 命令及协议停止事件的回归测试 |

当前没有独立 `AIState` 枚举，敌人也没有装配独立 `FacingComponent`。这些与早期方案的结构差异本身不等于功能缺失：移动事件可从移动方向取朝向，攻击使用 `CombatComponent.atk_facing`。以实际行为和边界测试决定是否需要补组件。

后续由 Codex 新增并执行 `server/tests/test_ai_system.py` 验证命令输出与当前约定行为，新增并执行 `server/tests/test_ai_pipeline.py` 验证同 tick 顺序、确定性及移动和战斗约束。不要复制一份伤害或移动规则到测试中。

## 4. 当前 tick 顺序

```text
GameWorld.step(dt)
  → 按队列顺序 dispatch 外部命令
  → AICompSystem.decide(world, dt)
  → 按返回顺序 dispatch AI 命令
  → MovementCompSystem.update
  → JoinCompSystem.update（当前为空）
  → AttackCompSystem.update
  → LeaveCompSystem.update（当前为空）
  → CombatCompSystem.update
  → DeathSystem.update
  → SpawnEnemySystem.update
  → 生成 TickResult，交给现有适配器发送
```

AI 的位置、血量和战斗冷却仍由原系统修改。AI 攻击命令顺序为停止移动 → `AtkRotateCommand` → `AttackCommand`；当前角度契约使用 `-atan2(dy, dx)`。重合位置的朝向保留规则还应补测试。

AI 命令不入下一 tick 的外部队列；`CombatCompSystem` 每 tick 只推进一次冷却。`AIComponent.atk_interval_ms` 是 AI 产生攻击意图的间隔，`CombatComponent.atk_countdown_ms` 是战斗系统执行攻击的冷却，二者职责不同。

内部命令沿用 `connection_id=0`，仍经过移动与战斗校验。当前适配器会将拒绝事件交给 `send_to(connection_id)`；后续应明确内部拒绝结果的记录方式，不向不存在的客户端连接投递。

## 5. 7B 工作表（全部待办）

7B 前置条件为按当前接受的行为完成 7A 基础验收；暂缓 BUG 不作为阻碍。7B 的查询单测与两端联调用例均由 Codex 编写和执行。摄像头便于观察绕行，但不进入寻路算法的依赖。

| 编号 | 工作 | 主要文件 | 验收方式 |
| --- | --- | --- | --- |
| 7B-01 | 有限障碍网格和统一可行走查询 | `model/navigation_grid.py`、测试地图配置 | 移动与寻路使用同一障碍数据和实体尺寸规则 |
| 7B-02 | 有节点展开上限的纯 A* | `tools/pathfinding.py` | 有路、无路、非法起终点和预算耗尽结果明确 |
| 7B-03 | 路径状态与跟随 | `model/navigation_component.py`、`systems/ai_compsystem.py` | 通过移动命令跟随路径点，不直接设置坐标 |
| 7B-04 | 单 tick 总预算与公平轮转 | `navigation_component.py`、`ai_compsystem.py`、`world.py` | 多敌人不突破预算，后面的敌人不会一直得不到查询 |
| 7B-05 | 路径失效、重算间隔、无路重试与开关 | 同上、`json_config/ai_config.json` | 目标移动或路径阻塞可恢复，预算不足不误判为无路 |
| 7B-06 | 移动合法性接入网格 | `systems/comp_system.py` | 检查整段移动与实体体积，大步长不能跨墙 |
| 7B-07 | 纯查询测试及两端可见的障碍联调 | 寻路测试、AI 导航测试、`NavigationDebugView.gd` | 绕行、无路、预算耗尽、关闭寻路均通过 |

### 5.1 待新增文件与职责

下列服务端路径以 `server/game/` 为基准；标出完整前缀的路径以仓库根目录为基准。

| 文件 | 职责 |
| --- | --- |
| `model/navigation_grid.py` | 有限网格、坐标转换、地图版本、按实体半径查询可行走区域及移动线段 |
| `model/navigation_component.py` | 每实体的路径点、索引、目标格、地图版本、重算计时；World 的全局轮转状态 |
| `tools/pathfinding.py` | 纯 A* 查询；不写 World，不发送命令或消息 |
| `server/tests/test_pathfinding.py` | 路径正确性、边界、不可达、展开上限 |
| `server/tests/test_ai_navigation.py` | 跟随、停止、失效重算、总预算、公平性和不穿墙 |
| `json_config/navigation_test_map.json` | 一张有限测试地图：格子尺寸、范围、障碍格；两端同一数据源 |
| `client/Scirpt/game/level/NavigationDebugView.gd` | 在 `TestLevel/Map` 下画测试障碍，与实体使用同一世界坐标；不计算权威路径或碰撞 |

接入时再调整 `world.py`、`ai_compsystem.py`、`config_loader.py` 和 `MovementCompSystem.check_can_move()`。测试网格无需依赖无限地形生成器。

手写配置只修改 `json_config/`，再通过 `tools/sync_config.py` 同步到两端 `config/`。地图也可由编辑器导出为该目录下的公共数据；若采用导出方案，该地图 JSON 是生成物，只修改制图源，不再同时手改 JSON。制作方式见第 5.5 节。首次固定地图联调可以使用同一发布包中的配置副本；未来有多地图或运行时地图变更时，再约定地图身份、版本及同步，不能让运行中的客户端提交地图覆盖服务端规则。

### 5.2 查询与执行分开

建议查询语义：

```text
find_path(grid, start_cell, goal_cell, agent_radius, max_expansions) -> PathResult
```

结果包含状态、路径点、实际展开节点数，至少区分 `FOUND`、`UNREACHABLE`、`INVALID_ENDPOINT`、`BUDGET_EXHAUSTED`。起终点相同是合法结果。使用固定邻居顺序和平局规则，保证复现。

首版四邻接，按实体半径预留空间，不做路径平滑或跨帧搜索缓存。移动检查使用相同尺寸规则，并检查移动线段，不能只查终点。

AI 取得路径后只计算移动意图。接近路径点时需要限制本次移动距离，避免越过节点反复折返；7B 再给领域移动命令设计停止距离或目标点约束，位移仍由移动系统执行，客户端仍不能提交权威坐标。

### 5.3 状态与预算

- 地图、地图版本、公平轮转游标归 `GameWorld` 持有。
- 每个敌人的路径、当前索引、目标格与重算计时归其 `NavigationComponent` 持有。
- 搜索堆与已访问集合只存在于一次查询内部。
- 当前 tick 查询次数与节点消耗使用所有敌人共享的局部预算。

在 `ai_config.json` 新增明确的 `navigation` 全局配置区，与现有按名称保存的 AI 参数分开。需要的字段为 `navigation_enabled`、`repath_interval_ms`、`waypoint_reach_distance`、`max_queries_per_tick`、`max_expanded_nodes_per_query`、`max_expanded_nodes_per_tick`。原有加载器会遍历顶层非注释键，增加全局区时必须一起调整解析，避免被当成一种 AI 配置。

旧 `constants.json` 含寻路常量，接入时选择并记录唯一参数来源，不同时读取两套同义参数。

### 5.4 失效与失败策略

目标换人或死亡、目标进入其他格、地图版本变化、下一段不可走、偏离路径或到达末端，都要重新评估。目标仍在同格时不必因轻微移动立即重算。

预算不足时继续使用安全有效的旧路径；没有安全路径就停止，下次轮到再查。无路时等待重试间隔或目标、地图变化。稳定实体顺序配合轮转游标分配查询机会。

关闭寻路后恢复直线追踪；障碍碰撞仍生效，遇墙停止，不能通过关寻路穿墙。

### 5.5 固定测试地图如何制作

V1 在 `client/Script/tiledmap/ChunkGenerator.gd` 和 `server/game/map_generator.py` 中分别实现区块生成器，用同一 seed 和算法生成逻辑地形。7B 可以先把输入换成固定地图数据；地图来源与可行走查询分开，未来再用生成器提供地形。

以下两种制作方式都可行。当前只记录方案，尚未选定或实现地图导出工具；建议希望可视化画地图时采用编辑器导出方式。

| 方式 | 制作入口 | 双端运行时输入 | 适用情形 |
| --- | --- | --- | --- |
| 手写配置 | 在 `json_config/navigation_test_map.json` 写格子与地形 | 同一 JSON 的两端副本 | 快速构造几堵墙、无路区域和寻路回归样本 |
| Godot 编辑器制作并导出 | 用 `TileMapLayer` 画地形，运行导出脚本 | 导出的同一 JSON 的两端副本 | 希望直观看见地图并反复调整布局 |

推荐的数据流：

```text
Godot 编辑器中的地图场景与 TileSet（制图源）
  → 编辑器导出脚本
  → json_config/navigation_test_map.json（运行时公共数据）
  → tools/sync_config.py
  ├── server/config/... → NavigationGrid → 移动与 A*
  └── client/config/... → TileMapLayer 或调试绘制
```

Godot 可使用 TileSet 自定义数据标记逻辑地形；同一种 tile 的所有放置实例共享其自定义数据，可通过替代 tile 表达变体。[Godot TileSet 自定义数据说明](https://docs.godotengine.org/en/4.6/tutorials/2d/using_tilesets.html#assigning-custom-metadata-to-the-tileset-s-tiles)

建议首版只导出一个方格地形层，装饰单独放层；地形 tile 携带 `terrain_id`，通行规则继续读取项目已有 `json_config/terrain_config.json`。例如 BRICK 和 WATER 不可走，GRASS 可走。不要同时维护独立的 `blocked` 与地形通行规则作为两套可写事实。

导出脚本遍历 `TileMapLayer.get_used_cells()`，通过 `get_cell_tile_data()` 读取 TileData 自定义数据；首版使用普通 atlas tile，对空格或非 atlas tile 明确校验，不静默漏掉障碍。[Godot TileMapLayer API](https://docs.godotengine.org/en/4.6/classes/class_tilemaplayer.html)

可以先用 `EditorScript` 提供一次手动导出入口，不需要先做完整插件。[Godot 编辑器脚本说明](https://docs.godotengine.org/en/4.6/tutorials/plugins/running_code_in_the_editor.html#one-off-scripts-using-editorscript)

公共数据至少约定：地图 ID/版本、格子尺寸、有限范围、坐标原点、格子坐标与 `terrain_id`。客户端另用固定映射将地形 ID 转成贴图；服务端不需要贴图资源。首版约定范围外和未声明地形的格子不可走，明确格心/格角坐标关系；可通过 Godot 的 `map_to_local()` 取得格心再转换到世界坐标进行双端比对。首版不支持旋转、缩放的逻辑地形层，导出时检查并提示。

**可以在客户端编辑器制作地图，但当前 Python 服务端不能直接把 Godot `.tscn`、TileSet 和 TileMapLayer 当作自己的地图模型加载。** 用 Godot 负责读取场景并导出公共 JSON，Python 读取 JSON 即可。制作场景是开发工具输入；实际客户端和服务端统一读取导出版本，可减少“场景已改、服务端配置未更新”的分歧。

由 Codex 编写并执行导出与双端一致性用例：同一制图源重复导出内容稳定；图中每个地形格与公共数据相符；Python 与 Godot 对相同格子给出相同地形和通行结果；格心、负坐标、边界一致；移动按实体半径检查整段位移而非只查格心。导出工具和这些用例都在实施地图步骤时再创建，摄像头仍先做。

## 6. 阶段 6 与验收边界

[阶段 6 BUG 记录](PHASE6_BUGS.md) 是早期记录，不能直接当作当前代码事实。当前工作区已增加死亡攻击者跳过结算、攻击层过滤，并修改扇形几何；当前 1001 在本次四方向探测中能扣血。这些证据不足以宣布对应 BUG 的所有边界已关闭，需另行做阶段 6 回归。

7A 重点验证 AI 决策不能绕过原移动与战斗入口；不在 AI 里另写命中或伤害算法。摄像头与地图显示同样不承担权威规则。

## 7. 完成检查（用例编写与执行负责人：Codex）

### 7A

- [ ] 补齐空世界、无玩家、重合位置、四向朝向的 AI 专项回归。
- [ ] 固定输入与固定 `dt` 得到相同结果；同 tick 命令顺序有测试。
- [ ] 验证超距后停止并在后续 tick 重选，接受 BUG-7-01 的时序，不要求先修复。
- [ ] 验证等待期间停止、间隔结束后攻击；状态标签和 AI 快照按 BUG-7-03、BUG-7-04 暂缓。
- [ ] 验证按当前插入顺序选人且保留有效目标；玩家死亡或移除后可当次停止或重选。不同插入顺序的平局规则按 BUG-7-02 暂缓。
- [1] 死亡追逐敌人停止移动，不再产生 AI 命令，并同步停止事件（现有测试通过）。
- [ ] 接回摄像头后完成单敌人单玩家、单敌人双玩家及真实断线联调。
- [ ] 实现后更新 `docs/MODULE_RESPONSIBILITIES.md` 的 AI 职责与 tick 顺序。

### 7A.5 与 7B

- [ ] 完成 [摄像头工作方案](PHASE7_CAMERA_WORK_PLAN.md) 的跟随与生命周期验收。
- [ ] 客户端能看见服务端采用的固定障碍布局。
- [ ] 绕行、无路、非法端点与预算耗尽结果正确。
- [ ] 总预算受控且分配公平，实体不能跨墙或斜穿墙角。
- [ ] 关闭寻路后仍可独立测试 7A，障碍地图上的碰撞仍生效。
- [ ] 只把实际完成并验证的内容同步到总清单。

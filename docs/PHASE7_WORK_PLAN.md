# 阶段 7 工作内容与文件职责设计

本文是待实施方案，不代表代码已完成。对应 [重建清单阶段 7](../V2_REBUILD_TODO.md#阶段-7实现最小-ai-和寻路)。本次只编写工作表和文件设计，不创建代码骨架、不修复阶段 6 BUG。

## 1. 本阶段要做到什么

一种敌人在服务端发现玩家，追逐玩家，进入攻击距离后停下并攻击；玩家离开、死亡或断线后，敌人能够停止或重新选择目标。客户端通过已有权威同步显示移动和战斗。

分成两个可单独验收的小阶段：

| 子阶段 | 内容 | 完成标志 |
| --- | --- | --- |
| 7A：最小 AI | 空地图、直线追踪、`idle/chase/attack`、目标失效处理 | 单个敌人能够发现、追逐和攻击玩家，多玩家时目标选择稳定 |
| 7B：最小寻路 | 固定障碍网格、A* 查询、路径跟随、预算和失效处理 | 敌人能够绕过障碍；无路或预算不足时安全等待；关闭寻路后仍能测试 7A |

先完成 7A，再创建 7B 文件。第一版不加入巡逻、视锥、行为树、群体避让、返巢、远距离瞬移、无限地图生成或生存刷怪。受击硬直不是本阶段要求。

## 2. 当前实现可以复用什么

| 当前模块 | 当前事实 | 阶段 7 怎么用 |
| --- | --- | --- |
| `GameWorld.create_enemy()` | 敌人已有位置、战斗组件和碰撞体；没有移动和 AI 组件 | 补充 `MovementComponent`、`FacingComponent`、`AIComponent` |
| `MoveCommand` / `MovementCompSystem` | 移动命令、归一化、死亡和锁定检查已存在 | AI 复用同一路径，不自行修改坐标 |
| `AtkRotateCommand` / `CombatCompSystem` | 攻击朝向与冷却已有实现 | AI 先提交转向，再提交攻击 |
| `AttackCommand` / `AttackCompSystem` | 攻击开始、判定帧、扣血已有实现 | AI 只提出攻击请求，不绕过死亡和冷却校验 |
| `DeathSystem` | 死亡事件与延迟移除已实现 | AI 排除死亡目标，自身死亡后停止决策 |
| `WorldFrame` 和客户端表现 | 已能同步移动、朝向、攻击、伤害与死亡 | 7A 原则上不需要新增协议或客户端 AI |
| `EntityInfo.ai_state` | 快照协议已有字段，服务端投影仍返回空字符串 | 可补充快照投影；实时 AI 状态不作为首版客户端依赖 |
| `tools/sync_config.py` | 实际读取 `json_config/`，复制到两端 `config/` | 所有新增数值在 `json_config/` 修改；旧说明中的 `shared_config/` 不作为新路径 |

## 3. 工作内容表

所有任务初始为待办；顺序表示推荐实施顺序，不是已经完成的记录。

| 编号 | 工作内容 | 主要文件 | 前置条件 | 验收方式 |
| --- | --- | --- | --- | --- |
| 7A-01 | 定义一种敌人的 AI 参数：索敌距离、脱离距离、攻击距离、攻击 ID | `json_config/ai_config.json`、`config_loader.py` | 无 | 配置能加载；未知类型不自动获得 AI |
| 7A-02 | 定义 `AIState` 与 `AIComponent`；只保存状态和目标 ID | `model/ai_component.py` | 7A-01 | 新敌人初始为 `idle`，没有目标 |
| 7A-03 | 为配置启用 AI 的敌人装配移动、朝向、AI 组件 | `world.py` | 7A-02 | 能通过已有移动命令移动敌人；速度来自实体配置 |
| 7A-04 | 实现索敌和目标保留规则 | `systems/ai_system.py` | 7A-03 | 只选活着的玩家；等距离选择确定；不每帧来回切目标 |
| 7A-05 | 实现直线追踪和无目标停止命令 | `systems/ai_system.py` | 7A-04 | 方向正确、不产生零向量归一化错误；目标失效后不沿旧方向继续跑 |
| 7A-06 | 在 tick 中加入 AI 决策及命令应用阶段 | `tick_pipeline.py`、`world.py`、`command_router.py` | 7A-05 | AI 命令在当前 tick 的移动前应用；不混进网络发送逻辑 |
| 7A-07 | 实现攻击距离切换、停止、朝向与攻击命令 | `systems/ai_system.py` | 7A-06 | 进入攻击范围停下；先转向再攻击；冷却期间不持续制造拒绝事件 |
| 7A-08 | 处理目标死亡、移除、断线、超出脱离距离及自身死亡 | `systems/ai_system.py` | 7A-07 | 同次决策清理失效目标、停止或重选；死亡敌人不产生新命令 |
| 7A-09 | 补齐快照移动动画和 AI 状态投影 | `entity_projector.py` | 7A-08 | 新进入客户端能看到当前实体位置与有效动画名；移动状态使用现有 `run/idle` 命名 |
| 7A-10 | 编写纯服务端 AI 和 pipeline 回归测试 | `tests/test_ai_system.py`、`tests/test_ai_pipeline.py` | 7A-09 | 固定世界与固定 `dt` 得到相同结果，不启动 WebSocket |
| 7A-11 | 单敌人单玩家、单敌人双玩家联调 | 现有客户端、`SpawnEnemyCommand` | 7A-10 | 双端观察一致，断线重选正常；不引入阶段 8 刷怪器 |
| 7B-01 | 定义有限障碍网格和统一可行走查询 | `model/navigation_grid.py` | 7A 验收 | 移动与寻路使用同一份障碍数据及实体尺寸约束 |
| 7B-02 | 实现有节点展开上限的纯 A* 查询 | `tools/pathfinding.py` | 7B-01 | 绕墙、有路、无路、非法起终点结果明确 |
| 7B-03 | 增加路径状态及跟随逻辑 | `model/navigation_component.py`、`systems/ai_system.py`、`world.py` | 7B-02 | 跟随下一路径点，仍通过 `MoveCommand` 移动，不直接设置坐标 |
| 7B-04 | 加入单 tick 查询次数和节点展开总预算、公平轮转 | `model/navigation_component.py`、`systems/ai_system.py`、`world.py` | 7B-03 | 多敌人不会突破预算，排在后面的敌人不会长期得不到查询机会 |
| 7B-05 | 加入路径失效、重算间隔、无路重试和开关 | 同上、`json_config/ai_config.json` | 7B-04 | 目标移动、地图变化、路径阻塞后可恢复；预算不足不被误判为无路 |
| 7B-06 | 将移动合法性接入统一网格查询 | `systems/comp_system.py` | 7B-01、7B-05 | 检查移动线段与实体体积，不能靠大步长跨墙 |
| 7B-07 | 补齐寻路单测与固定障碍场景联调 | `tests/test_pathfinding.py`、`tests/test_ai_navigation.py`、测试地图文件 | 7B-06 | 绕障碍、无路等待、预算耗尽、关闭寻路均通过 |
| 7-收尾 | 更新职责文档、tick 顺序和总清单 | `docs/MODULE_RESPONSIBILITIES.md`、`V2_REBUILD_TODO.md` | 实现与测试完成 | 文档只把实际完成并验证的内容标为完成 |

## 4. 文件存放位置与职责

下列路径均相对于仓库根目录。标注“新增”的文件现在只做设计，实施对应任务时再创建。

### 4.1 7A 新增文件

| 文件 | 职责 | 不承担的事情 |
| --- | --- | --- |
| `json_config/ai_config.json` | 按实体配置键保存 AI 行为参数，首版只配置一种敌人 | 不重复保存血量、速度、攻击伤害和冷却 |
| `server/game/model/ai_component.py` | 定义 `AIState`、`AIComponent`，保存实体的 AI 状态和目标 ID | 不搜索目标、不持有目标 Entity 引用、不发网络消息 |
| `server/game/systems/ai_system.py` | 定义 `AISystem`，读取权威状态，更新 AI 自身状态，产生移动、转向、攻击命令 | 不修改位置、血量、冷却；不直接调用其他 System |
| `server/tests/test_ai_system.py` | 验证状态切换、目标选择、方向和命令输出 | 不依赖客户端或 WebSocket |
| `server/tests/test_ai_pipeline.py` | 验证 AI 命令顺序、同 tick 应用以及移动和战斗约束 | 不复制一份伤害或移动规则 |

### 4.2 7A 调整现有文件

| 文件 | 要调整的内容 |
| --- | --- |
| `server/game/model/config_loader.py` | 加载 `ai_config.json`，增加 `AIConfig` 与 `get_ai_config(entity_config_key)`；校验距离关系、攻击 ID 等配置 |
| `server/game/world.py` | 装配敌人组件、AI 系统和 tick 阶段；实体上的 AI 状态仍由 World 持有 |
| `server/game/tick_pipeline.py` | 明确 AI 决策阶段，收集 AI 命令，通过路由器按序执行，再推进移动和战斗 |
| `server/game/command_router.py` | 复用已有命令到处理系统的映射；必要时补充顺序分发辅助方法，不塞入 AI 规则 |
| `server/game/commands.py` | 更新命令职责说明：移动和攻击命令也可由服务端 AI 产生，字段原则上复用 |
| `server/game/entity_projector.py` | 从 `AIComponent` 投影快照状态；统一移动动画名，当前快照的 `move` 与已有表现的 `run` 需要对齐 |
| `server/transport/game_protocol_adapter.py` | 如现有拒绝事件会发往连接 0，明确仅投递给真实客户端连接；服务端内部命令拒绝保留为领域结果 |
| `docs/MODULE_RESPONSIBILITIES.md` | 在实现后补充 AI 文件职责、状态归属与 tick 调用关系 |

`server/game/systems/comp_system.py` 中现有移动与攻击系统继续复用，先不为接入 AI 大规模搬文件。`CombatCompSystem` 的冷却每 tick 只推进一次，不能因为 AI 接入重复更新。

### 4.3 7B 再新增的文件

| 文件 | 职责 |
| --- | --- |
| `server/game/model/navigation_grid.py` | 有限网格的数据类型与查询；提供坐标和网格转换、地图版本、按实体半径检查可行走区域与移动线段的能力 |
| `server/game/model/navigation_component.py` | 定义 `NavigationComponent`，保存路径点、当前索引、目标格、地图版本、重算计时；定义 World 持有的 `NavigationBudgetState`，保存公平轮转游标 |
| `server/game/tools/pathfinding.py` | 纯函数 A*：输入只读网格、起终点、实体尺寸和展开上限，输出 `PathResult`；不写 World |
| `server/tests/test_pathfinding.py` | 验证路径正确性、边界、不可达与展开上限 |
| `server/tests/test_ai_navigation.py` | 验证跟随、停止、失效重算、总预算、公平性以及移动不穿墙 |
| `json_config/navigation_test_map.json` | 一张有限测试地图，保存格子尺寸、范围和障碍格；作为两端测试显示的同一数据源 |
| `client/Scirpt/game/level/NavigationDebugView.gd` | 在 7B 联调时绘制测试障碍，只负责显示服务端采用的地图布局，不参与 AI 或路径判定 |

接入 7B 时再调整 `world.py`、`ai_system.py`、`config_loader.py` 和 `MovementCompSystem.check_can_move()`，让移动与寻路读取同一张网格。测试地图查询无需与现有无限地形功能绑定。

配置副本 `server/config/ai_config.json`、`client/config/ai_config.json` 以及测试地图副本由 `tools/sync_config.py` 同步产生，不直接编辑。所有新增 Python 文件保留首行 `# coding=utf-8`，注释和文档字符串使用中文。

## 5. AI 状态和数据怎么设计

### 5.1 `AIComponent` 最小字段

| 字段 | 含义 | 写入者 |
| --- | --- | --- |
| `state: AIState` | `idle/chase/attack`，初始 `idle` | `AISystem` |
| `target_entity_id: str` | 当前玩家目标；无目标为空字符串 | `AISystem` |

先不缓存位置、血量、速度或冷却。通过目标 ID 从 World 查询最新状态；AI 参数使用实体已有的 `entity_config_key` 查配置。

### 5.2 状态切换

| 条件 | 状态与动作 |
| --- | --- |
| 没有有效目标，索敌范围内也没有活玩家 | `idle`；发停止意图，清空目标 |
| 找到目标，距离大于攻击进入距离 | `chase`；朝目标移动 |
| 距离进入攻击距离 | `attack`；停止移动，面向目标，冷却可用时请求攻击 |
| `attack` 中目标离开攻击退出距离 | `chase`；恢复追踪 |
| 目标死亡、移除或超出脱离距离 | 清空目标，当次重新索敌；没有替代目标则停止 |
| 敌人自身死亡 | 不再产生 AI 命令，由现有移动和死亡系统处理停止与移除 |

已有目标仍然有效时继续追踪，避免两名玩家距离接近时来回换目标。新选目标按“距离平方、实体 ID”排序，等距离时结果固定。

攻击进入距离与退出距离留少量间隔，避免边缘反复切换。攻击距离只是 AI 决定何时尝试攻击的参数，真正命中仍由战斗几何判定；应结合敌人与玩家碰撞体、攻击近边和远边调试。首版先用当前可工作的矩形攻击 1004。

### 5.3 配置字段

| 字段 | 用途 | 单位或约束 |
| --- | --- | --- |
| `enabled` | 是否给此类敌人启用 AI | 布尔值 |
| `acquire_radius` | 无目标时索敌距离 | 像素，正数 |
| `lose_radius` | 已有目标的脱离距离 | 像素，不小于索敌距离 |
| `attack_enter_distance` | 从追逐进入攻击状态的距离 | 像素，按选定攻击范围调试 |
| `attack_exit_distance` | 离开攻击状态的距离 | 像素，大于进入距离且小于脱离距离 |
| `attack_id` | AI 使用的攻击配置 ID | 初期 1004；伤害和冷却仍取攻击、实体配置 |
| `navigation_enabled` | 7B 寻路开关 | 7A 关闭 |
| `repath_interval_ms` | 路径重算最短间隔 | 7B，毫秒 |
| `waypoint_reach_distance` | 到达路径点的容差 | 7B，像素 |
| `max_queries_per_tick` | 整个 World 每 tick 最多寻路次数 | 7B，全局参数，不按敌人数叠加 |
| `max_expanded_nodes_per_query` | 单次查询展开上限 | 7B，正整数 |
| `max_expanded_nodes_per_tick` | 整个 World 每 tick 展开总上限 | 7B，正整数 |

在同一个 `ai_config.json` 中区分 `entities` 参数和 `navigation` 全局预算。现有 `constants.json` 里有旧寻路常量，7B 应选择并记录唯一参数来源，不同时读取两套同义参数；本次不迁移旧配置。

## 6. AI 怎样接入现有 tick

建议保留现有游戏系统的规则入口，只在命令应用与移动之间加入明确的 AI 决策阶段：

```text
GameWorld.step(dt)
  → 按现有队列顺序处理外部命令（加入、离开、输入、测试生成敌人等）
  → AISystem.decide(world, dt) 产生本 tick 的 AI 命令列表
  → TickPipeline 通过 CommandRouter 按顺序应用这些命令
  → MovementCompSystem.update：更新坐标、生成移动事件
  → AttackCompSystem.update：推进判定帧、命中与伤害
  → CombatCompSystem.update：推进冷却，保持每 tick 一次
  → DeathSystem.update：死亡事件、延迟移除
  → 汇总 TickResult，由现有网络适配器发送
```

`AISystem.decide()` 是本阶段新增的明确入口，返回领域命令列表；不把命令伪装成 `CompSystem.update()` 返回的 Event，也不让 `AISystem` 持有其他系统实例。

AI 命令由 pipeline 在当前 tick 内执行，不重新放入下一 tick 的外部命令队列。AI 可以更新自己的状态和目标字段，但位置、血量、攻击冷却始终交给对应系统修改。

攻击决策的命令顺序固定为：停止移动 → `AtkRotateCommand` → `AttackCommand`。当前角度契约与标准 `atan2` 符号相反，因此 AI 朝向使用 `-atan2(dy, dx)`；目标重合时保留原朝向，避免无意义转向。

服务端 AI 命令采用内部调用身份（沿用 `connection_id=0`，网络连接不得使用该值），`entity_id` 来自被遍历的敌人。AI 不经过 WebSocket Handler；网络消息仍必须由连接身份推导受控实体。内部身份不意味着可以跳过移动、死亡、冷却和战斗能力校验。

AI 可以读取冷却避免每 tick 发送注定被拒绝的攻击，但 `AttackCompSystem` 仍是最终校验者。保留当前冷却更新时序，不在此次 AI 接入中顺带重定义冷却算法；用 pipeline 测试固定行为。

## 7. 寻路的最小设计

### 7.1 查询与执行分开

建议接口语义：`find_path(grid, start_cell, goal_cell, agent_radius, max_expansions) -> PathResult`。

`PathResult` 包含状态、路径点和实际展开节点数。状态至少区分 `FOUND`、`UNREACHABLE`、`INVALID_ENDPOINT`、`BUDGET_EXHAUSTED`。起点等于终点是合法结果。使用固定邻居顺序和确定的平局规则，保证测试可复现。

首版使用四邻接网格，避免斜向穿墙角。返回路径需要按实体半径留出空间；移动也使用相同尺寸规则。不开路径平滑和跨帧搜索缓存，先用有界、同步的纯查询。

### 7.2 状态存在哪里

- 地图、地图版本与全局轮转状态归 `GameWorld` 持有。
- 每个敌人的路径、路径索引、目标格和重算计时归其 `NavigationComponent` 持有。
- 搜索堆、已访问集合只存在于一次查询内部，查询结束后释放。
- 当前 tick 的查询数、节点消耗是局部预算；所有查询共享同一个剩余预算。
- `AISystem` 取得路径后只计算移动方向；靠近路径点时限制本次步长，避免低帧率越过节点反复折返，具体位移仍由移动系统执行。

如果现有 `MoveCommand` 只有方向而没有限制本次移动距离的字段，7B 再设计领域级的停止距离或目标点约束供移动系统使用；不允许 AI 直接“吸附”坐标到路径点，也不向客户端开放提交权威坐标的能力。

### 7.3 路径何时失效

目标换人或死亡、目标进入其他格子、地图版本变化、下一段不可行走、实体偏离路径或到达路径末端，都应重新评估路径。目标轻微移动但仍处于同格时不必立即重算。

预算不足时，继续使用仍安全有效的旧路径；没有安全路径则发停止意图，下次轮到再尝试。无路时等待重试间隔或目标、地图变化，不每 tick 全量搜索。查询按稳定实体顺序配合轮转游标分配，避免总是优先同几个敌人。

关闭寻路后走直线追踪策略；在障碍地图上移动合法性检查仍然生效，敌人遇墙停止，不能通过关闭寻路穿墙。

## 8. 阶段 6 问题如何影响本阶段

用户已要求 [阶段 6 BUG](PHASE6_BUGS.md) 暂缓修复。本方案不自动扩大为修复任务；若问题仍存在，在联调报告中明确记录影响，不能把 AI 自己的过滤当作底层战斗规则已完善。

| 问题 | 对阶段 7 的影响 | 本阶段安排 |
| --- | --- | --- |
| BUG-6-01：死亡或移除攻击者的残留攻击 | AI 死亡后不再发新命令，但此前攻击仍可能结算 | 分别测试“AI 停止决策”和“战斗取消攻击”；后者保留已知问题 |
| BUG-6-02：转向越权 | 客户端可能改敌人朝向 | AI 内部正确取实体 ID；网络越权仍留在 BUG 文档 |
| BUG-6-03：能力与阵营过滤缺失 | 多敌人可能互相伤害，不能宣称完整战斗规则验收通过 | 先用单敌人验证决策；多敌人联调单独标注现象 |
| BUG-6-04：扇形判定错误 | 扇形攻击不能正常用于 AI | 首版配置 1004；不在 AI 中另写命中逻辑绕过问题 |
| BUG-6-05：请求去重不足 | 外部玩家攻击请求仍有重放缺口 | 内部 AI 每次冷却可用时产生新的攻击意图，不假装解决网络请求去重 |

新客户端在约 666ms 死亡动画窗口内加入时未恢复尸体动画，按当前取舍接受，不作为阶段 7 阻碍。

## 9. 完成检查

- [ ] 空世界、无玩家时 AI 不报错、不移动。
- [ ] 敌人发现、追逐并攻击玩家，伤害由现有战斗系统产生。
- [ ] 攻击前先停止并转向，四个方向均正确，重合位置不出错。
- [ ] 冷却、锁定、死亡约束仍由原系统生效；目标失效后无旧移动意图残留。
- [ ] 两名玩家时目标选择稳定，断线或死亡后能重选。
- [ ] 固定输入和固定 `dt` 的纯服务端测试可重复。
- [ ] 固定障碍地图能够绕行，无路和预算不足时正确等待。
- [ ] 寻路总预算受控，多个敌人不会长期饿死；关闭寻路后其他系统仍可测试。
- [ ] 客户端复用权威帧显示结果，不计算 AI 或命中。
- [ ] 阶段 6 已知问题与阶段 7 新问题分开记录，联调未通过的条件不勾选。

推荐第一批只实施 7A-01 至 7A-06：让一只敌人能稳定找到玩家并追上来。确认移动链路后再接攻击、失效处理与寻路。

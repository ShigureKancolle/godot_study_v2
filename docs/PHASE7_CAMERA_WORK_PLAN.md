# 7A.5：本地玩家跟随摄像头手写方案

本文是待实施的手写工作表，尚未创建摄像头脚本或修改场景。对应 [阶段 7 工作方案](PHASE7_WORK_PLAN.md) 和 [总清单](../V2_REBUILD_TODO.md)。

## 1. 先完成什么

进入游戏后，画面跟随本地玩家；其他玩家各自在自己的客户端控制自己的镜头。角色离开、视图移除或关卡退出时正确解除绑定，再次进入时绑定新角色。

摄像头是纯客户端表现。当前位置链路是：

```text
服务端坐标 → Reducer → GameStore → MotionPresenter 插值 → EntityView
                                                          ↓
                                                     CameraFollow
```

跟随目标选本地玩家的 `EntityView.global_position`。这样镜头和屏幕上实际显示的角色使用同一个位置。首版直接跟随视图，复用 `MotionPresenter` 的插值；额外的镜头缓动、震屏、鼠标前瞻、滚轮缩放可以后续按需要加入。

这一步不需要服务端改动、新协议、障碍网格或 A*。旧版 `client/Script/role/CameraFollow.gd` 可用于回忆表现，其 `ClientStateMirror` 绑定和固定比例插值不直接移植到 V2。

## 2. 文件与职责

| 文件 | 手写内容 |
| --- | --- |
| `client/Prefab/Level/TestLevel.tscn` | 在根节点下新增一个 `Camera2D`，挂 `CameraFollow.gd` |
| `client/Scirpt/game/level/CameraFollow.gd`（待新增） | 保存跟随视图引用、对齐摄像头、检查目标是否有效、解除绑定 |
| `client/Scirpt/game/level/TestLevel.gd` | 按本地实体 ID 绑定摄像头，在视图移除、清空和重建时协调生命周期 |
| `client/Scirpt/game/controller/LocalPlayerController.gd` | 检查镜头更新后的鼠标世界坐标与处理顺序，继续只发输入意图 |

`TestLevel` 已持有 `entity_views`，适合决定跟谁；`CameraFollow` 只负责怎么跟。镜头节点随关卡存在，玩家死亡后仍可停在最后位置。`EntityViewFactory` 继续只创建实体表现，摄像头无需进入玩家或敌人的公共预制体。

建议场景结构：

```text
TestLevel (Node2D)
├── Map
├── Entity
├── Effect
├── DamageNum
├── Camera2D       ← CameraFollow.gd
├── Hud
└── Debug
```

当前 `Hud` 是空的 `Node2D`。以后放固定屏幕 UI 时使用 `CanvasLayer`；地图、角色、攻击特效和伤害数字继续处于世界坐标中。

## 3. 按这个顺序手写

### CAM-01：先让关卡有唯一摄像头

新增 `Camera2D`，保持默认居中锚点、`zoom = Vector2.ONE`、`offset = Vector2.ZERO`，关闭额外位置平滑和拖拽边界。进入场景树后保持 `enabled = true`，用 `make_current()` 明确设为当前镜头。

`Camera2D` 每个视口只会激活一个；`make_current()` 要求镜头启用。内置位置平滑与镜头实际屏幕中心的关系见 [Godot Camera2D 文档](https://docs.godotengine.org/en/stable/classes/class_camera2d.html)。这里先保持直接跟随，便于判断角色已有插值的效果。

### CAM-02：只写绑定、解绑和跟随

`CameraFollow` 继承 `Camera2D`，先设计三个职责明确的入口：

| 入口/字段 | 语义 |
| --- | --- |
| `_target_view: Node2D` | 当前跟随视图；未绑定为 `null` |
| `bind_target(view)` | 检查视图有效且已入树，保存引用，立即将镜头对齐到视图的 `global_position` |
| `clear_target()` | 清空引用，镜头保留最后位置，清除本地偏移 |
| `_process(delta)` | 目标有效、未排队删除且仍在树中时，读取其 `global_position` 并更新镜头 |

先用命名局部变量和显式检查处理 `null`、`is_instance_valid()`、`is_queued_for_deletion()`、`is_inside_tree()`，确认有效后再读取位置。镜头只修改自己的位置，不修改角色节点或 Store。

首次绑定立即对齐，避免从世界原点飞向出生位置。未来若启用内置平滑，重新绑定或瞬移对齐时再调用 `reset_smoothing()`；关闭平滑时该方法无效果。[Godot 对齐说明](https://docs.godotengine.org/en/stable/classes/class_camera2d.html#class-camera2d-method-reset-smoothing)

### CAM-03：在视图初始化后绑定

当前 `TestLevel.spawn_entity()` 的顺序为创建视图 → 加入 `Entity` → `view.setup(state)` → 登记 `entity_views`。在这之后判断 `entity_state.entity_id == GameBootstrap.game_store.self_entity_id`，相等才绑定。

必须等 `view.setup()` 完成：它会通过 `MotionPresenter.set_position()` 设置初始服务端位置。若提前绑定，镜头可能先对齐到未初始化的原点。

本地身份来自服务端快照的 `self_entity_id`。`WorldSnapshotReducer` 已设置 `is_local_player`，但增量出生的 reducer 当前没有设置它，摄像头选择直接比较实体 ID 更清楚；不由摄像头修改这个标志。

### CAM-04：固定表现、镜头、输入顺序

当前 `MotionPresenter` 在 `EntityView._process()` 中插值，摄像头也使用空闲帧更新（`CAMERA2D_PROCESS_IDLE`）。建议处理顺序：

```text
EntityView 插值（process_priority = 0）
  → CameraFollow 跟随（process_priority = 100）
  → LocalPlayerController 采样鼠标并发送意图（process_priority = 200）
```

Godot 的 `process_priority` 数值越小越先执行；不要只依赖节点添加顺序。[Godot Node 文档](https://docs.godotengine.org/en/stable/classes/class_node.html#class-node-property-process-priority)

跟随脚本设置镜头位置后可调用 `force_update_scroll()`，确保这一帧的画布变换在随后采样鼠标前更新；首次绑定立即对齐时同样处理。该方法负责立即更新镜头滚动。[Godot Camera2D 文档](https://docs.godotengine.org/en/stable/classes/class_camera2d.html#class-camera2d-method-force-update-scroll)

`LocalPlayerController._atk_rotate_intent()` 已使用 `role.get_global_mouse_position()` 与 `role.global_position` 相减，保持这种同一画布坐标下的计算。该 API 返回节点所在画布层中的鼠标全局坐标，不需要再手工加一次镜头位置或屏幕中心。[Godot CanvasItem 文档](https://docs.godotengine.org/en/stable/classes/class_canvasitem.html#class-canvasitem-method-get-global-mouse-position)

### CAM-05：把生命周期接完整

| 触发点 | `TestLevel` 应做的事 |
| --- | --- |
| 首次进入关卡 | `_ready()` 从已有 Store 创建视图；本地视图初始化后绑定 |
| 后续本地视图创建 | 在 `spawn_entity()` 的同一入口绑定，避免出现两个绑定逻辑 |
| `remove_entity()` 移除跟随目标 | 先解除摄像头绑定，再移出场景树和 `queue_free()`；远端玩家移除不影响镜头 |
| `clear_entity_views()` | 先解除绑定，再清空全部视图 |
| 同一关卡收到新全量快照 | 旧视图可能已过期；清理旧视图并从更新后的 Store 重建，本地视图重新绑定 |
| 关卡退出 | 解除目标引用，清理本关卡新增的信号连接；镜头随场景销毁 |

当前 `TestLevel` 没有监听 `snl_world_snapshot_applied`，而 `GameBootstrap.enter_world()` 在已处于相同关卡时不会切场景。因此需要在关卡增加快照重建处理，避免再次快照后仍跟着旧视图；首次进入仍由 `_ready()` 读取 Store 完成初始化。

现有 `snl_store_cleared → clear_entity_views()` 可复用。网络层 `STATE_CLOSED` 当前只有 `pass`，尚不会自动调用 Store 重置；摄像头本身不监听 WebSocket。先通过已有 `GameBootstrap.reset_game_store()` 验证清理入口，真实断线到世界重置的连接作为后续联调项，不把它误判为已完成。

## 4. 验收与联调（Codex 编写用例并执行）

业务代码由用户手写；以下项目由 Codex 编写用例、准备测试脚本、执行并记录证据，不默认要求用户手测。能自动化的使用 Godot 测试脚本，涉及画面和双客户端的项目由 Codex 组织并执行联调；工具或环境受限时记录具体未验证项，不能把它标为通过。

- [ ] 首次进入时镜头立即对准本地角色，出生位置远离原点时也正确。
- [ ] 连续横向、纵向和斜向移动时镜头跟随角色，观察不到额外一帧拖尾。
- [ ] 停止后角色和镜头一起稳定，不因各自插值产生相对漂移。
- [ ] 镜头移动后，向上下左右攻击仍朝向鼠标；移动中持续瞄准也正确。
- [ ] 两个客户端进入同一房间，镜头各自跟随各自角色，远端出生不抢镜头。
- [ ] 本地玩家移除后镜头保留最后位置，无已释放对象访问错误。
- [ ] Store 清空、同场景新快照、退出再进入后重新绑定正确，不保留旧目标。
- [ ] 镜头移动只改变显示；Store 坐标、移动请求和服务端权威位置不受镜头影响。

完成 CAM-01 至 CAM-03 就能先看到基本跟随；继续完成 CAM-04 至 CAM-05 和验收，再用这个画面做 7A 双客户端收尾。7B 的障碍显示可直接放进已有 `Map` 节点，随同一镜头滚动。

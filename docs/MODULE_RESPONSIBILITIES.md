# V2 模块职责

本文只描述当前 V2 的模块边界。依赖方向为：入口装配 → 应用层 → 协议/传输与游戏领域；传输层不能直接修改 `GameWorld`。

## 服务端

| 文件或目录 | 唯一职责 |
| --- | --- |
| `server/main.py` | 创建依赖并同时启动 WebSocket 与固定帧游戏循环。 |
| `server/app/bootstrap.py` | 在启动时登记客户端消息路由和领域事件发布器。 |
| `server/app/app_runtime.py` | 区分会话命令与世界命令；处理登录会话，向 World 投递已认证命令。 |
| `server/app/game_runtime.py` | 按固定 `dt` 推进 World，并发布每个 `TickResult`。 |
| `server/transport/websocket_server.py` | 管理连接、收发二进制包和连接关闭生命周期，不执行游戏规则。 |
| `server/transport/connection_registry.py` | 保存连接上下文以及连接与认证身份、玩家实体的绑定。 |
| `server/transport/outbound_queue.py` | 编码服务端包络并按接收连接排队。 |
| `server/transport/game_protocol_adapter.py` | 把领域 Event/快照投影为服务端 Protobuf 消息。 |
| `server/protocol/codec.py` | 编解码方向明确的 Protobuf 包络。 |
| `server/protocol/contract.py` | 校验协议字段、必填值和数值范围，不判断世界状态。 |
| `server/protocol/router.py` | 将一种客户端 payload 路由到唯一 Handler。 |
| `server/protocol/handlers/` | 只把协议消息和连接身份转换成 Command。 |
| `server/game/world.py` | 唯一持有实体、待处理命令和权威 tick 状态。 |
| `server/game/commands.py` | 定义不携带网络对象的会话/世界意图数据。 |
| `server/game/events.py` | 定义 World 输出的瞬时领域事件和只读快照。 |
| `server/game/command_router.py` | 将 WorldCommand 分配给唯一所属 System。 |
| `server/game/tick_pipeline.py` | 以固定顺序执行命令和 System 更新。 |
| `server/game/systems/comp_system.py` | 校验领域规则、修改组件并产生领域 Event。 |
| `server/game/model/` | 定义实体、组件以及只读配置模型。 |
| `server/game/entity_projector.py` | 将内部实体投影成不暴露组件引用的快照。 |
| `server/game/tools/` | 提供不持有 World 状态的纯计算工具。 |
| `server/proto/generated/` | Protobuf Python 生成物，禁止手改。 |

## 客户端

| 文件或目录 | 唯一职责 |
| --- | --- |
| `client/Scirpt/app/GameBootstrap.gd` | 初始化客户端依赖并根据快照切换游戏场景。 |
| `client/Scirpt/net/WebSocketTransport.gd` | 轮询 WebSocket、发送和接收编码后的包。 |
| `client/Scirpt/net/ProtocolCodec.gd` | 构建客户端 Protobuf 请求包络。 |
| `client/Scirpt/net/ServerMessageRouter.gd` | 将一种服务端 payload 路由给唯一 Handler。 |
| `client/Scirpt/net/handlers/` | 把服务端消息交给同步器或会话信号，不修改场景节点。 |
| `client/Scirpt/state/GameStore.gd` | 保存服务端权威世界的客户端镜像。 |
| `client/Scirpt/state/EntityState.gd` | 保存单个实体的权威镜像字段。 |
| `client/Scirpt/state/ClientSession.gd` | 保存登录成功后的本地会话身份。 |
| `client/Scirpt/state/SignalMgr.gd` | 在状态同步与表现层之间提供类型化通知。 |
| `client/Scirpt/game/world/ClientWorldSynchronizer.gd` | 按 tick 顺序调用 reducer 并发出表现通知。 |
| `client/Scirpt/game/reducer/` | 只根据服务端消息更新 Store。 |
| `client/Scirpt/game/system/EntityViewFactory.gd` | 根据 EntityState 创建实体表现。 |
| `client/Scirpt/game/controller/LocalPlayerController.gd` | 采样输入并只发送 `MoveIntent`。 |
| `client/Scirpt/game/view/` | 插值和播放纯客户端表现，不决定权威结果。 |
| `client/Scirpt/game/level/` | 持有本关卡实体视图并响应状态变化信号。 |
| `client/Scirpt/ui/` | 显示会话/权威状态并发送用户请求。 |
| `client/Scirpt/proto/game_proto.gd` | Protobuf GDScript 生成物，禁止手改。 |

## 登录为什么不进入 GameWorld

`LoginRequest` 到达时，连接已经存在，但玩家实体还不存在。这是正常状态。登录只认证连接身份，因此走会话命令路径：

```text
LoginRequest
→ login_handle（只构造 LoginCommand）
→ AppRuntime.on_session_command
→ ConnectionRegistry 绑定 account/player_name
→ LoginAccepted
```

成功登录之后，进入游戏才走权威世界路径：

```text
EnterGameRequest
→ game_handler（构造 JoinCommand，调用者身份来自 ConnectionContext）
→ AppRuntime.on_world_command（检查已登录）
→ GameWorld.enqueue_command
→ JoinCompSystem
→ EntityJoinedEvent
→ GameProtocolAdapter
→ WorldSnapshot / EntitySpawned
```

因此 `Command` 是应用意图的统称，不等于必须修改 World。`SessionCommand` 修改会话状态，`WorldCommand` 才能进入 `GameWorld`。

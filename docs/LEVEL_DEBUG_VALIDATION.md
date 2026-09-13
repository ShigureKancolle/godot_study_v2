# 生存模式调试消息与阶段计时验收

日期：2026-09-13。

## 修复范围

`GameWorld._debug_data()` 原先把可变的 `SpawnBudgetData` 对象放进领域快照的 `budget` 字段，导致 Protobuf 构造 `EnemyBudgetData` 时抛出 `TypeError`。改为采集 `budget_data.budget` 数值，领域快照保留浮点精度。

当前协议中的预算、阶段秒数和刷怪倒计时均为 `uint64`。协议投影时显式截去小数部分，刷怪倒计时小于零时发送零；不修改内部预算或时钟，不修改协议和生成代码。客户端预算显示暂不包含小数。

阶段计时原先用系统时间减去持续推进的玩法时间，正常运行时差值接近零，暂停后反而包含暂停时长。现在由 `SurvivalMode._init_stage()` 记录 `_stage_start_timestamp_ms`，调试字段使用玩法时间减去阶段起点计算整数秒。阶段切换重新记录起点，暂停期间不累计时间。进入阶段不足一秒时，零值仍按 proto3 默认规则省略显示，客户端读取值为零。

## 环境及命令

Windows PowerShell；Python 3.12.14；protobuf 6.33.5；websockets 15.0.1。测试依赖安装在项目临时目录，未修改用户的 Python 安装。

在仓库根目录执行：

```powershell
$env:PYTHONPATH = 'D:/work/godot_demo_v2/.tmp/level_debug_validation/deps'
Set-Location -LiteralPath 'D:/work/godot_demo_v2/server'
& 'C:/Users/王钰玲/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -X utf8 -B -m unittest discover -s tests -p test_level_debug.py -v
```

## 结果

| 项目 | 状态 | 证据 |
| --- | --- | --- |
| 修复前复现 | 失败（预期） | 相同测试复现 `SpawnBudgetData` 对象无法作为整数，以及后续浮点数无法作为整数的异常；`.tmp/level_debug_validation/before.log` |
| 调试快照预算采集 | 通过 | 采集 12.75 后修改模式中的预算为 99，已采集快照仍为 12.75，未携带可变对象引用 |
| 浮点数据编码及解码 | 通过 | 预算 12.75、阶段秒数 10.9、倒计时 987.9，分别按现有协议编码为 12、10、987；完整 `ServerMessage` 往返成功 |
| 到期倒计时 | 通过 | -33.3、-0.1、0.0 均成功序列化为零 |
| 连续帧及房间投递 | 通过 | 真实 `SurvivalMode` 与 `GameWorld` 连续推进 360 帧；每帧调试消息成功编码并入队；同房间两个模拟连接收到投递，其他房间不接收；第 360 帧的普通移动消息仍成功发布 |
| 阶段计时修复前复现 | 失败（预期） | 新增 3 个测试全部复现错误：玩法推进后秒数仍为零、暂停后秒数包含暂停时长、第二阶段秒数不增长；`.tmp/level_debug_validation/stage_time_before.log` |
| 阶段计时增长和协议显示 | 通过 | 推进 2.5 秒后字段为 2；系统时间再跳变一小时，字段仍为 2；Protobuf 编解码后值为 2，文本日志包含 `stage_time_seconds: 2` |
| 暂停和恢复 | 通过 | 玩法推进 1.25 秒后暂停 30 秒，恢复时字段为 1，再推进 0.75 秒后为 2；沿用现有暂停期间不产生调试事件的行为 |
| 阶段切换 | 通过 | 真实推进至第一阶段到期，第二阶段字段从零开始；再推进 2.25 秒后为 2 |
| Godot 客户端和真实双客户端联调 | 未执行 | 本次验证边界为服务端采集、投影、编码和出站队列；模拟连接未建立真实 WebSocket，也未验证客户端 UI |

最新 7 个测试全部通过，日志：`.tmp/level_debug_validation/stage_time_after.log`。此前类型修复的 4 个测试结果保留在 `.tmp/level_debug_validation/after.log`。测试代码：`server/tests/test_level_debug.py`。只执行阶段计时的 3 个用例时，在上述命令中增加 `-k stage_time`。

## 客户端接入静态检查

当前 `HandlerRegister.register()` 已把 `level_debug_data` 注册到 `GameHandler.on_level_debug()`。本次阶段计时修复未修改客户端；上述结论来自代码检查，不代表已经执行 Godot UI 或真实双客户端联调。

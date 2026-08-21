# godot_study_v2
重构study，纯手写重构加深印象。

这是一个吸血鬼幸存者玩法的游戏，有无限拓展的随机地图，敌人离玩家太远会被瞬移到玩家行进方向的屏幕外。

## Protobuf 协议

`protocol/game.proto` 是唯一可编辑的协议源。不要修改 Python 或 GDScript 生成文件。

修改协议后，在仓库根目录执行：

```powershell
.\tools\sync_proto.ps1 -GodotExecutable "C:\path\to\Godot.exe"
```

也可以把 Godot 路径配置为环境变量 `GODOT_BIN`。提交前执行
`.\tools\check_proto_sync.ps1`，它会重新生成并检查生成物是否被漏提交或手改。

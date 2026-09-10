extends SceneTree
## 使用实际角色场景、动画资源和 Presenter 验证死亡动画不会被后续移动覆盖。

const VISUAL_SCENE := preload("res://Prefab/Role/PlayerVisual.tscn")

var _failures: Array[String] = []
var _cases: Array[Dictionary] = []

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error(message)

func _run() -> void:
	create_timer(5.0).timeout.connect(func(): quit(2))
	for direction in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		var view := EntityView.new()
		view.entity_visual = VISUAL_SCENE.instantiate() as PlayerVisual
		view.add_child(view.entity_visual)
		root.add_child(view)
		var presenter := AnimationPresenter.new(view)
		var body := view.entity_visual.get_node("Body") as AnimatedSprite2D
		presenter.update_facing(direction)
		presenter.play_anim("run")
		_check(String(body.animation).ends_with("_Run"), "存活时仍能正常播放跑步动画")
		var expected := String(body.animation).replace("_Run", "_Die")
		var item := {"view": view, "presenter": presenter, "body": body, "expected": expected, "finished": 0}
		body.animation_finished.connect(func(): item["finished"] += 1)
		_cases.append(item)
		presenter.play_anim("die")
		_check(body.animation == expected, "死亡事件必须立即开始死亡动画：" + expected)

	# 对应服务端先击杀、下一 tick 才停止移动的真实事件顺序。
	await create_timer(1.0 / 30.0).timeout
	for item in _cases:
		var presenter: AnimationPresenter = item["presenter"]
		presenter.play_anim("idle")
		presenter.play_anim("run")
		_check(item["body"].animation == item["expected"], "后续停止和跑步事件不能覆盖死亡动画")

	# 模拟位置插值尚未收敛时，每帧继续提供不同移动方向。
	for direction in [Vector2.LEFT, Vector2.UP, Vector2.RIGHT, Vector2.DOWN]:
		for item in _cases:
			item["presenter"].update_facing(direction)
		await create_timer(1.0 / 30.0).timeout
	for item in _cases:
		var body: AnimatedSprite2D = item["body"]
		_check(body.animation == item["expected"], "死亡后的方向变化不能切换死亡动画")
		_check(body.frame > 0, "死亡动画必须继续推进帧数")
		var old_frame := body.frame
		item["presenter"].play_anim("die")
		_check(body.frame == old_frame, "重复死亡通知不能重播动画")

	await create_timer(0.7).timeout
	for item in _cases:
		var body: AnimatedSprite2D = item["body"]
		_check(item["finished"] == 1, "死亡动画必须完整播放且只结束一次")
		_check(body.animation == item["expected"], "播放完毕后保留死亡姿势")
		_check(not body.is_playing(), "死亡动画不能循环")
		_check(body.frame == body.sprite_frames.get_frame_count(body.animation) - 1, "保留死亡动画最后一帧")
		print(item["expected"], " frame=", body.frame, " finished=", item["finished"])
		item["presenter"] = null
		item["view"].queue_free()
	_cases.clear()
	await process_frame
	print("Death animation tests: ", "PASS" if _failures.is_empty() else "FAIL")
	quit(0 if _failures.is_empty() else 1)

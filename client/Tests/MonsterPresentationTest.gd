extends SceneTree
## 在现有客户端工程中验收怪物资源、攻击时序、死亡优先级和网络同步。

const GameProto := preload("res://Scirpt/proto/game_proto.gd")
const KEYS: Array[String] = ["enemy_slime", "enemy_skeleton", "enemy_runner", "enemy_elite", "enemy_boss"]
const ATTACKS: Array[int] = [1001, 1001, 2001, 2002, 2003]
var failures: Array[String] = []
var checks: int = 0
var views: Dictionary = {}
var store := GameStore.new()
var sync: ClientWorldSynchronizer
var received_attacks: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _argument(prefix: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return ""

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		push_error(description)

func _state(key: String) -> EntityState:
	var info := GameProto.EntityInfo.new()
	info.set_entity_id(key)
	info.set_entity_config_key(key)
	info.set_entity_type(2)
	info.set_facing_y(1.0)
	info.set_anim_state("idle")
	var combat: GameProto.CombatEntityInfo = info.new_combat_entity_info()
	combat.set_entity_id(key)
	combat.set_hp(100)
	combat.set_max_hp(100)
	return EntityState.from_entity_info(info)

func _view(state: EntityState) -> EntityView:
	var view: EntityView = EntityViewFactory.create_entity_view(state)
	root.add_child(view)
	view.setup(state)
	view.set_process(false)
	view.entity_visual.set_process(false)
	return view

func _run() -> void:
	var network_url: String = _argument("--network-url=")
	if not network_url.is_empty():
		await _network_test(network_url)
	else:
		_test_config()
		_test_monsters()
		await _test_live_playback()
		var capture: String = _argument("--capture=")
		if not capture.is_empty():
			await _gallery(capture)
	print("MONSTER_TEST_RESULT " + JSON.stringify({"checks": checks, "failures": failures, "received_attacks": received_attacks}))
	await process_frame
	quit(0 if failures.is_empty() else 1)

func _test_config() -> void:
	var reward: Dictionary = ConfigLoader.get_reward_config()
	_check(reward.rewards.size() == 7, "客户端应读取七种奖励定义")
	reward.progression.next_level_xp[0] = 999
	_check(ConfigLoader.get_reward_config().progression.next_level_xp[0] == 12, "奖励缓存必须隔离调用方修改")
	var survival: Dictionary = ConfigLoader.get_survival_config()
	var total: float = 0.0
	for stage in survival.stages:
		total += stage.duration_seconds
	_check(total == 780.0, "八阶段总时长应为 780 秒")
	survival.stages[7].entry_spawn.enemy_type = "invalid"
	_check(ConfigLoader.get_survival_stage(8).entry_spawn.enemy_type == "enemy_boss", "阶段缓存必须隔离调用方修改")
	for attack_id in [1001, 1002, 1003, 1004, 2001, 2002, 2003]:
		var effect: Node2D = AttackEffectFactory.create_attack_effect(attack_id)
		_check(effect != null, "所有攻击都有表现入口: %d" % attack_id)
		if effect != null:
			effect.free()
	var double_attack: ConfigLoader.AttackConfig = ConfigLoader.get_attack_config(1002)
	_check(double_attack.get_attack_time() == 1166 and double_attack.shape_list[1].hit_time == 666, "连击使用从攻击开始累计的绝对毫秒")
	var rect: ConfigLoader.RectParams = ConfigLoader.get_attack_config(1004).shape_list[0].shape_params
	_check(rect.length > 0 and rect.width > 0, "矩形攻击必须加载 length 和 width")

func _test_monsters() -> void:
	for index in range(KEYS.size()):
		var key: String = KEYS[index]
		var view: EntityView = _view(_state(key))
		_check(view.entity_visual is MonsterVisual, "使用专属怪物表现: " + key)
		var visual := view.entity_visual as MonsterVisual
		var body: AnimatedSprite2D = visual.get_node("Body")
		var frames: SpriteFrames = body.sprite_frames
		_check(frames.get_animation_names().size() == 20, "四方向五状态齐全: " + key)
		for state in MonsterAnimationLibrary.STATES:
			for direction in MonsterAnimationLibrary.DIRECTIONS:
				var animation := StringName(direction + "_" + state)
				_check(frames.get_frame_count(animation) == 4, "四帧动作: " + key + "/" + animation)
				_check(frames.get_animation_loop(animation) == (state in ["Idle", "Run"]), "单次动作不能循环: " + animation)
				for frame in range(4):
					var texture: Texture2D = frames.get_frame_texture(animation, frame)
					var bitmap: Image = texture.get_image()
					_check(bitmap != null and bitmap.get_used_rect().has_area(), "图集帧不能为空: %s/%s/%d" % [key, animation, frame])
		var animator := view.get_presenter(AnimationPresenter.presenter_name) as AnimationPresenter
		var attack: ConfigLoader.AttackConfig = ConfigLoader.get_attack_config(ATTACKS[index])
		var hit: float = attack.shape_list[0].hit_time
		view.apply_attack_start(ATTACKS[index], 0.0)
		_check(body.animation == &"Right_Attack", "攻击朝向使用权威攻击角度: " + key)
		animator.play_anim("run")
		animator.update_facing(Vector2.UP)
		view.apply_damage_received(1)
		_check(body.animation == &"Right_Attack", "移动与受击不能打断攻击时序: " + key)
		visual._process((hit - 1.0) / 1000.0)
		_check(body.frame == 1, "命中前仍为蓄力帧: " + key)
		visual._process(0.002)
		_check(body.frame == 2, "命中时切换出手帧: " + key)
		animator.process(attack.get_attack_time() / 1000.0 + 0.01)
		_check(body.animation == &"Up_Run", "攻击结束恢复缓存的移动方向: " + key)
		var effect := AttackEffectFactory.create_attack_effect(ATTACKS[index], true) as ConfiguredAttackEffect
		_check(effect.attack_config == attack, "预警直接使用攻击配置: " + key)
		effect._process(attack.get_attack_time() / 1000.0 + 0.01)
		_check(effect._finished, "攻击结束必须释放特效: " + key)
		effect.free()
		view.play_dead_animation()
		view.apply_attack_start(ATTACKS[index], 0.0)
		animator.play_anim("run")
		animator.update_facing(Vector2.DOWN)
		_check(body.animation == &"Up_Die" and visual._atk_effects.is_empty(), "死亡锁定方向并清理攻击: " + key)
		var death_seconds: float = 4.0 / frames.get_animation_speed(&"Up_Die")
		_check(death_seconds < ConfigLoader.get_capability(key).dead_duration_ms / 1000.0, "死亡动作应在服务端移除前播完: " + key)
		view.free()
	var dead_state: EntityState = _state("enemy_slime")
	dead_state.combat_entity_state.dead = true
	var dead_view: EntityView = _view(dead_state)
	_check((dead_view.entity_visual.get_node("Body") as AnimatedSprite2D).animation == &"Down_Die", "快照中已死亡的怪物直接显示死亡")
	dead_view.free()

func _test_live_playback() -> void:
	var live_views: Array[EntityView] = []
	for key in KEYS:
		var view: EntityView = _view(_state(key))
		view.entity_visual.play_anim("Right_Run")
		live_views.append(view)
	await create_timer(0.25).timeout
	for view in live_views:
		var body := view.entity_visual.get_node("Body") as AnimatedSprite2D
		_check(body.frame > 0 and body.is_playing(), "引擎实际推进奔跑帧: " + view.entity_id)
		view.play_dead_animation()
	await create_timer(0.7).timeout
	for view in live_views:
		var body := view.entity_visual.get_node("Body") as AnimatedSprite2D
		_check(body.frame == 3 and not body.is_playing(), "引擎实际播完死亡并停在末帧: " + view.entity_id)
		view.free()

func _label(text: String, position: Vector2, font_size: int = 20) -> void:
	var label := Label.new()
	label.text = text
	label.position = position
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("d4deef"))
	root.add_child(label)

func _gallery(path: String) -> void:
	root.size = Vector2i(1500, 1190)
	var background := ColorRect.new()
	background.color = Color("111722")
	background.size = Vector2(1500, 1190)
	root.add_child(background)
	_label("MONSTER ANIMATION LIBRARY", Vector2(40, 22), 32)
	_label("5 creatures / 4 directions / 5 actions / 400 frames", Vector2(40, 66), 19)
	for column in range(5):
		_label(MonsterAnimationLibrary.STATES[column].to_upper(), Vector2(230 + column * 258, 120))
	for row in range(5):
		_label(KEYS[row].trim_prefix("enemy_").to_upper(), Vector2(35, 207 + row * 190), 19)
		_label("hit %d ms" % ConfigLoader.get_attack_config(ATTACKS[row]).shape_list[0].hit_time, Vector2(35, 237 + row * 190), 15)
		for column in range(5):
			var visual := EntityViewFactory.MONSTER_VISUAL_SCENE.instantiate() as MonsterVisual
			visual.configure(KEYS[row])
			root.add_child(visual)
			visual.position = Vector2(258 + column * 258, 227 + row * 190)
			visual.set_process(false)
			visual.get_node("NameLabel").hide()
			var body := visual.get_node("Body") as AnimatedSprite2D
			body.animation = StringName("Right_" + MonsterAnimationLibrary.STATES[column])
			body.stop()
			body.frame = 3 if column == 4 else 1
			if column == 2:
				var effect := AttackEffectFactory.create_attack_effect(ATTACKS[row], true) as ConfiguredAttackEffect
				visual.add_child(effect)
				effect.set_process(false)
				effect.elapsed_ms = effect.attack_config.shape_list[0].hit_time * 0.85
				effect.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	_check(image != null and not image.is_empty(), "真实渲染截图不能为空")
	if image != null and not image.is_empty():
		_check(image.save_png(path) == OK, "保存怪物动画验收图")

func _network_test(url: String) -> void:
	sync = ClientWorldSynchronizer.new(store)
	SignalMgr.Get().snl_attack_start.connect(_network_attack)
	var peer := WebSocketPeer.new()
	_check(peer.connect_to_url(url) == OK, "连接联调服务")
	var started: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < 20000:
		peer.poll()
		while peer.get_available_packet_count() > 0:
			var envelope := GameProto.ServerMessage.new()
			_check(envelope.from_bytes(peer.get_packet()) == GameProto.PB_ERR.NO_ERRORS, "解码真实服务端二进制协议")
			match envelope.get_payload_case():
				GameProto.ServerMessage.PayloadCase.WORLD_SNAPSHOT:
					sync.apply_world_snapshot(envelope.get_world_snapshot())
					_check(store.entities.size() == 5, "完整快照包含五种怪物")
					for state: EntityState in store.all_entities():
						views[state.entity_id] = _view(state)
						_check(state.entity_config_key in KEYS and views[state.entity_id].entity_visual is MonsterVisual, "快照正确恢复怪物外观")
				GameProto.ServerMessage.PayloadCase.WORLD_FRAME:
					sync.apply_world_frame(envelope.get_server_tick(), envelope.get_world_frame())
		if received_attacks == 5:
			peer.send_text(JSON.stringify({"checks": checks, "failures": failures, "monsters": store.entities.size(), "attacks": received_attacks}))
			await create_timer(0.1).timeout
			break
		await process_frame
	_check(received_attacks == 5, "限时收到五个攻击事件")
	peer.close()
	for view: EntityView in views.values():
		view.free()
	views.clear()

func _network_attack(entity_id: String, attack_id: int, facing: float) -> void:
	_check(views.has(entity_id), "攻击者已有视图")
	if not views.has(entity_id):
		return
	var view: EntityView = views[entity_id]
	view.apply_attack_start(attack_id, facing)
	var body := view.entity_visual.get_node("Body") as AnimatedSprite2D
	_check(body.animation == &"Up_Attack", "两个客户端按权威角度播放攻击")
	var effects: Dictionary = view.entity_visual._atk_effects
	_check(effects.size() == 1 and effects.values()[0] is ConfiguredAttackEffect, "两个客户端均创建配置驱动的攻击预警")
	received_attacks += 1

extends EntityViewPresenter
class_name HpBarPresenter

static var presenter_name := &"HpBarPresenter"

var _hp_bar: MyProgressBar = null

func set_hp_bar(hp_bar: MyProgressBar):
    _hp_bar = hp_bar
    _hp_bar.set_type("hp")
    _hp_bar.position = Vector2(0, -40)

func update_hp_bar(hp: int, max_hp = null):
    if _hp_bar:
        if max_hp != null:
            _hp_bar.set_max(max_hp)
        _hp_bar.set_value(hp)

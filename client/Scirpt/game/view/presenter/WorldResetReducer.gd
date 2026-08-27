extends EntityViewPresenter
class_name WorldResetReducer

static var presenter_name := &"WorldResetReducer"

static func apply(store: GameStore) -> void:
	store.reset()

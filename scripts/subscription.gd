class_name Subscription
extends RefCounted

var _signals: Array[Signal] = []
var _callables: Array[Callable] = []


func add(sig: Signal, callable: Callable) -> void:
	sig.connect(callable)
	_signals.append(sig)
	_callables.append(callable)


func clear_all() -> void:
	for i in _signals.size():
		if _signals[i].is_connected(_callables[i]):
			_signals[i].disconnect(_callables[i])
	_signals.clear()
	_callables.clear()

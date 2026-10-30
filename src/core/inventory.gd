class_name Inventory
extends RefCounted
signal changed
var amounts: Array[int] = [0, 30, 0, 0, 0]
var selected := 1
func add(id: int, count: int = 1) -> bool:
	if id < 1 or id >= amounts.size() or count < 0 or amounts[id] + count > Blocks.STACK_LIMIT:
		return false
	amounts[id] += count
	changed.emit()
	return true
func take(id: int) -> bool:
	if id < 1 or id >= amounts.size() or amounts[id] <= 0:
		return false
	amounts[id] -= 1
	changed.emit()
	return true
func restore(data: Array) -> bool:
	if data.size() != 5: return false
	for value in data:
		if not (value is float or value is int) or value < 0 or value > Blocks.STACK_LIMIT or value != int(value): return false
	amounts.assign(data)
	changed.emit()
	return true

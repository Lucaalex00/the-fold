extends Node

# Run with: add TestRunner.tscn as autostart scene, check Output panel
# Each test suite must implement run_tests() -> Array[Dictionary]
# Each result: { "name": String, "passed": bool, "message": String }

const TEST_SUITES = [
	"res://tests/test_game_state.gd",
	"res://tests/test_omino_system.gd",
	"res://tests/test_culture_system.gd",
	"res://tests/test_genetic_system.gd",
	"res://tests/test_prestige_system.gd",
	"res://tests/test_localization.gd",
]

var _total: int = 0
var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	print("\n====== THE FOLD — TEST RUNNER ======")
	for suite_path in TEST_SUITES:
		_run_suite(suite_path)
	_print_summary()
	# In CI/export context: quit with error code if tests fail
	if _failed > 0:
		get_tree().quit(1)


func _run_suite(path: String) -> void:
	var script = load(path)
	if script == null:
		print("[ERROR] Cannot load: " + path)
		return
	var suite = script.new()
	suite.name = path.get_file().get_basename()
	add_child(suite)

	print("\n--- " + suite.name + " ---")
	var results: Array = suite.run_tests()

	for result in results:
		_total += 1
		var icon = "✓" if result["passed"] else "✗"
		var msg = result.get("message", "")
		print("  %s %s%s" % [icon, result["name"], (" — " + msg) if msg != "" else ""])
		if result["passed"]:
			_passed += 1
		else:
			_failed += 1

	suite.queue_free()


func _print_summary() -> void:
	print("\n====== RESULTS: %d/%d passed (%d failed) ======\n" % [_passed, _total, _failed])

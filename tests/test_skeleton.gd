extends GutTest
## WO-0.1 smoke test: proves the toolchain runs green and the EventBus autoload
## is wired up. Replaced/expanded by real logic tests in later work orders.


func test_toolchain_runs():
	assert_true(true, "GUT is installed and executing tests")


func test_event_bus_autoload_present():
	assert_not_null(EventBus, "EventBus autoload should be available globally")


func test_event_bus_declares_core_signals():
	assert_true(EventBus.has_signal("unit_died"), "EventBus has unit_died")
	assert_true(EventBus.has_signal("battle_won"), "EventBus has battle_won")
	assert_true(EventBus.has_signal("support_rank_up"), "EventBus has support_rank_up")

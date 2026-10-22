extends SceneTree

func _initialize() -> void:
	print("--- Running Full Test Suite Discovery ---")
	var dir = DirAccess.open("res://tests/")
	if not dir:
		printerr("Cannot open res://tests/")
		quit(1)
		return
		
	var test_files: Array[String] = []
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.begins_with("test_") and file_name.ends_with(".gd") and file_name != "test_signal.gd":
			test_files.append("res://tests/" + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	test_files.sort()
	
	print("Found %d test suites to execute." % test_files.size())
	
	var total_suites_passed = 0
	var total_suites_failed = 0
	var total_tests_passed = 0
	var total_tests_failed = 0
	var failed_details: Array[Dictionary] = []
	
	for path in test_files:
		var script = load(path)
		if not script:
			printerr("[SUITE LOAD ERROR] Could not load: %s" % path)
			total_suites_failed += 1
			continue
			
		var suite = script.new()
		if not (suite is McpTestSuite):
			print("Skipping non-McpTestSuite: %s" % path)
			continue
			
		var s_name = suite.suite_name() if suite.has_method("suite_name") else path
		var methods: Array[String] = []
		for m in suite.get_method_list():
			if m["name"].begins_with("test_"):
				methods.append(m["name"])
		methods.sort()
		
		print("\n▶ Running Suite: %s (%d tests) [%s]" % [s_name, methods.size(), path.get_file()])
		var suite_had_failure = false
		
		for method_name in methods:
			suite._reset()
			suite.setup()
			suite.call(method_name)
			suite.teardown()
			suite._free_tracked()
			
			if suite._failed:
				print("   ✖ FAIL: %s -> %s" % [method_name, suite._message])
				total_tests_failed += 1
				suite_had_failure = true
				failed_details.append({"suite": s_name, "test": method_name, "message": suite._message})
			elif suite._skipped:
				print("   - SKIP: %s -> %s" % [method_name, suite._skip_reason])
			else:
				print("   ✔ PASS: %s (%d assertions)" % [method_name, suite._assertion_count])
				total_tests_passed += 1
				
		if suite_had_failure:
			total_suites_failed += 1
		else:
			total_suites_passed += 1
			
	print("\n=======================================================")
	print("FINAL RESULTS: %d suites passed, %d suites failed" % [total_suites_passed, total_suites_failed])
	print("TESTS: %d passed, %d failed" % [total_tests_passed, total_tests_failed])
	if not failed_details.is_empty():
		print("\nFAILED TESTS LIST:")
		for item in failed_details:
			print("  ✖ [%s] %s: %s" % [item["suite"], item["test"], item["message"]])
	print("=======================================================")
	quit(1 if total_tests_failed > 0 or total_suites_failed > 0 else 0)

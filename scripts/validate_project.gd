extends SceneTree

const Catalog := preload("res://scripts/demo_catalog.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failed := false
	failed = not _validate_catalog() or failed
	failed = not _validate_main_scene() or failed
	failed = not _validate_glbs() or failed
	failed = not await _validate_fpe_runtime() or failed
	if failed:
		quit(1)
	else:
		print("FPE Rush validation passed.")
		quit(0)

func _validate_catalog() -> bool:
	var ok := true
	if Catalog.DEMOS.size() != 16:
		push_error("Expected 16 demos, found %s." % Catalog.DEMOS.size())
		ok = false
	var seen := {}
	for demo in Catalog.DEMOS:
		for key in ["id", "number", "title", "concept", "blurb", "event", "metadata"]:
			if not demo.has(key) or str(demo[key]).is_empty():
				push_error("Demo is missing %s: %s" % [key, demo])
				ok = false
		if seen.has(demo.id):
			push_error("Duplicate demo id: %s" % demo.id)
			ok = false
		seen[demo.id] = true
	return ok

func _validate_main_scene() -> bool:
	var packed := load("res://scenes/main.tscn")
	if packed == null:
		push_error("Could not load main scene.")
		return false
	var instance: Node = packed.instantiate()
	if instance == null:
		push_error("Could not instantiate main scene.")
		return false
	instance.free()
	return true

func _validate_glbs() -> bool:
	var ok := true
	for demo in Catalog.DEMOS:
		var path := Catalog.glb_path(demo)
		if not FileAccess.file_exists(path):
			push_error("Missing GLB: %s" % path)
			ok = false
			continue
		var packed := load(path)
		if packed == null:
			push_error("Godot could not load GLB: %s" % path)
			ok = false
			continue
		var instance: Node = packed.instantiate()
		if instance == null:
			push_error("Godot could not instantiate GLB: %s" % path)
			ok = false
			continue
		var extras := UserDataUtils.get_user_data(instance)
		if not extras.has("fpe_scene_context_props") or not extras.has("fpe_scene_events_context_props"):
			push_error("Root scene extras missing for %s." % path)
			ok = false
		if not _has_any_fpe_object_metadata(instance):
			push_error("No child FPE object metadata found in %s." % path)
			ok = false
		instance.free()
	return ok

func _has_any_fpe_object_metadata(node: Node) -> bool:
	var extras := UserDataUtils.get_user_data(node)
	for key in extras.keys():
		if str(key).begins_with("fpe_") and key != "fpe_scene_context_props" and key != "fpe_scene_events_context_props":
			return true
	for child in node.get_children():
		if _has_any_fpe_object_metadata(child):
			return true
	return false

func _validate_fpe_runtime() -> bool:
	var ok := true
	var environment_node := WorldEnvironment.new()
	environment_node.environment = Environment.new()
	root.add_child(environment_node)
	InventoryUtils.register_inventory_type_size(
		InventoryConstants.INVENTORY_TYPES.PLAYER,
		InventorySize.new({"width": 4, "height": 2}),
	)

	for demo in Catalog.DEMOS:
		var stage := Node3D.new()
		stage.name = "ValidationStage"
		root.add_child(stage)
		var feature_utils: FeatureUtils = GLTFModelUtils.load_gltf_scene(
			Catalog.glb_path(demo),
			stage,
			environment_node,
		)
		await process_frame
		if feature_utils == null or feature_utils.FPE_GLOBALS.CURRENT_LOADED_ROOT == null:
			push_error("FPE runtime load failed for %s." % demo.id)
			ok = false
		elif feature_utils.FPE_GLOBALS.SCENE_CAMERAS.is_empty():
			push_error("FPE found no cameras for %s." % demo.id)
			ok = false
		GLTFModelUtils.clear_scene(feature_utils, stage, true)
		await process_frame
		await process_frame
		stage.free()

	environment_node.free()
	InventoryUtils.clean_up()
	return ok

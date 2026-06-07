extends Node

const Catalog := preload("res://scripts/demo_catalog.gd")
const PaperKeepsake := preload("res://demos/inventory/paper_keepsake.tres")

var _engine: FoldedPaperEngine
var _conversation_manager: FPEConversationManager
var _inventory_config: FPEInventoryConfig
var _selected_index := 0
var _cards: Array[Button] = []
var _title_label: Label
var _concept_label: Label
var _description_label: Label
var _metadata_label: Label
var _status_label: Label
var _activate_button: Button
var _loading := false

func _ready() -> void:
	_build_world_environment()
	_build_fpe_support()
	_build_engine()
	_build_interface()
	_connect_events()
	_select_demo(0, false)

func _build_world_environment() -> void:
	var environment_node := WorldEnvironment.new()
	environment_node.name = "WorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#e9ddc8")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#fff1d8")
	environment.ambient_light_energy = 1.15
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment_node.environment = environment
	add_child(environment_node)

func _build_engine() -> void:
	_engine = FoldedPaperEngine.new()
	_engine.name = "FoldedPaperEngine"
	_engine.capture_pointer = false
	_engine.path = Catalog.glb_path(Catalog.DEMOS[0])
	_engine.environment = get_node("WorldEnvironment")
	add_child(_engine)

func _build_fpe_support() -> void:
	_conversation_manager = FPEConversationManager.new()
	_conversation_manager.name = "ConversationManager"
	add_child(_conversation_manager)

	var inventory_size := InventorySize.new({"width": 4, "height": 2})
	_inventory_config = FPEInventoryConfig.new()
	_inventory_config.name = "InventoryConfig"
	_inventory_config.inventory_kinds = [PaperKeepsake]
	_inventory_config.player_inventory_size = inventory_size
	_inventory_config.keep_player_inventory = true
	add_child(_inventory_config)

func _build_interface() -> void:
	var layer := CanvasLayer.new()
	layer.name = "GalleryUI"
	add_child(layer)

	var root := MarginContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 28)
	root.add_theme_constant_override("margin_top", 24)
	root.add_theme_constant_override("margin_right", 28)
	root.add_theme_constant_override("margin_bottom", 24)
	layer.add_child(root)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 22)
	root.add_child(columns)

	var library_panel := PanelContainer.new()
	library_panel.custom_minimum_size = Vector2(410, 0)
	library_panel.add_theme_stylebox_override("panel", _panel_style(Color("#f8f0dfdd"), 24, Color("#6e5b4b33")))
	columns.add_child(library_panel)

	var library_margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		library_margin.add_theme_constant_override("margin_%s" % side, 22)
	library_panel.add_child(library_margin)

	var library := VBoxContainer.new()
	library.add_theme_constant_override("separation", 12)
	library_margin.add_child(library)

	var brand := Label.new()
	brand.text = "FPE RUSH!"
	brand.add_theme_font_size_override("font_size", 30)
	brand.add_theme_color_override("font_color", Color("#4b3c34"))
	library.add_child(brand)

	var subtitle := Label.new()
	subtitle.text = "16 tiny Folded Paper Engine field trips"
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color("#7d6a5a"))
	library.add_child(subtitle)

	var rule := HSeparator.new()
	rule.modulate = Color("#bca88f")
	library.add_child(rule)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	library.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)

	for index in Catalog.DEMOS.size():
		var demo: Dictionary = Catalog.DEMOS[index]
		var card := Button.new()
		card.text = "%s  %s\n%s" % [demo.number, demo.title, demo.concept]
		card.alignment = HORIZONTAL_ALIGNMENT_LEFT
		card.custom_minimum_size = Vector2(172, 70)
		card.focus_mode = Control.FOCUS_ALL
		card.add_theme_font_size_override("font_size", 13)
		card.add_theme_stylebox_override("normal", _panel_style(Color("#fffaf0"), 14, Color("#b8a58c55")))
		card.add_theme_stylebox_override("hover", _panel_style(demo.accent.lightened(0.28), 14, demo.accent))
		card.add_theme_stylebox_override("pressed", _panel_style(demo.accent.lightened(0.16), 14, demo.accent.darkened(0.15)))
		card.pressed.connect(_select_demo.bind(index, true))
		grid.add_child(card)
		_cards.append(card)

	var detail_panel := PanelContainer.new()
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_panel.add_theme_stylebox_override("panel", _panel_style(Color("#fffaf0e8"), 24, Color("#6e5b4b33")))
	columns.add_child(detail_panel)

	var detail_margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		detail_margin.add_theme_constant_override("margin_%s" % side, 26)
	detail_panel.add_child(detail_margin)

	var detail := VBoxContainer.new()
	detail.add_theme_constant_override("separation", 10)
	detail_margin.add_child(detail)

	var eyebrow := Label.new()
	eyebrow.text = "NOW VISITING"
	eyebrow.add_theme_font_size_override("font_size", 12)
	eyebrow.add_theme_color_override("font_color", Color("#9a7960"))
	detail.add_child(eyebrow)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 38)
	_title_label.add_theme_color_override("font_color", Color("#49382f"))
	detail.add_child(_title_label)

	_concept_label = Label.new()
	_concept_label.add_theme_font_size_override("font_size", 18)
	detail.add_child(_concept_label)

	_description_label = Label.new()
	_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description_label.add_theme_font_size_override("font_size", 16)
	_description_label.add_theme_color_override("font_color", Color("#66564a"))
	detail.add_child(_description_label)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail.add_child(spacer)

	var metadata_panel := PanelContainer.new()
	metadata_panel.add_theme_stylebox_override("panel", _panel_style(Color("#4c4038e8"), 15, Color.TRANSPARENT))
	detail.add_child(metadata_panel)
	var metadata_margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		metadata_margin.add_theme_constant_override("margin_%s" % side, 16)
	metadata_panel.add_child(metadata_margin)
	_metadata_label = Label.new()
	_metadata_label.add_theme_font_size_override("font_size", 14)
	_metadata_label.add_theme_color_override("font_color", Color("#fff4df"))
	_metadata_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	metadata_margin.add_child(_metadata_label)

	_status_label = Label.new()
	_status_label.text = "Loading authored GLB through FPE..."
	_status_label.add_theme_font_size_override("font_size", 13)
	_status_label.add_theme_color_override("font_color", Color("#816f61"))
	detail.add_child(_status_label)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	detail.add_child(actions)

	_activate_button = Button.new()
	_activate_button.text = "Activate FPE Demo"
	_activate_button.custom_minimum_size = Vector2(190, 48)
	_activate_button.add_theme_font_size_override("font_size", 16)
	_activate_button.add_theme_stylebox_override("normal", _panel_style(Color("#ef8f78"), 14, Color("#c86352")))
	_activate_button.add_theme_stylebox_override("hover", _panel_style(Color("#f4a18c"), 14, Color("#c86352")))
	_activate_button.pressed.connect(_activate_demo)
	actions.add_child(_activate_button)

	var reset := Button.new()
	reset.text = "Reset Scene"
	reset.custom_minimum_size = Vector2(130, 48)
	reset.add_theme_font_size_override("font_size", 15)
	reset.add_theme_stylebox_override("normal", _panel_style(Color("#f5e7cf"), 14, Color("#b49b7b")))
	reset.pressed.connect(_reload_demo)
	actions.add_child(reset)

	var footer := Label.new()
	footer.text = "WASD / mouse controls apply in player demos  •  Esc releases the pointer"
	footer.add_theme_font_size_override("font_size", 11)
	footer.add_theme_color_override("font_color", Color("#968273"))
	detail.add_child(footer)

func _panel_style(color: Color, radius: int, border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = border_color
	style.content_margin_left = 12
	style.content_margin_top = 10
	style.content_margin_right = 12
	style.content_margin_bottom = 10
	return style

func _connect_events() -> void:
	if FPEEventManager.GLOBAL_INSTANCE and not FPEEventManager.GLOBAL_INSTANCE.fpe_event.is_connected(_on_fpe_event):
		FPEEventManager.GLOBAL_INSTANCE.fpe_event.connect(_on_fpe_event)
	if not _conversation_manager.conversation_started.is_connected(_on_conversation_started):
		_conversation_manager.conversation_started.connect(_on_conversation_started)

func _select_demo(index: int, load_scene: bool) -> void:
	_selected_index = index
	var demo: Dictionary = Catalog.DEMOS[index]
	_title_label.text = "%s. %s" % [demo.number, demo.title]
	_concept_label.text = demo.concept
	_concept_label.add_theme_color_override("font_color", demo.accent.darkened(0.28))
	_description_label.text = demo.blurb
	_metadata_label.text = "BLENDER → GLTF EXTRAS → FPE\n%s" % demo.metadata
	for card_index in _cards.size():
		_cards[card_index].button_pressed = card_index == index
	if load_scene:
		_load_demo()

func _load_demo() -> void:
	if _loading:
		return
	_loading = true
	_activate_button.disabled = true
	var demo: Dictionary = Catalog.DEMOS[_selected_index]
	_status_label.text = "Loading %s through FoldedPaperEngine..." % demo.title
	FoldedPaperEngine.global_unload_level()
	await get_tree().process_frame
	_inventory_config._setup()
	FoldedPaperEngine.global_load_level(Catalog.glb_path(demo))
	await get_tree().process_frame
	_loading = false
	_activate_button.disabled = false
	_status_label.text = "Ready. Press Activate to dispatch “%s”." % demo.event

func _reload_demo() -> void:
	_load_demo()

func _activate_demo() -> void:
	if _loading or not FoldedPaperEngine.GLOBAL_FEATURE_UTILS:
		return
	var demo: Dictionary = Catalog.DEMOS[_selected_index]
	var owner := FoldedPaperEngine.GLOBAL_FEATURE_UTILS.FPE_GLOBALS.CURRENT_LOADED_ROOT
	var event := FPEEvent.new(demo.event, owner, owner, {"demo_id": demo.id})
	FoldedPaperEngine.GLOBAL_FEATURE_UTILS.EVENT_UTILS.dispatch_event(event)
	_status_label.text = "Dispatched FPE event “%s”." % demo.event

func _on_fpe_event(event: FPEEvent) -> void:
	if event and event.name != "ActivateDemo":
		_status_label.text = "FPE event observed: %s" % event.name

func _on_conversation_started(instance: ConversationInstance, manager: FPEConversationManager) -> void:
	if instance and instance.current_comment:
		_status_label.text = instance.current_comment.content
	manager.end()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

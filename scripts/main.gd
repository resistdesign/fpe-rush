extends Node

const Catalog := preload("res://scripts/demo_catalog.gd")
const PaperKeepsake := preload("res://demos/inventory/paper_keepsake.tres")
const FPELogo := preload("res://assets/branding/fpe-logo.png")

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
var _gallery_root: Control
var _open_button: Button
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
	environment.ambient_light_energy = 0.28
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 0.92
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

	_open_button = Button.new()
	_open_button.text = "FPE RUSH  •  OPEN GALLERY"
	_open_button.position = Vector2(18, 18)
	_open_button.custom_minimum_size = Vector2(230, 46)
	_open_button.add_theme_font_size_override("font_size", 13)
	_open_button.add_theme_color_override("font_color", Color("#fffaf0"))
	_open_button.add_theme_stylebox_override("normal", _panel_style(Color("#49382fee"), 14, Color("#fff4df44"), 12, 5))
	_open_button.add_theme_stylebox_override("hover", _panel_style(Color("#60493dee"), 14, Color("#ef9a8f"), 12, 6))
	_open_button.pressed.connect(_set_gallery_visible.bind(true))
	_open_button.hide()
	layer.add_child(_open_button)

	_gallery_root = MarginContainer.new()
	_gallery_root.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	_gallery_root.offset_left = 18
	_gallery_root.offset_top = 18
	_gallery_root.offset_right = 702
	_gallery_root.offset_bottom = -18
	layer.add_child(_gallery_root)

	var gallery_panel := PanelContainer.new()
	gallery_panel.add_theme_stylebox_override("panel", _panel_style(Color("#f8f0dff2"), 24, Color("#6e5b4b44"), 0, 14))
	_gallery_root.add_child(gallery_panel)

	var gallery_margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		gallery_margin.add_theme_constant_override("margin_%s" % side, 20)
	gallery_panel.add_child(gallery_margin)

	var gallery := VBoxContainer.new()
	gallery.add_theme_constant_override("separation", 12)
	gallery_margin.add_child(gallery)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	gallery.add_child(header)

	var logo := TextureRect.new()
	logo.texture = FPELogo
	logo.custom_minimum_size = Vector2(300, 82)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header.add_child(logo)

	var header_copy := VBoxContainer.new()
	header_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_copy.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_child(header_copy)

	var brand := Label.new()
	brand.text = "RUSH!"
	brand.add_theme_font_size_override("font_size", 28)
	brand.add_theme_color_override("font_color", Color("#49382f"))
	header_copy.add_child(brand)

	var subtitle := Label.new()
	subtitle.text = "16 tiny field trips"
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override("font_color", Color("#7d6a5a"))
	header_copy.add_child(subtitle)

	var close := Button.new()
	close.text = "×"
	close.tooltip_text = "Close gallery"
	close.custom_minimum_size = Vector2(42, 42)
	close.add_theme_font_size_override("font_size", 26)
	close.add_theme_color_override("font_color", Color("#49382f"))
	close.add_theme_stylebox_override("normal", _panel_style(Color("#f1dfc6"), 21, Color("#b99d7d66")))
	close.add_theme_stylebox_override("hover", _panel_style(Color("#ef9a8f"), 21, Color("#c86352")))
	close.pressed.connect(_set_gallery_visible.bind(false))
	header.add_child(close)

	var rule := HSeparator.new()
	rule.modulate = Color("#bca88f")
	gallery.add_child(rule)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 18)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gallery.add_child(columns)

	var library := VBoxContainer.new()
	library.custom_minimum_size = Vector2(308, 0)
	library.add_theme_constant_override("separation", 8)
	columns.add_child(library)

	var library_label := Label.new()
	library_label.text = "FIELD TRIP INDEX"
	library_label.add_theme_font_size_override("font_size", 11)
	library_label.add_theme_color_override("font_color", Color("#9a7960"))
	library.add_child(library_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	library.add_child(scroll)

	var card_list := VBoxContainer.new()
	card_list.add_theme_constant_override("separation", 7)
	card_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(card_list)

	for index in Catalog.DEMOS.size():
		var demo: Dictionary = Catalog.DEMOS[index]
		var card := Button.new()
		card.text = "%s   %s  ·  %s" % [demo.number, demo.title, demo.concept]
		card.alignment = HORIZONTAL_ALIGNMENT_LEFT
		card.custom_minimum_size = Vector2(286, 43)
		card.focus_mode = Control.FOCUS_ALL
		card.toggle_mode = true
		card.add_theme_font_size_override("font_size", 12)
		card.add_theme_color_override("font_color", Color("#49382f"))
		card.add_theme_stylebox_override("normal", _panel_style(Color("#fffaf0"), 12, Color("#b8a58c55")))
		card.add_theme_stylebox_override("hover", _panel_style(demo.accent.lightened(0.28), 12, demo.accent))
		card.add_theme_stylebox_override("pressed", _panel_style(demo.accent.lightened(0.16), 12, demo.accent.darkened(0.15), 4))
		card.pressed.connect(_select_demo.bind(index, true))
		card_list.add_child(card)
		_cards.append(card)

	var detail_panel := PanelContainer.new()
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_panel.add_theme_stylebox_override("panel", _panel_style(Color("#fffaf0"), 18, Color("#6e5b4b33"), 0, 5))
	columns.add_child(detail_panel)

	var detail_margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		detail_margin.add_theme_constant_override("margin_%s" % side, 18)
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
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title_label.add_theme_font_size_override("font_size", 28)
	_title_label.add_theme_color_override("font_color", Color("#49382f"))
	detail.add_child(_title_label)

	_concept_label = Label.new()
	_concept_label.add_theme_font_size_override("font_size", 16)
	detail.add_child(_concept_label)

	_description_label = Label.new()
	_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description_label.add_theme_font_size_override("font_size", 14)
	_description_label.add_theme_color_override("font_color", Color("#66564a"))
	detail.add_child(_description_label)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail.add_child(spacer)

	var metadata_panel := PanelContainer.new()
	metadata_panel.add_theme_stylebox_override("panel", _panel_style(Color("#4c4038"), 15, Color.TRANSPARENT))
	detail.add_child(metadata_panel)
	var metadata_margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		metadata_margin.add_theme_constant_override("margin_%s" % side, 16)
	metadata_panel.add_child(metadata_margin)
	_metadata_label = Label.new()
	_metadata_label.add_theme_font_size_override("font_size", 12)
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
	_activate_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_activate_button.custom_minimum_size = Vector2(0, 46)
	_activate_button.add_theme_font_size_override("font_size", 14)
	_activate_button.add_theme_color_override("font_color", Color("#49382f"))
	_activate_button.add_theme_stylebox_override("normal", _panel_style(Color("#ef9a8f"), 14, Color("#c86352"), 3, 3))
	_activate_button.add_theme_stylebox_override("hover", _panel_style(Color("#f4b0a0"), 14, Color("#c86352"), 3, 4))
	_activate_button.pressed.connect(_activate_demo)
	actions.add_child(_activate_button)

	var reset := Button.new()
	reset.text = "Reset Scene"
	reset.text = "Reset"
	reset.custom_minimum_size = Vector2(82, 46)
	reset.add_theme_font_size_override("font_size", 13)
	reset.add_theme_stylebox_override("normal", _panel_style(Color("#f5e7cf"), 14, Color("#b49b7b")))
	reset.pressed.connect(_reload_demo)
	actions.add_child(reset)

	var footer := Label.new()
	footer.text = "Close this card to explore. Esc releases the pointer."
	footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	footer.add_theme_font_size_override("font_size", 11)
	footer.add_theme_color_override("font_color", Color("#968273"))
	detail.add_child(footer)

func _panel_style(color: Color, radius: int, border_color: Color, border_width := 1, shadow_size := 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.border_color = border_color
	style.shadow_color = Color("#49382f38")
	style.shadow_size = shadow_size
	style.content_margin_left = 12
	style.content_margin_top = 10
	style.content_margin_right = 12
	style.content_margin_bottom = 10
	return style

func _set_gallery_visible(is_visible: bool) -> void:
	_gallery_root.visible = is_visible
	_open_button.visible = not is_visible

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
	_set_gallery_visible(false)

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
		if not _gallery_root.visible:
			_set_gallery_visible(true)

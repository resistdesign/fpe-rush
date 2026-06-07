class_name DemoCatalog

const DEMOS: Array[Dictionary] = [
	{"id": "01_scene_settings", "number": "01", "title": "Paper Morning", "concept": "Scene settings", "blurb": "Sky color and gravity arrive from Blender scene metadata.", "accent": Color("#ef9a8f"), "event": "ActivateDemo", "metadata": "fpe_scene_context_props"},
	{"id": "02_groups", "number": "02", "title": "Ribbon Clubs", "concept": "Groups", "blurb": "Objects join Godot groups from a comma-separated FPE property.", "accent": Color("#e7b66d"), "event": "ActivateDemo", "metadata": "Groups: warm_ribbons, collectibles"},
	{"id": "03_triggers", "number": "03", "title": "Welcome Mat", "concept": "Triggers", "blurb": "A tagged volume turns overlap or interaction into a named event.", "accent": Color("#d9cb72"), "event": "ActivateDemo", "metadata": "fpe_trigger_events_context_props"},
	{"id": "04_event_commands", "number": "04", "title": "Postcard Route", "concept": "Event commands", "blurb": "A declarative event routes one moment into multiple commands.", "accent": Color("#9fc58e"), "event": "ActivateDemo", "metadata": "SceneEvents[].Commands"},
	{"id": "05_animations", "number": "05", "title": "Wind-Up Bloom", "concept": "Animations", "blurb": "FPE plays a Blender-authored action by its exported name.", "accent": Color("#79b9a6"), "event": "ActivateDemo", "metadata": "Animations: Bloom"},
	{"id": "06_cameras", "number": "06", "title": "Teacup Close-Up", "concept": "Cameras", "blurb": "Named Blender cameras become event-addressable viewpoints.", "accent": Color("#71b8c8"), "event": "ActivateDemo", "metadata": "ActivateCamera: DetailCamera"},
	{"id": "07_speakers", "number": "07", "title": "Tiny Chime", "concept": "Speakers", "blurb": "Tagged geometry becomes a spatial audio speaker.", "accent": Color("#83a8d8"), "event": "ActivateDemo", "metadata": "fpe_speaker_settings_context_props"},
	{"id": "08_rigid_physics", "number": "08", "title": "Tumble Parcel", "concept": "Rigid physics", "blurb": "Naming and physics metadata produce an enhanced rigid body.", "accent": Color("#a69bd6"), "event": "ActivateDemo", "metadata": "Parcel-rigid + Physics"},
	{"id": "09_holdables", "number": "09", "title": "Carry The Star", "concept": "Holdables", "blurb": "A rigid object opts into FPE's player hold zone.", "accent": Color("#c197cf"), "event": "ActivateDemo", "metadata": "Holdable: true"},
	{"id": "10_inventory", "number": "10", "title": "Keepsake Pocket", "concept": "Inventory", "blurb": "Pickup metadata declares an item kind and quantity.", "accent": Color("#d593b7"), "event": "ActivateDemo", "metadata": "InventoryItemKind + Quantity"},
	{"id": "11_sub_scenes", "number": "11", "title": "Secret Nook", "concept": "Sub-scenes", "blurb": "A scene host can be loaded and unloaded through event commands.", "accent": Color("#e38e9d"), "event": "ActivateDemo", "metadata": "LoadSubScene: SecretNook"},
	{"id": "12_conversations", "number": "12", "title": "Neighbor Note", "concept": "Conversations", "blurb": "A command starts a resource-backed branching conversation.", "accent": Color("#e79f84"), "event": "ActivateDemo", "metadata": "StartConversation: neighbor_note.tres"},
	{"id": "13_water", "number": "13", "title": "Puddle Shine", "concept": "Water effect", "blurb": "One object flag applies FPE's animated water material.", "accent": Color("#73b7c7"), "event": "ActivateDemo", "metadata": "Water: true"},
	{"id": "14_ui_elements", "number": "14", "title": "Paper Buttons", "concept": "3D UI elements", "blurb": "Tagged meshes become camera-aware selectable controls.", "accent": Color("#89bd9a"), "event": "ActivateDemo", "metadata": "UIElement + UIOptions"},
	{"id": "15_frame_events", "number": "15", "title": "Clockwork Spark", "concept": "Frame events", "blurb": "Animation time can dispatch gameplay at an exact authored frame.", "accent": Color("#e0bd68"), "event": "ActivateDemo", "metadata": "fpe_frame_event_context_props"},
	{"id": "16_physical_puzzle", "number": "16", "title": "Garden Gate", "concept": "Physical puzzle", "blurb": "A trigger plays an animation that moves visible geometry and collision together.", "accent": Color("#ef856f"), "event": "ActivateDemo", "metadata": "Trigger -> Animations: GateOpen"},
]

static func glb_path(demo: Dictionary) -> String:
	return "res://demos/glb/%s.glb" % demo.id


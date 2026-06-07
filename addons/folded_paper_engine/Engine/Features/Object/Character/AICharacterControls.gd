class_name CharacterAI extends CharacterControls

# =============================================================================
# AI CHARACTER WANDERING/ROAMING CONTROLLER
# =============================================================================
# This script provides autonomous AI character movement with intelligent pathfinding.
# Characters will roam randomly within a defined boundary mesh, generating paths
# between waypoints while avoiding obstacles and perimeter edges.
#
# CONFIGURATION:
# - Requires CHARACTER_CONFIG.WanderingBounds to be set to the name of a mesh node
#   in the scene that defines the wandering area boundary
# - The WanderingBounds mesh will be analyzed to generate safe waypoints inside
#   the perimeter, and the AI will create paths between these points
#
# COMPATIBLE VARIABLES (can be set in CHARACTER_CONFIG or directly):
# - WanderingBounds: String - Name of the boundary mesh node in the scene
# - max_speed: float - Maximum movement speed (default: 0.5)
# - path_update_interval: float - Time between path regenerations (default: 5.0)
# - distance_threshold: float - Max distance between waypoints (default: 4.0)
# - show_debug: bool - Enable visual debug rendering (default: true)
#
# FEATURES:
# - Automatic perimeter detection from mesh boundaries
# - Safe pathfinding that never crosses perimeter edges
# - Dynamic waypoint generation inside safe areas
# - Hole detection for exclusion zones within boundaries
# - Idle behavior between waypoints (30% chance, 1-3 seconds)
# - Stuck detection and automatic waypoint skipping
# - Cardinal-only movement to prevent diagonal drift
# =============================================================================

# =============================================================================
# CORE DEPENDENCIES
# =============================================================================
var BOUNDS: Node3D                                     # Reference to bounds mesh node

# =============================================================================
# PATHFINDING CONFIGURATION
# =============================================================================
var path_points: Array[Vector3] = []                   # Current path waypoints
var current_path_index: int = 0                        # Index of current target waypoint
var path_timer: float = 0.0                           # Timer for path regeneration
var path_update_interval: float = 5.0                 # How often to pick new paths (seconds)
var visit_distance: float = 0.2                       # Distance to consider waypoint "reached"
var distance_threshold: float = 4.0                   # Maximum distance between consecutive waypoints

# =============================================================================
# CORE PATHFINDING DATA
# =============================================================================
var available_waypoints: Array[Vector3] = []          # All valid pathfinding waypoints
var perimeter_boundary: Array[Array] = []             # Perimeter edges for boundary detection
var bounds_vertices: PackedVector3Array = []          # All mesh vertices in world space
var bounds_edges: Array[Array] = []                   # All mesh edges as vertex index pairs
var bounds_min: Vector2                               # 2D bounding box minimum
var bounds_max: Vector2                               # 2D bounding box maximum
var cached_perimeter_polygon: Array[Vector2] = []     # Cached ordered perimeter points for performance
var cached_hole_polygons: Array[Array] = []           # Cached hole perimeters (exclusion zones)

# =============================================================================
# WAYPOINT VISITATION TRACKING
# =============================================================================
var waypoint_visit_times: Dictionary = {}             # Tracks last visit time for each waypoint
var waypoint_cooldown: float = 15.0                   # Seconds before a waypoint can be revisited
var favor_unvisited_multiplier: float = 3.0           # How much to favor unvisited waypoints

# =============================================================================
# DEBUG VISUALIZATION
# =============================================================================
var debug_container: Node3D = null                    # Container for all debug visuals
var debug_path_line: MeshInstance3D = null            # Visual representation of current path
var show_debug: bool = false                          # Toggle debug visualization

# =============================================================================
# MOVEMENT CONFIGURATION
# =============================================================================
var max_speed: float = 0.5                            # Maximum movement speed
var min_speed: float = 0.1                            # Minimum movement speed
var speed_distance_threshold: float = 2.0             # Distance threshold for speed calculations

# =============================================================================
# MOVEMENT STATE MANAGEMENT
# =============================================================================
var current_movement_direction: Vector2 = Vector2.ZERO # Locked movement direction to prevent shaking
var direction_change_threshold: float = 0.3            # Threshold for changing movement direction

# =============================================================================
# STUCK DETECTION SYSTEM
# =============================================================================
var stuck_detection_timer: float = 0.0                # Timer for stuck detection
var stuck_check_interval: float = 2.0                 # How often to check for stuck state
var last_position: Vector2 = Vector2.ZERO             # Previous position for stuck detection
var min_expected_movement: float = 0.1                # Minimum expected movement distance

# =============================================================================
# IDLE BEHAVIOR SYSTEM
# =============================================================================
var is_idling_between_points: bool = false            # Whether character is idling between waypoints
var idle_timer: float = 0.0                          # Current idle timer
var idle_duration: float = 2.0                       # How long to idle between waypoints

# =============================================================================
# LEGACY VARIABLES (kept for compatibility)
# =============================================================================
var direction_change_timer: float = 0.0               # Legacy direction change timer
var direction_change_interval: float = 2.0            # Legacy direction change interval
var current_input: Vector2 = Vector2.ZERO             # Legacy input vector
var stuck_threshold_time: float = 3.0                 # Legacy stuck threshold

func _ready() -> void:
	super._ready()

	# Try to setup bounds from CHARACTER_CONFIG if available
	if CHARACTER_CONFIG and CHARACTER_CONFIG.WanderingBounds:
		BOUNDS = NodeUtils.find_node_by_name(get_tree().current_scene, CHARACTER_CONFIG.WanderingBounds)  #reads wandering bounds

		if BOUNDS:
			_analyze_bounds_mesh()

# =============================================================================
# MAIN UPDATE LOOP
# =============================================================================
func _physics_process(delta: float) -> void:
	super._physics_process(delta)

	# Update path regeneration timer
	path_timer += delta
	
	# Regenerate path every X seconds to keep movement dynamic
	if path_timer >= path_update_interval:
		path_timer = 0.0
		is_idling_between_points = false
		idle_timer = 0.0
		
		# Reset all movement state to prevent old input from carrying over
		current_movement_direction = Vector2.ZERO
		stuck_detection_timer = 0.0
		last_position = Vector2(global_position.x, global_position.z)
		
		_pick_new_path()
	
	# Handle idle periods between waypoints
	if is_idling_between_points:
		idle_timer += delta
		
		# Keep character stationary during idle
		move(Vector2.ZERO, 0.0, 0.0)
		
		# Check if idle period is complete
		if idle_timer >= idle_duration:
			is_idling_between_points = false
			idle_timer = 0.0
		return
	
	# Execute pathfinding movement or idle if no path available
	if path_points.size() > 0 and current_path_index < path_points.size():
		_move_towards_current_target(delta)
	else:
		# No active path - keep character stationary
		move(Vector2.ZERO, 0.0, 0.0)

# =============================================================================
# PATHFINDING MOVEMENT EXECUTION
# =============================================================================
func _move_towards_current_target(delta: float) -> void:
	# Get current target waypoint and character position
	var current_target = path_points[current_path_index]
	var character_pos = global_position
	
	# Calculate 2D distance to target (ignore Y axis for ground-based movement)
	var char_pos_2d = Vector2(character_pos.x, character_pos.z)
	var target_pos_2d = Vector2(current_target.x, current_target.z)
	var distance_to_target = char_pos_2d.distance_to(target_pos_2d)
	
	# === STUCK DETECTION SYSTEM ===
	stuck_detection_timer += delta
	if stuck_detection_timer >= stuck_check_interval:
		var movement_distance = char_pos_2d.distance_to(last_position)
		
		# If character hasn't moved enough, consider it stuck and skip to next waypoint
		if movement_distance < min_expected_movement and current_movement_direction != Vector2.ZERO:
			# Skip to next waypoint in path
			current_path_index += 1
			current_movement_direction = Vector2.ZERO

			# Check if we've completed the entire path
			if current_path_index >= path_points.size():
				path_points.clear()
				current_path_index = 0
				current_movement_direction = Vector2.ZERO

				# Clear path visualization
				_update_debug_path()

				# Stop character movement when path is complete
				move(Vector2.ZERO, 0.0, 0.0)
			else:
				# Update path visualization to show remaining waypoints
				_update_debug_path()

			# Reset stuck detection system
			stuck_detection_timer = 0.0
			last_position = char_pos_2d
			return
		
		# Update stuck detection state
		stuck_detection_timer = 0.0
		last_position = char_pos_2d
	
	# === WAYPOINT ARRIVAL CHECK ===
	if distance_to_target <= visit_distance:
		# Mark waypoint as visited
		_mark_waypoint_visited(current_target)

		# Waypoint reached - advance to next one
		current_path_index += 1

		# Reset movement state for clean transition
		current_movement_direction = Vector2.ZERO
		stuck_detection_timer = 0.0
		last_position = char_pos_2d

		# Check if we've completed the entire path
		if current_path_index >= path_points.size():
			path_points.clear()
			current_path_index = 0
			current_movement_direction = Vector2.ZERO

			# Clear path visualization
			_update_debug_path()

			# Stop character movement when path is complete
			move(Vector2.ZERO, 0.0, 0.0)
		else:
			# More waypoints remaining - randomly decide whether to idle
			if randf() < 0.3:  # 30% chance to idle at waypoint
				is_idling_between_points = true
				idle_timer = 0.0
				idle_duration = randf_range(1.0, 3.0)  # Random idle time 1-3 seconds

			# Update path visualization to show remaining waypoints
			_update_debug_path()
		return

	# === MOVEMENT DIRECTION CALCULATION ===
	var direction_to_target = (target_pos_2d - char_pos_2d).normalized()
	var speed_factor = max_speed  # Use consistent maximum speed

	# Determine primary movement direction (cardinal directions only to prevent diagonal drift)
	var new_direction = Vector2.ZERO
	if abs(direction_to_target.x) > abs(direction_to_target.y):
		# Horizontal movement is dominant
		new_direction = Vector2(1, 0) if direction_to_target.x > 0 else Vector2(-1, 0)
	else:
		# Vertical movement is dominant
		new_direction = Vector2(0, 1) if direction_to_target.y > 0 else Vector2(0, -1)
	
	# === DIRECTION LOCKING SYSTEM (prevents movement shaking) ===
	if current_movement_direction == Vector2.ZERO:
		# No direction set yet - use the calculated direction
		current_movement_direction = new_direction
		last_position = char_pos_2d
	elif abs(direction_to_target.x) > abs(direction_to_target.y) + direction_change_threshold and current_movement_direction.y != 0:
		# Strong horizontal preference - switch from vertical to horizontal
		current_movement_direction = new_direction
	elif abs(direction_to_target.y) > abs(direction_to_target.x) + direction_change_threshold and current_movement_direction.x != 0:
		# Strong vertical preference - switch from horizontal to vertical
		current_movement_direction = new_direction
	
	# === APPLY MOVEMENT ===
	var movement_input = current_movement_direction * speed_factor
	move(movement_input, 0.0, 0.0)

# =============================================================================
# PATH GENERATION SYSTEM
# =============================================================================
func _pick_new_path() -> void:
	# Ensure we have enough waypoints for pathfinding
	if available_waypoints.size() < 3:
		return

	# Reset all movement state for clean path transition
	path_points.clear()
	current_path_index = 0
	current_movement_direction = Vector2.ZERO
	stuck_detection_timer = 0.0

	# Stop character movement immediately during path change
	move(Vector2.ZERO, 0.0, 0.0)
	
	# Find starting point near character's current position
	var character_pos = global_position
	var character_pos_2d = Vector2(character_pos.x, character_pos.z)
	last_position = character_pos_2d

	var nearest_point = _find_nearest_waypoint_to_position(character_pos)
	if nearest_point == Vector3.INF:
		return

	# Attempt to create a valid 3-waypoint path with perimeter safety
	var max_attempts = 50
	var attempt = 0

	while path_points.size() < 3 and attempt < max_attempts:
		attempt += 1
		path_points.clear()

		# Start path from different points on each attempt
		# First few attempts use nearest point, then randomize
		var current_point: Vector3
		if attempt <= 3:
			# Try nearest point first
			current_point = nearest_point
		else:
			# Pick a random starting point for variety
			current_point = available_waypoints[randi() % available_waypoints.size()]

		var remaining_points = available_waypoints.duplicate()
		path_points.append(current_point)
		remaining_points.erase(current_point)
		
		# Build path by finding connected waypoints
		var valid_path = true
		for i in range(2):  # Need 2 more points for 3-point path
			var next_point = _find_next_waypoint_in_range(current_point, remaining_points)
			
			if next_point != Vector3.INF:
				path_points.append(next_point)
				remaining_points.erase(next_point)
				current_point = next_point
			else:
				valid_path = false
				break
		
		# Validate complete path for perimeter safety
		if path_points.size() == 3 and valid_path:
			var path_valid = true

			# Check every path segment for perimeter crossings
			for i in range(path_points.size() - 1):
				if _path_crosses_perimeter(path_points[i], path_points[i + 1]):
					path_valid = false
					break

			if path_valid:
				# Update debug path visualization
				_update_debug_path()
				break  # Successfully created valid path

	# Handle path creation failure
	if path_points.size() < 3:
		# Clean up failed path attempt
		path_points.clear()
		current_path_index = 0
		current_movement_direction = Vector2.ZERO

		# Clear path visualization
		_update_debug_path()

		# Stop character movement when no valid path available
		move(Vector2.ZERO, 0.0, 0.0)

		# Reset timer to retry after a short delay (not too fast to avoid frame drops)
		path_timer = path_update_interval - 2.0  # Will trigger retry in 2 seconds

# =============================================================================
# WAYPOINT CONNECTION SYSTEM
# =============================================================================
func _find_next_waypoint_in_range(from_point: Vector3, candidates: Array[Vector3]) -> Vector3:
	var valid_points: Array[Vector3] = []
	var point_scores: Array[float] = []

	# Find all candidate waypoints within range that don't cross perimeter
	for point in candidates:
		var distance = Vector2(from_point.x, from_point.z).distance_to(Vector2(point.x, point.z))

		if distance <= distance_threshold:
			# Check if direct path to this point crosses the perimeter boundary
			if not _path_crosses_perimeter(from_point, point):
				valid_points.append(point)
				# Calculate preference score for this waypoint
				var score = _get_waypoint_preference_score(point, distance)
				point_scores.append(score)

	# Return best valid waypoint based on preference score
	if valid_points.size() > 0:
		# Find the waypoint with the best (lowest) score
		var best_index = 0
		var best_score = point_scores[0]

		for i in range(1, valid_points.size()):
			if point_scores[i] < best_score:
				best_score = point_scores[i]
				best_index = i

		return valid_points[best_index]
	else:
		return Vector3.INF  # No valid points found

# =============================================================================
# BOUNDS MESH ANALYSIS SYSTEM
# =============================================================================
func _analyze_bounds_mesh() -> void:
	if not BOUNDS:
		return

	# Find MeshInstance3D component
	var mesh_instance: MeshInstance3D = null

	if BOUNDS is MeshInstance3D:
		mesh_instance = BOUNDS as MeshInstance3D
	else:
		# Look for MeshInstance3D child
		for child in BOUNDS.get_children():
			if child is MeshInstance3D:
				mesh_instance = child as MeshInstance3D
				break

	if not mesh_instance or not mesh_instance.mesh:
		return

	# Process mesh to generate core pathfinding data (invisible)
	_extract_vertices_and_edges_from_mesh(mesh_instance)

	_detect_perimeter_boundary()

	# Cache the perimeter polygon and holes ONCE
	var all_components = _get_all_perimeter_components()

	# Largest component is the outer boundary, smaller ones are holes
	if all_components.size() > 0:
		cached_perimeter_polygon = all_components[0]

		# Store holes (all components except the largest)
		cached_hole_polygons.clear()
		for i in range(1, all_components.size()):
			cached_hole_polygons.append(all_components[i])
	else:
		cached_perimeter_polygon = []

	# FALLBACK: If perimeter detection failed or polygon is degenerate, use simple bounding rectangle
	var use_fallback = false

	if cached_perimeter_polygon.size() < 4:
		use_fallback = true
	else:
		# Check if polygon is degenerate (all points on a line)
		var unique_x_coords = {}
		var unique_y_coords = {}
		for point in cached_perimeter_polygon:
			unique_x_coords[snapped(point.x, 0.001)] = true
			unique_y_coords[snapped(point.y, 0.001)] = true

		if unique_x_coords.size() < 2 or unique_y_coords.size() < 2:
			use_fallback = true

	if use_fallback:
		cached_perimeter_polygon = [
			Vector2(bounds_min.x, bounds_min.y),
			Vector2(bounds_max.x, bounds_min.y),
			Vector2(bounds_max.x, bounds_max.y),
			Vector2(bounds_min.x, bounds_max.y)
		]
		cached_hole_polygons.clear()  # No holes in fallback mode

	# Generate waypoints asynchronously to avoid lag
	await _generate_pathfinding_waypoints_async()
	_create_debug_visualization()

	# Pick initial path immediately so character starts moving right away
	if available_waypoints.size() > 0:
		_pick_new_path()

		# Skip any waypoints we're already standing on
		var char_pos_2d = Vector2(global_position.x, global_position.z)
		while current_path_index < path_points.size():
			var waypoint = path_points[current_path_index]
			var waypoint_2d = Vector2(waypoint.x, waypoint.z)
			var dist = char_pos_2d.distance_to(waypoint_2d)

			if dist <= visit_distance * 2.0:  # Already at this waypoint
				current_path_index += 1
			else:
				break  # Found a waypoint we need to walk to

		# Make sure we're not idling at start
		is_idling_between_points = false
		idle_timer = 0.0

# =============================================================================
# MESH GEOMETRY EXTRACTION
# =============================================================================
func _extract_vertices_and_edges_from_mesh(mesh_instance: MeshInstance3D) -> void:
	var mesh = mesh_instance.mesh
	var surface_count = mesh.get_surface_count()
	
	# Clear previous data
	bounds_vertices.clear()
	bounds_edges.clear()
	var all_vertices: PackedVector3Array = []
	var vertex_offset = 0
	
	# Process each mesh surface
	for surface_idx in range(surface_count):
		var arrays = mesh.surface_get_arrays(surface_idx)
		if not arrays[Mesh.ARRAY_VERTEX] or not arrays[Mesh.ARRAY_INDEX]:
			continue
			
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		
		# Transform vertices to world space
		var transform = mesh_instance.global_transform
		for vertex in vertices:
			var world_vertex = transform * vertex
			all_vertices.append(world_vertex)
		
		# Extract edges from triangles
		for i in range(0, indices.size(), 3):
			var v1 = indices[i] + vertex_offset
			var v2 = indices[i + 1] + vertex_offset  
			var v3 = indices[i + 2] + vertex_offset
			
			# Add the three edges of each triangle
			_add_edge(v1, v2)
			_add_edge(v2, v3)
			_add_edge(v3, v1)
		
		vertex_offset += vertices.size()
	
	bounds_vertices = all_vertices
	
	# Calculate 2D bounding rectangle for waypoint generation
	if bounds_vertices.size() > 0:
		bounds_min = Vector2(bounds_vertices[0].x, bounds_vertices[0].z)
		bounds_max = bounds_min
		
		for vertex in bounds_vertices:
			bounds_min.x = min(bounds_min.x, vertex.x)
			bounds_min.y = min(bounds_min.y, vertex.z)
			bounds_max.x = max(bounds_max.x, vertex.x)
			bounds_max.y = max(bounds_max.y, vertex.z)

func _add_edge(v1: int, v2: int) -> void:
	# Create normalized edge (smaller index first) to prevent duplicates
	var edge = [min(v1, v2), max(v1, v2)]
	
	# Check if edge already exists
	for existing_edge in bounds_edges:
		if existing_edge[0] == edge[0] and existing_edge[1] == edge[1]:
			return
	
	bounds_edges.append(edge)

# =============================================================================
# PERIMETER BOUNDARY DETECTION
# =============================================================================
func _detect_perimeter_boundary() -> void:
	perimeter_boundary.clear()
	
	# Count how many triangles use each edge
	var edge_count: Dictionary = {}
	
	# Get mesh instance for triangle processing
	var mesh_instance: MeshInstance3D = BOUNDS as MeshInstance3D
	if not mesh_instance:
		for child in BOUNDS.get_children():
			if child is MeshInstance3D:
				mesh_instance = child as MeshInstance3D
				break
	
	if not mesh_instance or not mesh_instance.mesh:
		return
	
	var mesh = mesh_instance.mesh
	var vertex_offset = 0
	
	# Process each mesh surface to count edge usage
	for surface_idx in range(mesh.get_surface_count()):
		var arrays = mesh.surface_get_arrays(surface_idx)
		if not arrays[Mesh.ARRAY_VERTEX] or not arrays[Mesh.ARRAY_INDEX]:
			continue
			
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		
		# Count edge usage in triangles
		for i in range(0, indices.size(), 3):
			var v1 = indices[i] + vertex_offset
			var v2 = indices[i + 1] + vertex_offset
			var v3 = indices[i + 2] + vertex_offset
			
			_count_edge_usage(edge_count, v1, v2)
			_count_edge_usage(edge_count, v2, v3)
			_count_edge_usage(edge_count, v3, v1)
		
		vertex_offset += vertices.size()
	
	# Edges used by only one triangle are perimeter edges (boundary)
	for edge_key in edge_count.keys():
		if edge_count[edge_key] == 1:
			var vertices_indices = edge_key.split(",")
			var v1 = int(vertices_indices[0])
			var v2 = int(vertices_indices[1])
			perimeter_boundary.append([v1, v2])

func _count_edge_usage(edge_count: Dictionary, v1: int, v2: int) -> void:
	# Create normalized edge key for counting
	var key = str(min(v1, v2)) + "," + str(max(v1, v2))
	
	if key in edge_count:
		edge_count[key] += 1
	else:
		edge_count[key] = 1

# =============================================================================
# WAYPOINT GENERATION SYSTEM (INVISIBLE)
# =============================================================================
func _generate_pathfinding_waypoints() -> void:
	if bounds_vertices.size() == 0:
		return

	if perimeter_boundary.size() == 0:
		return

	available_waypoints.clear()

	# Calculate average Y height from bounds mesh vertices
	var average_y: float = 0.0
	for vertex in bounds_vertices:
		average_y += vertex.y
	average_y /= bounds_vertices.size()

	var target_waypoints = 45           # Number of waypoints to generate
	var waypoints_created = 0
	var safety_margin = 0.3            # Distance from perimeter edge
	var min_spacing = 2.0              # Minimum distance between waypoints
	var max_attempts = target_waypoints * 30

	var attempts = 0
	var placed_positions: Array[Vector2] = []
	var inside_count = 0  # Debug counter
	
	# Method 1: Random placement with safety checks
	while waypoints_created < target_waypoints and attempts < max_attempts:
		attempts += 1
		
		# Generate random position within bounds
		var random_x = randf_range(bounds_min.x + safety_margin, bounds_max.x - safety_margin)
		var random_z = randf_range(bounds_min.y + safety_margin, bounds_max.y - safety_margin)
		var test_point = Vector2(random_x, random_z)
		
		# Check if point is safely inside perimeter with proper spacing
		if _is_point_safely_inside_perimeter(test_point, safety_margin):
			inside_count += 1
			var too_close = false
			for existing_pos in placed_positions:
				if test_point.distance_to(existing_pos) < min_spacing:
					too_close = true
					break

			if not too_close:
				# Add invisible waypoint to pathfinding system
				available_waypoints.append(Vector3(random_x, average_y, random_z))
				placed_positions.append(test_point)
				waypoints_created += 1
	
	# Method 2: Grid-based placement if needed
	if waypoints_created < target_waypoints * 0.5:
		var grid_size = 20
		var step_x = (bounds_max.x - bounds_min.x) / grid_size
		var step_z = (bounds_max.y - bounds_min.y) / grid_size
		
		for x in range(grid_size):
			for z in range(grid_size):
				if waypoints_created >= target_waypoints:
					break
				
				var pos_x = bounds_min.x + x * step_x
				var pos_z = bounds_min.y + z * step_z
				var test_point = Vector2(pos_x, pos_z)
				
				if _is_point_safely_inside_perimeter(test_point, safety_margin):
					var too_close = false
					for existing_pos in placed_positions:
						if test_point.distance_to(existing_pos) < min_spacing:
							too_close = true
							break
					
					if not too_close:
						# Add invisible waypoint to pathfinding system
						available_waypoints.append(Vector3(pos_x, average_y, pos_z))
						placed_positions.append(test_point)
						waypoints_created += 1
			
			if waypoints_created >= target_waypoints:
				break

# Clear waypoints (called when teleporting to new room to avoid regenerating immediately)
func clear_waypoints() -> void:
	available_waypoints.clear()

# Async waypoint generation - spreads load across frames to prevent lag
func _generate_pathfinding_waypoints_async() -> void:
	if bounds_vertices.size() == 0:
		return

	if perimeter_boundary.size() == 0:
		return

	available_waypoints.clear()

	# Calculate average Y height
	var average_y: float = 0.0
	for vertex in bounds_vertices:
		average_y += vertex.y
	average_y /= bounds_vertices.size()

	var target_waypoints = 45
	var waypoints_created = 0
	var safety_margin = 0.3
	var min_spacing = 2.0
	var max_attempts = target_waypoints * 30

	var attempts = 0
	var placed_positions: Array[Vector2] = []
	var inside_count = 0

	# Generate waypoints, yielding every 5 waypoints to spread load
	while waypoints_created < target_waypoints and attempts < max_attempts:
		attempts += 1

		var random_x = randf_range(bounds_min.x + safety_margin, bounds_max.x - safety_margin)
		var random_z = randf_range(bounds_min.y + safety_margin, bounds_max.y - safety_margin)
		var test_point = Vector2(random_x, random_z)

		if _is_point_safely_inside_perimeter(test_point, safety_margin):
			inside_count += 1
			var too_close = false
			for existing_pos in placed_positions:
				if test_point.distance_to(existing_pos) < min_spacing:
					too_close = true
					break

			if not too_close:
				available_waypoints.append(Vector3(random_x, average_y, random_z))
				placed_positions.append(test_point)
				waypoints_created += 1

				# Yield every 5 waypoints to spread load
				if waypoints_created % 5 == 0:
					await get_tree().process_frame

# =============================================================================
# GEOMETRIC POINT-IN-POLYGON TESTING
# =============================================================================
func _is_point_inside_shape(point: Vector2) -> bool:
	# Compatibility function - redirects to polygon testing
	return _is_point_inside_perimeter_polygon(point)

func _is_point_inside_perimeter_polygon(point: Vector2) -> bool:
	# Use cached perimeter polygon for performance
	if cached_perimeter_polygon.size() < 3:
		return false

	# Ray casting algorithm: count intersections with polygon edges
	var intersections = 0
	var ray_y = point.y

	for i in range(cached_perimeter_polygon.size()):
		var p1 = cached_perimeter_polygon[i]
		var p2 = cached_perimeter_polygon[(i + 1) % cached_perimeter_polygon.size()]
		
		# Check if edge crosses the horizontal ray
		if ((p1.y > ray_y) != (p2.y > ray_y)):
			var intersection_x = (p2.x - p1.x) * (ray_y - p1.y) / (p2.y - p1.y) + p1.x
			
			# Count intersections to the right of the point
			if intersection_x > point.x:
				intersections += 1
	
	# Point is inside if odd number of intersections
	return (intersections % 2) == 1

func _get_all_perimeter_components() -> Array[Array]:
	# Find ALL connected components and return them sorted by size (largest first)
	if perimeter_boundary.size() == 0:
		return []

	# Convert 3D vertices to 2D
	var vertex_2d_map: Dictionary = {}
	for i in range(bounds_vertices.size()):
		vertex_2d_map[i] = Vector2(bounds_vertices[i].x, bounds_vertices[i].z)

	# Build adjacency list from perimeter edges
	var adjacency: Dictionary = {}
	for edge in perimeter_boundary:
		var v1 = edge[0]
		var v2 = edge[1]

		if not adjacency.has(v1):
			adjacency[v1] = []
		if not adjacency.has(v2):
			adjacency[v2] = []

		adjacency[v1].append(v2)
		adjacency[v2].append(v1)

	# Find all connected components
	var all_components: Array[Array] = []
	var global_visited: Dictionary = {}

	for start_vertex in adjacency.keys():
		if start_vertex in global_visited:
			continue

		# Trace this component
		var component: Array[Vector2] = []
		var current_vertex = start_vertex
		var previous_vertex = -1

		while true:
			if current_vertex in global_visited:
				break

			global_visited[current_vertex] = true
			component.append(vertex_2d_map[current_vertex])

			# Find next unvisited neighbor
			var next_vertex = -1
			for neighbor in adjacency[current_vertex]:
				if neighbor != previous_vertex:
					next_vertex = neighbor
					break

			if next_vertex == -1 or next_vertex == start_vertex:
				break

			previous_vertex = current_vertex
			current_vertex = next_vertex

		if component.size() >= 3:
			all_components.append(component)

	# Sort components by size (largest first)
	all_components.sort_custom(func(a, b): return a.size() > b.size())

	return all_components

func _get_largest_perimeter_component() -> Array[Vector2]:
	# Compatibility function - returns only the largest component
	var all_components = _get_all_perimeter_components()
	if all_components.size() > 0:
		return all_components[0]
	return []

func _get_ordered_perimeter_points() -> Array[Vector2]:
	if perimeter_boundary.size() == 0:
		return []

	# Convert 3D vertices to 2D
	var vertex_2d_map: Dictionary = {}
	for i in range(bounds_vertices.size()):
		vertex_2d_map[i] = Vector2(bounds_vertices[i].x, bounds_vertices[i].z)

	# Build adjacency list from perimeter edges
	var adjacency: Dictionary = {}
	for edge in perimeter_boundary:
		var v1 = edge[0]
		var v2 = edge[1]

		if not adjacency.has(v1):
			adjacency[v1] = []
		if not adjacency.has(v2):
			adjacency[v2] = []

		adjacency[v1].append(v2)
		adjacency[v2].append(v1)

	# Find leftmost point as starting point
	var start_vertex = -1
	var leftmost_x = INF
	for vertex_idx in adjacency.keys():
		var pos = vertex_2d_map[vertex_idx]
		if pos.x < leftmost_x:
			leftmost_x = pos.x
			start_vertex = vertex_idx

	if start_vertex == -1:
		return []

	# Traverse perimeter to get ordered points
	var ordered_points: Array[Vector2] = []
	var current_vertex = start_vertex
	var previous_vertex = -1
	var visited: Dictionary = {}

	while true:
		if current_vertex in visited:
			break

		visited[current_vertex] = true
		ordered_points.append(vertex_2d_map[current_vertex])

		# Find next unvisited neighbor
		var next_vertex = -1
		for neighbor in adjacency[current_vertex]:
			if neighbor != previous_vertex:
				next_vertex = neighbor
				break

		if next_vertex == -1 or next_vertex == start_vertex:
			break

		previous_vertex = current_vertex
		current_vertex = next_vertex

	return ordered_points

# =============================================================================
# DEBUG VISUALIZATION
# =============================================================================
func _create_debug_visualization() -> void:
	if not show_debug:
		return

	# Clean up old debug visuals
	if debug_container:
		debug_container.queue_free()

	# Create container
	debug_container = Node3D.new()
	debug_container.name = "AI_Debug_Visuals"
	get_tree().current_scene.add_child(debug_container)

	# Draw perimeter polygon
	_debug_draw_perimeter()

	# Draw hole perimeters
	_debug_draw_holes()

	# Draw waypoints
	_debug_draw_waypoints()

	# Draw bounding box
	_debug_draw_bounds()

func _debug_draw_perimeter() -> void:
	if cached_perimeter_polygon.size() < 3:
		return

	# Get average Y for the perimeter line
	var avg_y = 0.0
	for v in bounds_vertices:
		avg_y += v.y
	avg_y /= bounds_vertices.size()

	# Create a line mesh for the perimeter
	var immediate_mesh = ImmediateMesh.new()
	immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)

	for point_2d in cached_perimeter_polygon:
		immediate_mesh.surface_add_vertex(Vector3(point_2d.x, avg_y + 0.1, point_2d.y))

	# Close the loop
	if cached_perimeter_polygon.size() > 0:
		var first = cached_perimeter_polygon[0]
		immediate_mesh.surface_add_vertex(Vector3(first.x, avg_y + 0.1, first.y))

	immediate_mesh.surface_end()

	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = immediate_mesh
	mesh_instance.name = "Perimeter_Line"

	# Create material for perimeter (yellow)
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(1, 1, 0, 1)  # Yellow
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_instance.material_override = material

	debug_container.add_child(mesh_instance)

func _debug_draw_holes() -> void:
	if cached_hole_polygons.size() == 0:
		return

	# Get average Y for the hole lines
	var avg_y = 0.0
	for v in bounds_vertices:
		avg_y += v.y
	avg_y /= bounds_vertices.size()

	# Draw each hole polygon
	for hole_idx in range(cached_hole_polygons.size()):
		var hole_polygon = cached_hole_polygons[hole_idx]

		if hole_polygon.size() < 3:
			continue

		# Create a line mesh for this hole
		var immediate_mesh = ImmediateMesh.new()
		immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)

		for point_2d in hole_polygon:
			immediate_mesh.surface_add_vertex(Vector3(point_2d.x, avg_y + 0.15, point_2d.y))

		# Close the loop
		if hole_polygon.size() > 0:
			var first = hole_polygon[0]
			immediate_mesh.surface_add_vertex(Vector3(first.x, avg_y + 0.15, first.y))

		immediate_mesh.surface_end()

		var mesh_instance = MeshInstance3D.new()
		mesh_instance.mesh = immediate_mesh
		mesh_instance.name = "Hole_" + str(hole_idx) + "_Perimeter"

		# Create material for hole perimeter (magenta/orange)
		var material = StandardMaterial3D.new()
		material.albedo_color = Color(1, 0, 1, 1)  # Magenta
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mesh_instance.material_override = material

		debug_container.add_child(mesh_instance)

func _debug_draw_waypoints() -> void:
	for waypoint in available_waypoints:
		var sphere = _create_debug_sphere(0.15, Color(0, 1, 0, 0.8))  # Green semi-transparent
		sphere.position = waypoint
		sphere.name = "Waypoint"
		debug_container.add_child(sphere)

func _debug_draw_bounds() -> void:
	if bounds_min == Vector2.ZERO and bounds_max == Vector2.ZERO:
		return

	var avg_y = 0.0
	for v in bounds_vertices:
		avg_y += v.y
	avg_y /= bounds_vertices.size()

	# Draw bounding box as lines
	var corners = [
		Vector3(bounds_min.x, avg_y + 0.05, bounds_min.y),
		Vector3(bounds_max.x, avg_y + 0.05, bounds_min.y),
		Vector3(bounds_max.x, avg_y + 0.05, bounds_max.y),
		Vector3(bounds_min.x, avg_y + 0.05, bounds_max.y)
	]

	var immediate_mesh = ImmediateMesh.new()
	immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)

	for corner in corners:
		immediate_mesh.surface_add_vertex(corner)
	immediate_mesh.surface_add_vertex(corners[0])  # Close the loop

	immediate_mesh.surface_end()

	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = immediate_mesh
	mesh_instance.name = "Bounds_Box"

	var material = StandardMaterial3D.new()
	material.albedo_color = Color(1, 0, 0, 1)  # Red
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_instance.material_override = material

	debug_container.add_child(mesh_instance)

func _update_debug_path() -> void:
	if not show_debug:
		return

	if not debug_container:
		return

	# Remove old path line if it exists
	if debug_path_line:
		debug_path_line.queue_free()
		debug_path_line = null

	# Only draw if we have a valid path with at least 2 remaining waypoints
	var remaining_waypoints = path_points.size() - current_path_index
	if remaining_waypoints < 2:
		return

	# Create line mesh for the path
	var immediate_mesh = ImmediateMesh.new()
	immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)

	# Draw line through all waypoints in the path
	for i in range(current_path_index, path_points.size()):
		var waypoint = path_points[i]
		immediate_mesh.surface_add_vertex(waypoint)

	immediate_mesh.surface_end()

	# Create mesh instance
	debug_path_line = MeshInstance3D.new()
	debug_path_line.mesh = immediate_mesh
	debug_path_line.name = "Current_Path"

	# Create material for path (cyan/bright blue)
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0, 1, 1, 1)  # Cyan
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	debug_path_line.material_override = material

	debug_container.add_child(debug_path_line)

func _create_debug_sphere(radius: float, color: Color) -> MeshInstance3D:
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = radius
	sphere_mesh.height = radius * 2

	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = sphere_mesh

	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_instance.material_override = material

	return mesh_instance

func _is_point_inside_any_hole(point: Vector2) -> bool:
	# Check if point is inside any hole polygon
	for hole_polygon in cached_hole_polygons:
		if _is_point_inside_polygon(point, hole_polygon):
			return true
	return false

func _is_point_inside_polygon(point: Vector2, polygon: Array) -> bool:
	# Ray casting algorithm for arbitrary polygon
	if polygon.size() < 3:
		return false

	var intersections = 0
	var ray_y = point.y

	for i in range(polygon.size()):
		var p1 = polygon[i]
		var p2 = polygon[(i + 1) % polygon.size()]

		# Check if edge crosses the horizontal ray
		if ((p1.y > ray_y) != (p2.y > ray_y)):
			var intersection_x = (p2.x - p1.x) * (ray_y - p1.y) / (p2.y - p1.y) + p1.x

			# Count intersections to the right of the point
			if intersection_x > point.x:
				intersections += 1

	# Point is inside if odd number of intersections
	return (intersections % 2) == 1

func _is_point_safely_inside_perimeter(point: Vector2, safety_margin: float = 0.5) -> bool:
	# First check if point is inside the outer polygon
	if not _is_point_inside_perimeter_polygon(point):
		return false

	# Check if point is inside any hole (exclusion zone)
	if _is_point_inside_any_hole(point):
		return false

	# Then check distance from all perimeter edges
	var min_distance_to_perimeter = INF

	for edge in perimeter_boundary:
		var v1_idx = edge[0]
		var v2_idx = edge[1]

		if v1_idx >= bounds_vertices.size() or v2_idx >= bounds_vertices.size():
			continue

		var v1_2d = Vector2(bounds_vertices[v1_idx].x, bounds_vertices[v1_idx].z)
		var v2_2d = Vector2(bounds_vertices[v2_idx].x, bounds_vertices[v2_idx].z)

		var distance = _distance_point_to_line_segment(point, v1_2d, v2_2d)
		min_distance_to_perimeter = min(min_distance_to_perimeter, distance)

	return min_distance_to_perimeter >= safety_margin

func _distance_point_to_line_segment(point: Vector2, line_start: Vector2, line_end: Vector2) -> float:
	var line_vec = line_end - line_start
	var point_vec = point - line_start
	
	var line_len_squared = line_vec.length_squared()
	if line_len_squared == 0:
		return point_vec.length()
	
	var t = point_vec.dot(line_vec) / line_len_squared
	t = clamp(t, 0.0, 1.0)
	
	var projection = line_start + t * line_vec
	return point.distance_to(projection)

# =============================================================================
# LINE INTERSECTION DETECTION SYSTEM
# =============================================================================
func _path_crosses_perimeter(point1: Vector3, point2: Vector3) -> bool:
	var path_start = Vector2(point1.x, point1.z)
	var path_end = Vector2(point2.x, point2.z)

	# Check intersection with each perimeter edge (outer boundary)
	for edge in perimeter_boundary:
		var v1_idx = edge[0]
		var v2_idx = edge[1]

		if v1_idx >= bounds_vertices.size() or v2_idx >= bounds_vertices.size():
			continue

		var edge_start = Vector2(bounds_vertices[v1_idx].x, bounds_vertices[v1_idx].z)
		var edge_end = Vector2(bounds_vertices[v2_idx].x, bounds_vertices[v2_idx].z)

		# Test if path line segment intersects perimeter edge
		if _line_segments_intersect_robust(path_start, path_end, edge_start, edge_end):
			return true

	# Check if path crosses any hole perimeters
	if _path_crosses_holes(point1, point2):
		return true

	return false

func _path_crosses_holes(point1: Vector3, point2: Vector3) -> bool:
	# If no holes, path cannot cross them
	if cached_hole_polygons.size() == 0:
		return false

	var path_start = Vector2(point1.x, point1.z)
	var path_end = Vector2(point2.x, point2.z)

	# Check intersection with each hole polygon
	for hole_idx in range(cached_hole_polygons.size()):
		var hole_polygon = cached_hole_polygons[hole_idx]
		for i in range(hole_polygon.size()):
			var edge_start = hole_polygon[i]
			var edge_end = hole_polygon[(i + 1) % hole_polygon.size()]

			# Test if path line segment intersects hole edge
			if _line_segments_intersect_robust(path_start, path_end, edge_start, edge_end):
				return true

	return false

func _line_segments_intersect_robust(p1: Vector2, q1: Vector2, p2: Vector2, q2: Vector2) -> bool:
	# Calculate orientations for intersection test
	var o1 = _orientation(p1, q1, p2)
	var o2 = _orientation(p1, q1, q2)
	var o3 = _orientation(p2, q2, p1)
	var o4 = _orientation(p2, q2, q1)
	
	# General case - segments intersect if orientations differ
	if o1 != o2 and o3 != o4:
		return true
	
	# Special collinear cases
	if o1 == 0 and _point_on_segment_robust(p1, p2, q1):
		return true
	if o2 == 0 and _point_on_segment_robust(p1, q2, q1):
		return true
	if o3 == 0 and _point_on_segment_robust(p2, p1, q2):
		return true
	if o4 == 0 and _point_on_segment_robust(p2, q1, q2):
		return true
	
	return false

func _orientation(p: Vector2, q: Vector2, r: Vector2) -> int:
	# Calculate orientation of ordered triplet (p, q, r)
	var val = (q.y - p.y) * (r.x - q.x) - (q.x - p.x) * (r.y - q.y)
	
	if abs(val) < 1e-10:  # Floating point epsilon
		return 0  # Collinear
	
	return 1 if val > 0 else 2  # Clockwise or counterclockwise

func _point_on_segment_robust(p: Vector2, q: Vector2, r: Vector2) -> bool:
	return (q.x <= max(p.x, r.x) and q.x >= min(p.x, r.x) and
			q.y <= max(p.y, r.y) and q.y >= min(p.y, r.y))

# =============================================================================
# WAYPOINT VISITATION TRACKING FUNCTIONS
# =============================================================================
func _mark_waypoint_visited(waypoint: Vector3) -> void:
	# Create a unique key for this waypoint
	var key = str(snapped(waypoint.x, 0.01)) + "," + str(snapped(waypoint.z, 0.01))
	waypoint_visit_times[key] = Time.get_ticks_msec() / 1000.0

func _is_waypoint_available(waypoint: Vector3) -> bool:
	var key = str(snapped(waypoint.x, 0.01)) + "," + str(snapped(waypoint.z, 0.01))

	# If never visited, it's available
	if not waypoint_visit_times.has(key):
		return true

	# Check if cooldown period has passed
	var current_time = Time.get_ticks_msec() / 1000.0
	var time_since_visit = current_time - waypoint_visit_times[key]
	return time_since_visit >= waypoint_cooldown

func _get_waypoint_preference_score(waypoint: Vector3, distance: float) -> float:
	# Lower score = better choice
	# Score is based on distance, but heavily penalized if recently visited

	var base_score = distance

	# If waypoint is available (not recently visited), favor it
	if _is_waypoint_available(waypoint):
		base_score /= favor_unvisited_multiplier  # Make it much more attractive

	return base_score

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================
func _find_nearest_waypoint_to_position(position: Vector3) -> Vector3:
	if available_waypoints.size() == 0:
		return Vector3.INF

	var position_2d = Vector2(position.x, position.z)
	var best_point = Vector3.INF
	var best_score = INF

	# Find best waypoint considering both distance and visit history
	for point in available_waypoints:
		var point_2d = Vector2(point.x, point.z)
		var distance = position_2d.distance_to(point_2d)

		# Calculate preference score (lower is better)
		var score = _get_waypoint_preference_score(point, distance)

		if score < best_score:
			best_score = score
			best_point = point

	return best_point

# =============================================================================
# UTILITY FUNCTION
# =============================================================================
func _find_node_by_name(node: Node, name: String) -> Node:
	# Recursive search for node by name
	if node.name.to_lower() == name.to_lower():
		return node
	
	for child in node.get_children():
		var result = _find_node_by_name(child, name)
		if result:
			return result
	
	return null

# =============================================================================
# LEGACY FUNCTIONS (kept for compatibility)
# =============================================================================
func _pick_new_direction() -> void:
	# Legacy random direction picker - no longer used in pathfinding system
	var directions = [
		Vector2.ZERO,
		Vector2(0, -1), Vector2(0, 1),
		Vector2(-1, 0), Vector2(1, 0),
		Vector2(-1, -1), Vector2(1, -1),
		Vector2(-1, 1), Vector2(1, 1)
	]
	
	current_input = directions[randi() % directions.size()]
	direction_change_interval = randf_range(1.0, 3.0)

@tool
extends EditorPlugin

var menu_button: MenuButton
var popup: PopupMenu
var custom_dialog: ConfirmationDialog
var spin_x: SpinBox
var spin_y: SpinBox
var spin_z: SpinBox

enum PivotType {
	# Centers
	BOTTOM_CENTER,
	TOP_CENTER,
	CENTER,
	LEFT_CENTER,
	RIGHT_CENTER,
	FRONT_CENTER,
	BACK_CENTER,
	# Bottom 4 Corners
	BOTTOM_FRONT_LEFT,
	BOTTOM_FRONT_RIGHT,
	BOTTOM_BACK_LEFT,
	BOTTOM_BACK_RIGHT,
	# Top 4 Corners
	TOP_FRONT_LEFT,
	TOP_FRONT_RIGHT,
	TOP_BACK_LEFT,
	TOP_BACK_RIGHT,
	# Custom
	CUSTOM_POSITION
}

func _enter_tree():
	_remove_existing_pivot_buttons()

	# 1. Create MenuButton
	menu_button = MenuButton.new()
	menu_button.name = "ChangePivotMenuButton"
	menu_button.text = "Change Pivot"
	menu_button.tooltip_text = "Adjust Pivot Point location for selected Node3D or MeshInstance3D nodes"
	
	# 2. Configure Popup Menu
	popup = menu_button.get_popup()
	
	# Basic Centers
	popup.add_item("Center", PivotType.CENTER)
	popup.add_item("Bottom Center", PivotType.BOTTOM_CENTER)
	popup.add_item("Top Center", PivotType.TOP_CENTER)
	popup.add_item("Left Center", PivotType.LEFT_CENTER)
	popup.add_item("Right Center", PivotType.RIGHT_CENTER)
	popup.add_item("Front Center", PivotType.FRONT_CENTER)
	popup.add_item("Back Center", PivotType.BACK_CENTER)
	
	popup.add_separator("Bottom 4 Corners")
	popup.add_item("Bottom Front-Left", PivotType.BOTTOM_FRONT_LEFT)
	popup.add_item("Bottom Front-Right", PivotType.BOTTOM_FRONT_RIGHT)
	popup.add_item("Bottom Back-Left", PivotType.BOTTOM_BACK_LEFT)
	popup.add_item("Bottom Back-Right", PivotType.BOTTOM_BACK_RIGHT)
	
	popup.add_separator("Top 4 Corners")
	popup.add_item("Top Front-Left", PivotType.TOP_FRONT_LEFT)
	popup.add_item("Top Front-Right", PivotType.TOP_FRONT_RIGHT)
	popup.add_item("Top Back-Left", PivotType.TOP_BACK_LEFT)
	popup.add_item("Top Back-Right", PivotType.TOP_BACK_RIGHT)
	
	popup.add_separator()
	popup.add_item("Custom Scene Position (XYZ)...", PivotType.CUSTOM_POSITION)
	
	popup.id_pressed.connect(_on_pivot_option_selected)
	
	add_control_to_container(CONTAINER_SPATIAL_EDITOR_MENU, menu_button)
	
	# 3. Create Custom Dialog for XYZ input
	_create_custom_dialog()

func _exit_tree():
	_remove_existing_pivot_buttons()
	if custom_dialog:
		custom_dialog.queue_free()

func _remove_existing_pivot_buttons():
	if menu_button:
		remove_control_from_container(CONTAINER_SPATIAL_EDITOR_MENU, menu_button)
		menu_button.queue_free()
		menu_button = null

	var dummy = Control.new()
	add_control_to_container(CONTAINER_SPATIAL_EDITOR_MENU, dummy)
	var parent_container = dummy.get_parent()
	remove_control_from_container(CONTAINER_SPATIAL_EDITOR_MENU, dummy)
	dummy.queue_free()

	if parent_container:
		for child in parent_container.get_children():
			if child is Button and (child.text == "Change Pivot" or child.text.begins_with("Pivot")):
				parent_container.remove_child(child)
				child.queue_free()

func _create_custom_dialog():
	custom_dialog = ConfirmationDialog.new()
	custom_dialog.title = "Set Custom Pivot (Scene XYZ Position)"
	
	var grid = GridContainer.new()
	grid.columns = 2
	
	grid.add_child(_create_label("Scene X:"))
	spin_x = _create_spinbox()
	grid.add_child(spin_x)
	
	grid.add_child(_create_label("Scene Y:"))
	spin_y = _create_spinbox()
	grid.add_child(spin_y)
	
	grid.add_child(_create_label("Scene Z:"))
	spin_z = _create_spinbox()
	grid.add_child(spin_z)
	
	custom_dialog.add_child(grid)
	custom_dialog.confirmed.connect(_on_custom_dialog_confirmed)
	
	EditorInterface.get_base_control().add_child(custom_dialog)

func _create_label(text: String) -> Label:
	var lbl = Label.new()
	lbl.text = text
	return lbl

func _create_spinbox() -> SpinBox:
	var sb = SpinBox.new()
	sb.min_value = -100000.0
	sb.max_value = 100000.0
	sb.step = 0.001
	sb.custom_arrow_step = 0.1
	return sb

func _on_pivot_option_selected(id: int):
	if id == PivotType.CUSTOM_POSITION:
		var selection = EditorInterface.get_selection().get_selected_nodes()
		if not selection.is_empty() and selection[0] is Node3D:
			var pos = selection[0].global_position
			spin_x.value = pos.x
			spin_y.value = pos.y
			spin_z.value = pos.z
		custom_dialog.popup_centered(Vector2i(250, 160))
	else:
		_apply_pivot_change(id)

func _on_custom_dialog_confirmed():
	var target_scene_pos = Vector3(spin_x.value, spin_y.value, spin_z.value)
	_apply_custom_pivot(target_scene_pos)

func _apply_pivot_change(pivot_type: int):
	var selection = EditorInterface.get_selection().get_selected_nodes()
	if selection.is_empty():
		return

	var undo_redo = get_undo_redo()
	undo_redo.create_action("Change Pivot")
	var modified_any = false

	for node in selection:
		if node is MeshInstance3D and node.mesh:
			var orig_mesh = node.mesh
			var aabb = orig_mesh.get_aabb()
			var offset = calculate_pivot_offset(aabb, pivot_type)
			if offset.length() < 0.0001:
				continue
				
			var new_mesh = create_repositioned_mesh(orig_mesh, offset)
			if new_mesh == null or new_mesh.get_surface_count() == 0:
				continue
				
			var new_global_pos = node.global_position + (node.transform.basis * offset)
			
			undo_redo.add_do_property(node, "mesh", new_mesh)
			undo_redo.add_do_property(node, "global_position", new_global_pos)
			
			undo_redo.add_undo_property(node, "mesh", orig_mesh)
			undo_redo.add_undo_property(node, "global_position", node.global_position)
			modified_any = true
			
		elif node is Node3D:
			# Xử lý cho Node3D thông thường
			var combined_aabb = _get_combined_aabb_in_local(node)
			if combined_aabb.size == Vector3.ZERO:
				continue
				
			var offset = calculate_pivot_offset(combined_aabb, pivot_type)
			if offset.length() < 0.0001:
				continue
				
			var target_global_pos = node.global_transform * offset
			_reposition_node3d_pivot(node, target_global_pos, undo_redo)
			modified_any = true

	if modified_any:
		undo_redo.commit_action()
	else:
		undo_redo.undo()

func _apply_custom_pivot(target_scene_pos: Vector3):
	var selection = EditorInterface.get_selection().get_selected_nodes()
	if selection.is_empty():
		return

	var undo_redo = get_undo_redo()
	undo_redo.create_action("Change Custom Pivot")
	var modified_any = false

	for node in selection:
		if node is MeshInstance3D and node.mesh:
			var orig_mesh = node.mesh
			var world_offset = target_scene_pos - node.global_position
			var local_offset = node.global_transform.basis.inverse() * world_offset
			
			if local_offset.length() < 0.0001:
				continue
				
			var new_mesh = create_repositioned_mesh(orig_mesh, local_offset)
			if new_mesh == null or new_mesh.get_surface_count() == 0:
				continue
				
			undo_redo.add_do_property(node, "mesh", new_mesh)
			undo_redo.add_do_property(node, "global_position", target_scene_pos)
			
			undo_redo.add_undo_property(node, "mesh", orig_mesh)
			undo_redo.add_undo_property(node, "global_position", node.global_position)
			modified_any = true
			
		elif node is Node3D:
			_reposition_node3d_pivot(node, target_scene_pos, undo_redo)
			modified_any = true

	if modified_any:
		undo_redo.commit_action()
	else:
		undo_redo.undo()

# Dịch chuyển gốc Pivot của Node3D mà không làm thay đổi vị trí không gian của các Node con
func _reposition_node3d_pivot(node: Node3D, target_global_pos: Vector3, undo_redo: EditorUndoRedoManager):
	var old_global_pos = node.global_position
	var delta_pos = target_global_pos - old_global_pos
	
	if delta_pos.length() < 0.0001:
		return

	undo_redo.add_do_property(node, "global_position", target_global_pos)
	undo_redo.add_undo_property(node, "global_position", old_global_pos)

	for child in node.get_children():
		if child is Node3D:
			var old_child_pos = child.global_position
			undo_redo.add_do_property(child, "global_position", old_child_pos)
			undo_redo.add_undo_property(child, "global_position", old_child_pos)

# Tính tổng AABB của toàn bộ Mesh con bên trong Node3D
func _get_combined_aabb_in_local(parent: Node3D) -> AABB:
	var combined_aabb = AABB()
	var has_aabb = false
	
	var mesh_children = parent.find_children("*", "MeshInstance3D", true, false)
	for mesh_node in mesh_children:
		if mesh_node is MeshInstance3D and mesh_node.mesh:
			var mesh_aabb = mesh_node.mesh.get_aabb()
			# Transform AABB về không gian local của parent Node3D
			var xform = parent.global_transform.affine_inverse() * mesh_node.global_transform
			var transformed_aabb = xform * mesh_aabb
			
			if not has_aabb:
				combined_aabb = transformed_aabb
				has_aabb = true
			else:
				combined_aabb = combined_aabb.merge(transformed_aabb)
				
	return combined_aabb

func calculate_pivot_offset(aabb: AABB, pivot_type: int) -> Vector3:
	var center = aabb.get_center()
	var min_p = aabb.position
	var max_p = aabb.end
	
	match pivot_type:
		# Centers
		PivotType.CENTER:
			return center
		PivotType.BOTTOM_CENTER:
			return Vector3(center.x, min_p.y, center.z)
		PivotType.TOP_CENTER:
			return Vector3(center.x, max_p.y, center.z)
		PivotType.LEFT_CENTER:
			return Vector3(min_p.x, center.y, center.z)
		PivotType.RIGHT_CENTER:
			return Vector3(max_p.x, center.y, center.z)
		PivotType.FRONT_CENTER:
			return Vector3(center.x, center.y, max_p.z)
		PivotType.BACK_CENTER:
			return Vector3(center.x, center.y, min_p.z)
			
		# Bottom 4 Corners
		PivotType.BOTTOM_FRONT_LEFT:
			return Vector3(min_p.x, min_p.y, max_p.z)
		PivotType.BOTTOM_FRONT_RIGHT:
			return Vector3(max_p.x, min_p.y, max_p.z)
		PivotType.BOTTOM_BACK_LEFT:
			return Vector3(min_p.x, min_p.y, min_p.z)
		PivotType.BOTTOM_BACK_RIGHT:
			return Vector3(max_p.x, min_p.y, min_p.z)
			
		# Top 4 Corners
		PivotType.TOP_FRONT_LEFT:
			return Vector3(min_p.x, max_p.y, max_p.z)
		PivotType.TOP_FRONT_RIGHT:
			return Vector3(max_p.x, max_p.y, max_p.z)
		PivotType.TOP_BACK_LEFT:
			return Vector3(min_p.x, max_p.y, min_p.z)
		PivotType.TOP_BACK_RIGHT:
			return Vector3(max_p.x, max_p.y, min_p.z)
			
		_:
			return Vector3.ZERO

func create_repositioned_mesh(source_mesh: Mesh, offset: Vector3) -> ArrayMesh:
	var new_mesh = ArrayMesh.new()
	
	for i in range(source_mesh.get_surface_count()):
		var arrays = source_mesh.surface_get_arrays(i)
		if arrays.is_empty() or arrays[Mesh.ARRAY_VERTEX] == null:
			return null
			
		var vertex_array: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX].duplicate()
		
		for v_idx in range(vertex_array.size()):
			vertex_array[v_idx] -= offset
			
		arrays[Mesh.ARRAY_VERTEX] = vertex_array
		
		var mat = source_mesh.surface_get_material(i)
		var primitive_type = source_mesh.surface_get_primitive_type(i)
		var format = source_mesh.surface_get_format(i)
		
		new_mesh.add_surface_from_arrays(primitive_type, arrays, [], {}, format)
		if mat:
			new_mesh.surface_set_material(i, mat)
			
	return new_mesh

extends TileMapLayer

@onready var display_layer: TileMapLayer = $"WorldTile"

# Define your atlas coordinates for the 16 core combinations
# Order follows binary lookup flags: [TopLeft, TopRight, BottomLeft, BottomRight]
const DUAL_GRID_DICT = {
	0b0000: Vector2i(0, 0), # Fully empty
	0b0001: Vector2i(1, 0), # Bottom-Right corner
	0b0010: Vector2i(2, 0), # Bottom-Left corner
	0b0011: Vector2i(3, 0), # Bottom edge
	0b0100: Vector2i(0, 1), # Top-Right corner
	0b0101: Vector2i(1, 1), # Right edge
	0b0110: Vector2i(2, 1), # Diagonal split 1
	0b0111: Vector2i(3, 1), # Full except Top-Left
	0b1000: Vector2i(0, 2), # Top-Left corner
	0b1001: Vector2i(1, 2), # Diagonal split 2
	0b1010: Vector2i(2, 2), # Left edge
	0b1011: Vector2i(3, 2), # Full except Top-Right
	0b1100: Vector2i(0, 3), # Top edge
	0b1101: Vector2i(1, 3), # Full except Bottom-Left
	0b1110: Vector2i(2, 3), # Full except Bottom-Right
	0b1111: Vector2i(3, 3)  # Fully filled
}

func _use_tile_data_runtime_update(coords: Vector2i) -> bool:
	return true

# Automatically update the display map whenever you draw on the logical layer
func _on_cells_changed(changed_cells: Array[Vector2i]) -> void:
	for cell in changed_cells:
		# Any single logical change alters a 2x2 grid of display tiles around it
		for x_offset in range(0, 2):
			for y_offset in range(0, 2):
				update_display_tile(cell + Vector2i(x_offset, y_offset))

func update_display_tile(display_coords: Vector2i) -> void:
	# Query the 4 logical cells surrounding this visual intersection
	var tl = 1 if get_cell_source_id(display_coords + Vector2i(-1, -1)) != -1 else 0
	var tr = 1 if get_cell_source_id(display_coords + Vector2i(0, -1)) != -1 else 0
	var bl = 1 if get_cell_source_id(display_coords + Vector2i(-1, 0)) != -1 else 0
	var br = 1 if get_cell_source_id(display_coords + Vector2i(0, 0)) != -1 else 0
	
	# Synthesize into a 4-bit integer
	var bitmask = (tl << 3) | (tr << 2) | (bl << 1) | br
	
	if bitmask in DUAL_GRID_DICT:
		var atlas_coords = DUAL_GRID_DICT[bitmask]
		display_layer.set_cell(display_coords, 0, atlas_coords)
	else:
		display_layer.erase_cell(display_coords)

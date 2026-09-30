class_name TileLayersState
extends RefCounted

## One PackedScene per scene layer (resolved at state build time).
var scene_layers: Array = []
## One resource path per multimesh layer (resolved at state build time).
var multi_mesh_layers: Array = []
var scene_layer_rotations: Array[float] = []
var animal_model: String = ""
var element: int = GameEnums.ELEMENT.NONE
var orientation_steps: int = 0
var _signature: String = ""


static func create(
	resolved_scene_layers: Array,
	resolved_multimesh_layers: Array,
	resolved_rotations: Array[float] = [],
	layer_signature: String = "",
	resolved_animal_model: String = "",
	resolved_element: int = GameEnums.ELEMENT.NONE,
	resolved_orientation_steps: int = 0
) -> TileLayersState:
	var state := TileLayersState.new()
	state.scene_layers = resolved_scene_layers
	state.multi_mesh_layers = resolved_multimesh_layers
	state.scene_layer_rotations = resolved_rotations
	state.animal_model = resolved_animal_model
	state.element = resolved_element
	state.orientation_steps = resolved_orientation_steps
	state._signature = layer_signature
	return state


func signature() -> String:
	return _signature


func override_signature_suffix(suffix: String) -> void:
	_signature = "%s|%s" % [_signature, suffix]


func duplicate_state() -> TileLayersState:
	return create(
		scene_layers,
		multi_mesh_layers,
		scene_layer_rotations.duplicate(),
		_signature,
		animal_model,
		element,
		orientation_steps
	)


func matches(other: TileLayersState) -> bool:
	if other == null:
		return false
	return (
		signature() == other.signature()
		and animal_model == other.animal_model
		and element == other.element
		and orientation_steps == other.orientation_steps
	)

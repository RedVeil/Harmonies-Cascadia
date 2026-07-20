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
	scene_layer_rotations: Array[float] = [],
	signature: String = "",
	animal_model: String = "",
	element: int = GameEnums.ELEMENT.NONE,
	orientation_steps: int = 0
) -> TileLayersState:
	var state := TileLayersState.new()
	state.scene_layers = resolved_scene_layers
	state.multi_mesh_layers = resolved_multimesh_layers
	state.scene_layer_rotations = scene_layer_rotations
	state.animal_model = animal_model
	state.element = element
	state.orientation_steps = orientation_steps
	state._signature = signature
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

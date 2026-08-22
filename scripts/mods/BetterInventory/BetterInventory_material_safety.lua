local MaterialSafety = {}

local TEXTURE_PASS_TYPES = {
	rotated_texture = true,
	texture = true,
	texture_uv = true,
}
local DEFAULT_TEXTURE_MATERIAL = "content/ui/materials/icons/items/containers/item_container_landscape"
local GUARDED_MARKER = "better_inventory_material_guarded"
local WARNING_MARKER_PREFIX = "better_inventory_invalid_material_warning_"

local function valid_material_reference(value)
	local value_type = type(value)

	return value_type == "userdata" or value_type == "string" and value ~= ""
end

local function resolved_fallback(pass, explicit_fallback)
	if valid_material_reference(explicit_fallback) then
		return explicit_fallback
	end

	local pass_fallback = pass and pass.value

	return valid_material_reference(pass_fallback) and pass_fallback or DEFAULT_TEXTURE_MATERIAL
end

local function warn_once(mod, content, value_id, invalid_value, fallback)
	if type(content) ~= "table" then
		return
	end

	local marker = WARNING_MARKER_PREFIX .. tostring(value_id)

	if content[marker] then
		return
	end

	content[marker] = true

	if mod and type(mod.warning) == "function" then
		pcall(mod.warning, mod, "Repaired invalid UI material for '%s' (%s); using '%s'.", tostring(value_id), type(invalid_value), tostring(fallback))
	end
end

local function repair_dynamic_material(mod, content, value_id, fallback)
	if type(content) ~= "table" or type(value_id) ~= "string" or value_id == "" then
		return false
	end

	local value = content[value_id]

	if valid_material_reference(value) then
		return false
	end

	content[value_id] = fallback
	warn_once(mod, content, value_id, value, fallback)

	return true
end

local function guard_pass(mod, pass, explicit_fallback)
	if type(pass) ~= "table" or not TEXTURE_PASS_TYPES[pass.pass_type] or type(pass.value_id) ~= "string" or pass.value_id == "" then
		return false
	end

	if pass[GUARDED_MARKER] then
		return false
	end

	local fallback = resolved_fallback(pass, explicit_fallback)
	local value_id = pass.value_id
	local original_change_function = pass.change_function

	pass.value = valid_material_reference(pass.value) and pass.value or fallback
	pass[GUARDED_MARKER] = true
	pass.change_function = function(content, style, animations, dt)
		-- Repair before delegating so compatibility callbacks never receive the
		-- numeric render-target grid index as the card's material reference.
		repair_dynamic_material(mod, content, value_id, fallback)

		if type(original_change_function) == "function" then
			original_change_function(content, style, animations, dt)
		end

		-- A native or third-party callback may itself rewrite the dynamic value.
		-- Revalidate immediately before UIPasses asks UIRenderer to create it.
		repair_dynamic_material(mod, content, value_id, fallback)
	end

	return true
end

MaterialSafety.guard_blueprint = function(mod, blueprint)
	local passes = blueprint and blueprint.pass_template

	if type(passes) ~= "table" then
		return 0
	end

	local guarded = 0

	for index = 1, #passes do
		guarded = guard_pass(mod, passes[index]) and guarded + 1 or guarded
	end

	return guarded
end

MaterialSafety.guard_widget = function(mod, widget, explicit_fallback)
	local passes = widget and widget.passes

	if type(passes) ~= "table" then
		return 0
	end

	local guarded = 0

	for index = 1, #passes do
		local pass = passes[index]
		local fallback = pass and pass.style_id == "icon" and explicit_fallback or nil

		guarded = guard_pass(mod, pass, fallback) and guarded + 1 or guarded
	end

	return guarded
end

MaterialSafety.guard_inventory_widget = function(mod, item_grid, widget)
	local view = item_grid and item_grid._parent

	if not view or view.__class_name ~= "InventoryWeaponsView" or item_grid ~= view._item_grid then
		return 0
	end

	return MaterialSafety.guard_widget(mod, widget)
end

MaterialSafety.valid_material_reference = valid_material_reference
MaterialSafety.repair_dynamic_material = repair_dynamic_material
MaterialSafety.guard_pass = guard_pass
MaterialSafety.DEFAULT_TEXTURE_MATERIAL = DEFAULT_TEXTURE_MATERIAL

return MaterialSafety

local mod = get_mod("BetterInventory")

local InventoryWeaponsView = require("scripts/ui/views/inventory_weapons_view/inventory_weapons_view")
local ViewElementGrid = require("scripts/ui/view_elements/view_element_grid/view_element_grid")
local Layout = mod:io_dofile("BetterInventory/scripts/mods/BetterInventory/BetterInventory_layout")
local active_inventory_view

mod:hook(InventoryWeaponsView, "present_grid_layout", function(func, view, layout, on_present_callback)
	if not Layout.is_enabled_for_view(mod, view) then
		return func(view, layout, on_present_callback)
	end

	-- Mark only this call, then continue through the complete DMF hook chain.
	-- The grid hook below transforms whichever blueprints reach the base view,
	-- including changes made by compatible sorting or information mods.
	local previous_active_view = active_inventory_view

	active_inventory_view = view

	local result = func(view, layout, on_present_callback)

	active_inventory_view = previous_active_view

	return result
end)

mod:hook(ViewElementGrid, "present_grid_layout", function(func, item_grid, layout, content_blueprints, ...)
	local view = active_inventory_view
	local definitions = view and view._definitions
	local grid_settings = definitions and definitions.grid_settings
	local grid_size = grid_settings and grid_settings.grid_size
	local item_blueprint = content_blueprints and content_blueprints.item

	-- Restrict the global grid seam to the active InventoryWeaponsView item
	-- grid. Missing fields mean the game contract changed, so pass through.
	if not view or item_grid ~= view._item_grid or not grid_size or not grid_size[1] or not item_blueprint or not item_blueprint.pass_template then
		return func(item_grid, layout, content_blueprints, ...)
	end

	local local_blueprints = table.clone(content_blueprints)
	local local_item_blueprint = local_blueprints.item

	Layout.configure_item_blueprint(mod, local_item_blueprint, grid_size[1])
	Layout.configure_grid(mod, item_grid)

	return func(item_grid, layout, local_blueprints, ...)
end)

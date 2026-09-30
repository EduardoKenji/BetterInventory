-- Cached ItemSorting option signatures and native-option boundary.
-- View signatures stay on the view; localized native labels are resolved lazily.
local SortOptions = {}
local dependencies = {}
local native_ids

SortOptions.configure = function(options)
	dependencies = type(options) == "table" and options or {}
	native_ids = nil
end

local function definition_id(groups, option)
	if groups then
		for _, group in pairs(groups) do
			for _, definition in ipairs(group) do
				if option and definition.display_name == option.display_name then return definition.id end
			end
		end
	end
end

local function option_id(option)
	if not native_ids then
		native_ids = {}
		for _, definition in ipairs({
			{ "level_desc", "item_power", "high_low" }, { "level_asc", "item_power", "low_high" },
			{ "rarity_desc", "rarity", "high_low" }, { "rarity_asc", "rarity", "low_high" },
			{ "name_asc", "name", "increasing_letters" }, { "name_desc", "name", "decreasing_letters" },
			{ "price_asc", "item_price", "low_high" }, { "price_desc", "item_price", "high_low" },
		}) do
			local label = Localize("loc_inventory_item_grid_sort_title_format_" .. definition[3], true, {
				sort_name = Localize("loc_inventory_item_grid_sort_title_" .. definition[2]),
			})
			native_ids[label] = definition[1]
		end
	end
	local id = option and native_ids[option.display_name]
	if id then return id end
	local integration = dependencies.sorting
	local definitions = integration and integration.definitions()
	if definitions then
		return definition_id(definitions.customized_vanilla_methods, option) or definition_id(definitions.modded_methods, option)
	end
end

local function option_enabled(mod, option)
	local id = option_id(option)
	-- Unknown third-party choices remain available.
	return not id or mod:get("sort_option_" .. id) ~= false
end

SortOptions.is_visible = function(mod, options, index)
	if option_enabled(mod, options[index]) then return true end
	local fallback = 1
	for option_index = 1, #options do
		if option_enabled(mod, options[option_index]) then return false end
		if option_id(options[option_index]) == "name_asc" then fallback = option_index end
	end
	return index == fallback
end

SortOptions.any_visible = function(mod, options, first, last)
	for index = first, last do
		if SortOptions.is_visible(mod, options, index) then return true end
	end
	return false
end

SortOptions.next_index = function(mod, item_grid, start_index)
	local options = item_grid._sort_options or {}
	if #options == 0 then return start_index end
	local index = start_index or (item_grid._active_sort_index or 0) % #options + 1
	if index < 1 or index > #options then index = 1 end
	if option_enabled(mod, options[index]) then return start_index end
	for _ = 1, #options do
		if SortOptions.is_visible(mod, options, index) then return index end
		index = index % #options + 1
	end
end

SortOptions.panel_entry = function(mod, view, option, option_index)
	if not SortOptions.is_visible(mod, view._sort_options, option_index) then return end
	local geometry = view._better_inventory_options_panel_geometry

	return dependencies.panel_entry(view, "better_inventory_item_sorting_option_" .. tostring(option_index), 32, dependencies.option_passes(geometry.content_width), {
		hotspot = {},
		label = option.display_name or tostring(option_index),
		selected = (view._selected_sort_option_index or 1) == option_index,
	}, function(widget)
		widget.content.hotspot.pressed_callback = function()
			local item_grid = view._item_grid

			if item_grid and type(item_grid.trigger_sort_index) == "function" then
				item_grid:trigger_sort_index(option_index)
			elseif type(view.cb_on_sort_button_pressed) == "function" then
				view:cb_on_sort_button_pressed(option)
			end
		end
	end, function(widget)
		widget.content.selected = (view._selected_sort_option_index or 1) == option_index
	end, { "hotspot" })
end

SortOptions.sync_views = function(setting_id)
	if setting_id ~= nil and string.sub(setting_id, 1, 12) ~= "sort_option_" then return end
	for view in pairs(dependencies.inventory_views) do
		view._better_inventory_options_panel_structure_key = nil
		dependencies.invalidate_view(view)
	end
	for view in pairs(dependencies.armoury_views) do
		view._better_inventory_armoury_native_sort_rebuild_pending = true
		dependencies.invalidate_view(view)
	end
end

SortOptions.install = function(mod, ViewElementGrid, resolve_grid_scope)
	if type(ViewElementGrid._cb_on_sort_button_pressed) ~= "function" then return end
	mod:hook(ViewElementGrid, "_cb_on_sort_button_pressed", function(func, item_grid, start_index, ...)
		local view = resolve_grid_scope(item_grid)
		if view and item_grid == view._item_grid then
			start_index = SortOptions.next_index(mod, item_grid, start_index)
		end
		return func(item_grid, start_index, ...)
	end)
end

local function item_sorting_is_enabled()
	local fn = dependencies.item_sorting_is_enabled

	return type(fn) == "function" and fn() or false
end

local function is_armoury_sort_view(view)
	local fn = dependencies.is_armoury_sort_view

	return type(fn) == "function" and fn(view) or false
end

local function sorting()
	return dependencies.sorting
end

local function signature(parts)
	local fn = dependencies.signature

	return type(fn) == "function" and fn(parts) or table.concat(parts or {}, "|")
end

local function count_diagnostic(name, amount)
	local fn = dependencies.count_diagnostic

	if type(fn) == "function" then
		return fn(name, amount)
	end
end

local function item_sorting_custom_option_start(view)
	local integration = sorting()

	return integration and integration.native_option_start(view, is_armoury_sort_view) or #(view and view._sort_options or {}) + 1
end

local function item_sorting_options_signature(view)
	local item_sorting_active = item_sorting_is_enabled()

	if not item_sorting_active then
		if view and view._better_inventory_item_sorting_signature_cache and view._better_inventory_item_sorting_signature_cache.enabled ~= false then
			view._better_inventory_item_sorting_signature_cache = {
				enabled = false,
				value = "",
			}
			view._better_inventory_item_sorting_signature_poll = 0
		end

		return ""
	end

	if view then
		local cache = view._better_inventory_item_sorting_signature_cache
		local poll = (view._better_inventory_item_sorting_signature_poll or 0) + 1

		view._better_inventory_item_sorting_signature_poll = poll

		-- ItemSorting settings are external to BetterInventory. Keep a bounded
		-- compatibility poll, but avoid rebuilding the signature table/string on
		-- every idle vendor or inventory frame.
		if cache and cache.enabled == true and poll < 15 then
			return cache.value
		end

		view._better_inventory_item_sorting_signature_poll = 0
	end

	local sort_options = view and view._sort_options or {}
	local parts = {
		tostring(item_sorting_custom_option_start(view)),
		tostring(#sort_options),
	}

	for index = 1, #sort_options do
		parts[#parts + 1] = tostring(sort_options[index].display_name or index)
	end

	local signature = signature(parts)
	count_diagnostic("panel_signatures")

	if view then
		local cache = view._better_inventory_item_sorting_signature_cache

		if cache and cache.enabled == true and cache.value == signature then
			return cache.value
		end

		view._better_inventory_item_sorting_signature_cache = {
			enabled = true,
			value = signature,
		}
	end

	return signature
end
SortOptions.item_sorting_custom_option_start = item_sorting_custom_option_start
SortOptions.item_sorting_options_signature = item_sorting_options_signature

return SortOptions

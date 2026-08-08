-- Cached ItemSorting option signatures and native-option boundary.
-- No module-owned mutable state; cache remains attached to each view.
local SortOptions = {}
local dependencies = {}

SortOptions.configure = function(options)
	dependencies = type(options) == "table" and options or {}
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

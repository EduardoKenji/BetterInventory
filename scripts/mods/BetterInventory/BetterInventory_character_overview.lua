local CharacterOverview = {}

local function item_value(item, ...)
	if type(item) ~= "table" and type(item) ~= "userdata" then
		return
	end

	for index = 1, select("#", ...) do
		local key = select(index, ...)
		local value = item[key]

		if value ~= nil then
			return value
		end
	end
end

local function collection_count(value)
	return type(value) == "table" and #value or -1
end

CharacterOverview.identity = function(item)
	return item_value(item, "gear_id", "item_id", "id")
end

CharacterOverview.content_revision = function(item)
	if type(item) ~= "table" and type(item) ~= "userdata" then
		return nil, nil, nil, nil, nil, -1, -1, -1, -1
	end

	return item_value(item, "content_revision", "item_revision", "revision", "version"),
		item_value(item, "name", "display_name", "item_name"),
		item_value(item, "icon", "icon_name", "icon_material"),
		item_value(item, "item_level", "level"),
		item.rarity,
		collection_count(item.traits),
		collection_count(item.perks),
		collection_count(item.properties),
		collection_count(item.stats)
end

CharacterOverview.changed = function(previous_item, current_item)
	-- Overview widgets keep the same authoritative item object for almost every
	-- frame. Besides being the common fast path, equal references cannot expose
	-- an in-place revision by comparing fields on the object to themselves.
	if previous_item == current_item then
		return false
	end

	if previous_item == nil or current_item == nil then
		return previous_item ~= current_item
	end

	local previous_identity = CharacterOverview.identity(previous_item)
	local current_identity = CharacterOverview.identity(current_item)

	if previous_identity ~= nil or current_identity ~= nil then
		if previous_identity ~= current_identity then
			return true
		end
	end

	local previous_revision, previous_name, previous_icon, previous_level, previous_rarity, previous_traits, previous_perks, previous_properties, previous_stats = CharacterOverview.content_revision(previous_item)
	local current_revision, current_name, current_icon, current_level, current_rarity, current_traits, current_perks, current_properties, current_stats = CharacterOverview.content_revision(current_item)

	return previous_revision ~= current_revision or previous_name ~= current_name or previous_icon ~= current_icon or previous_level ~= current_level or previous_rarity ~= current_rarity or previous_traits ~= current_traits or previous_perks ~= current_perks or previous_properties ~= current_properties or previous_stats ~= current_stats
end

-- This is deliberately a complete, immutable-by-convention description of the
-- item identity/content inputs. Blueprint code may add layout-only state, but
-- it must not reuse this table for a different equipped item.
CharacterOverview.build_model = function(item, category, options)
	local model = {
		category = category or "unknown",
		empty = item == nil,
		selected = options and options.selected == true or false,
		widget_type = options and options.widget_type,
	}

	if item == nil then
		return model
	end

	local revision, name, icon, level, rarity, traits, perks, properties, stats = CharacterOverview.content_revision(item)

	model.identity = CharacterOverview.identity(item)
	model.revision = revision
	model.name = name
	model.icon = icon
	model.item_level = level
	model.rarity = rarity
	model.traits_count = traits
	model.perks_count = perks
	model.properties_count = properties
	model.stats_count = stats
	model.render_key = table.concat({
		 tostring(model.category),
		 tostring(model.identity),
		 tostring(model.revision),
		 tostring(model.name),
		 tostring(model.icon),
		 tostring(model.item_level),
		 tostring(model.rarity),
		 tostring(model.traits_count),
		 tostring(model.perks_count),
		 tostring(model.properties_count),
		 tostring(model.stats_count),
	}, "|")

	return model
end

-- Variable-height Curio content is owned by the widget. Clear every derived
-- value before native update_data repopulates it; this prevents old stat rows
-- and fitted names from surviving a one-line -> multi-line item swap.
CharacterOverview.clear_derived_content = function(content, maximum_stats)
	if type(content) ~= "table" then
		return false
	end

	content.better_inventory_curio_fit_initialized = nil
	content.better_inventory_curio_fit_stat_sources = nil
	content.better_inventory_curio_fit_stat_widths = nil
	content.better_inventory_curio_fit_name_source = nil
	content.better_inventory_curio_fit_title_width = nil
	content.better_inventory_curio_fit_title_font_size = nil
	content.better_inventory_curio_fit_title_line_limit = nil
	content.better_inventory_full_display_name = nil
	content.better_inventory_fitted_curio_name = nil
	content.better_inventory_curio_fit_normalized_values = nil
	content.better_inventory_curio_fit_raw_values = nil

	for index = 1, maximum_stats or 4 do
		content["better_inventory_overview_full_curio_stat_" .. index] = nil
		content["better_inventory_overview_fitted_curio_stat_" .. index] = nil
	end

	return true
end

return CharacterOverview

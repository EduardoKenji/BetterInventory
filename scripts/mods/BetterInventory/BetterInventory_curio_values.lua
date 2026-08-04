local BuffTemplates = require("scripts/settings/buff/buff_templates")
local Items = require("scripts/utilities/items")
local MasterItems = require("scripts/backend/master_items")

local CurioValues = {}

local TRAIT_BUFF_NAMES = {
	gadget_innate_health_increase = "max_health_modifier",
	gadget_innate_toughness_increase = "toughness_bonus",
	gadget_innate_max_wounds_increase = "extra_max_amount_of_wounds",
	gadget_stamina_increase = "stamina_modifier",
}

local function rounded(value)
	return math.floor(value + 0.5)
end

local function stepped_value(range, interpolation)
	if type(range) ~= "table" or #range == 0 then
		return
	end

	local index = math.clamp(rounded(1 + (#range - 1) * interpolation), 1, #range)

	return tonumber(range[index])
end

local function buff_value(trait_name, interpolation)
	local template = BuffTemplates and BuffTemplates[trait_name]
	local buff_name = TRAIT_BUFF_NAMES[trait_name]
	local buffs = template and (template.stat_buffs or template.lerped_stat_buffs)
	local buff = buffs and buff_name and buffs[buff_name]

	if not template or not buff then
		return
	end

	local value

	if template.lerped_stat_buffs and type(buff) == "table" then
		local minimum = tonumber(buff.min)
		local maximum = tonumber(buff.max)

		if not minimum or not maximum then
			return
		end

		if type(buff.lerp_value_func) == "function" then
			local success, result = pcall(buff.lerp_value_func, minimum, maximum, interpolation)

			value = success and tonumber(result) or nil
		else
			value = minimum + (maximum - minimum) * interpolation
		end
	elseif template.class_name == "stepped_range_buff" then
		value = stepped_value(buff, interpolation)
	else
		value = tonumber(buff)
	end

	if not value then
		return
	end

	local localization_info = template.localization_info

	if localization_info and localization_info[buff_name] == "percentage" then
		value = value * 100
	end

	return rounded(value)
end

local function first_description_number(value)
	if type(value) ~= "string" then
		return
	end

	value = string.gsub(value, "{#[^}]*}", "")
	value = string.gsub(value, "<[^>]*>", "")

	local number = string.match(value, "([%d]+%.?[%d]*)")

	return number and tonumber(number) or nil
end

function CurioValues.resolve(entry)
	if type(entry) ~= "table" or type(entry.id) ~= "string" then
		return
	end

	local success, definition = pcall(MasterItems.get_item, entry.id)
	local trait_name = success and definition and definition.trait

	if type(trait_name) ~= "string" then
		return
	end

	local interpolation = tonumber(entry.value)
	local value = interpolation and buff_value(trait_name, math.clamp(interpolation, 0, 1)) or nil

	-- BuffTemplates are stable gameplay data and remain authoritative even when a
	-- presentation mod hooks Items.trait_description. Description parsing is only
	-- a compatibility fallback for future or partially available templates.
	if not value and type(Items.trait_description) == "function" then
		local described, description = pcall(Items.trait_description, definition, entry.rarity or 0, entry.value or 0)

		value = described and first_description_number(description) or nil
	end

	return trait_name, value, definition
end

CurioValues._test = {
	buff_value = buff_value,
	first_description_number = first_description_number,
}

return CurioValues

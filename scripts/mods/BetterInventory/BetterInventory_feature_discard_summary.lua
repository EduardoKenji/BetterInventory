-- Shared discard rarity-summary formatter. Stateless presentation helper.
local DiscardSummary = {}
local RaritySettings = require("scripts/settings/item/rarity_settings")

local function summary_type_name(mod, count, singular_id, plural_id)
	return mod:localize(count == 1 and singular_id or plural_id)
end

local function rarity_summary(mod, candidates)
	local counts = {}
	local lines = {}

	for index = 1, #candidates do
		local item = candidates[index]
		local rarity = tonumber(item.rarity)

		if rarity then
			local rarity_counts = counts[rarity] or {
				curios = 0,
				melee = 0,
				ranged = 0,
				total = 0,
			}

			rarity_counts.total = rarity_counts.total + 1

			if item.item_type == "WEAPON_MELEE" then
				rarity_counts.melee = rarity_counts.melee + 1
			elseif item.item_type == "WEAPON_RANGED" then
				rarity_counts.ranged = rarity_counts.ranged + 1
			elseif item.item_type == "GADGET" then
				rarity_counts.curios = rarity_counts.curios + 1
			end

			counts[rarity] = rarity_counts
		end
	end

	for rarity = 1, 5 do
		local rarity_counts = counts[rarity]

		if rarity_counts then
			local settings = RaritySettings[rarity]
			local color = settings and settings.color or Color.white(255, true)
			local name = settings and Localize(settings.display_name) or tostring(rarity)
			local breakdown = ""

			if mod:get("quick_discard_show_type_breakdown") ~= false then
				breakdown = string.format(" (%d %s, %d %s %s %d %s)", rarity_counts.melee, summary_type_name(mod, rarity_counts.melee, "quick_discard_summary_melee_singular", "quick_discard_summary_melee_plural"), rarity_counts.ranged, summary_type_name(mod, rarity_counts.ranged, "quick_discard_summary_ranged_singular", "quick_discard_summary_ranged_plural"), mod:localize("quick_discard_summary_and"), rarity_counts.curios, summary_type_name(mod, rarity_counts.curios, "quick_discard_summary_curio_singular", "quick_discard_summary_curio_plural"))
			end

			lines[#lines + 1] = string.format("{#color(%d,%d,%d)}%d %s%s{#reset()}", color[2], color[3], color[4], rarity_counts.total, name, breakdown)
		end
	end

	return table.concat(lines, "\n")
end
DiscardSummary.summary_type_name = summary_type_name
DiscardSummary.rarity_summary = rarity_summary

return DiscardSummary

from pathlib import Path

from coverage_support import InstrumentedLuaRuntime as LuaRuntime


PROJECT_ROOT = Path(__file__).resolve().parents[1]
BACKEND_PATH = (
    PROJECT_ROOT
    / "scripts"
    / "mods"
    / "BetterInventory"
    / "auto_crafter"
    / "darktide"
    / "backend.lua"
)


def main() -> None:
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute(
        r'''
        local function resolved(value)
            local promise = {value = value}
            function promise:next(callback)
                local result = callback(self.value)
                if type(result) == "table" and type(result.next) == "function" then return result end
                return resolved(result)
            end
            function promise:catch(_) return self end
            return promise
        end

        package.preload["scripts/foundation/utilities/promise"] = function()
            return {resolved = resolved, rejected = resolved}
        end
        package.preload["scripts/utilities/items"] = function()
            return {
                expertise_level = function(item) return item.expertise_level or 300 end,
                is_item_id_favorited = function() return false end,
                max_expertise_level = function() return 500 end,
                preview_stats_change = function() return {} end,
                weapon_card_display_name = function(item) return item.card_display_name or item.name end,
                weapon_card_sub_display_name = function(item) return item.card_sub_display_name or "n/a" end,
            }
        end
        package.preload["scripts/utilities/mastery"] = function() return {} end
        test_master_items = {}
        test_master_items_version = 1
        package.preload["scripts/backend/master_items"] = function()
            return {
				get_item = function(item_id)
					return test_master_items[item_id] or {name = item_id, item_type = string.find(item_id, "perk", 1, true) and "PERK" or "TRAIT"}
                end,
                get_cached = function() return test_master_items end,
                get_cached_version = function() return test_master_items_version end,
                get_item_instance = function(raw_item)
                    if raw_item.invalid then return nil end
                    return raw_item
                end,
                get_store_item_instance = function(description)
                    local choices = description and description.lootChoices
                    local choice = choices and choices[1]
                    local master_id = type(choice) == "table" and (choice.masterId or choice.master_id) or choice
                    return test_master_items[master_id]
                end,
            }
        end
        package.preload["scripts/utilities/profile_utils"] = function() return {} end
        package.preload["scripts/settings/item/crafting_settings"] = function()
			return {
				recipes = {
					replace_perk = {is_valid_item = function(item) return item.item_type == "WEAPON_MELEE" or item.item_type == "WEAPON_RANGED" end},
					replace_trait = {is_valid_item = function(item) return item.item_type == "WEAPON_MELEE" or item.item_type == "WEAPON_RANGED" end},
				},
			}
		end
		package.preload["scripts/settings/item/rank_settings"] = function()
			return {max_perk_rank = 4, max_trait_rank = 4}
		end
        package.preload["scripts/utilities/weapon/weapon_template"] = function()
            return {weapon_template_from_item = function() return nil end}
        end

        Managers = {
            player = {
                local_player = function()
                    return {character_id = function() return "character-1" end}
                end,
            },
        }

        function make_services(gear, store)
            return {
                store = {
                    get_credits_goods_store = function() return resolved(store or {offers = {}}) end,
                    combined_wallets = function() return resolved({}) end,
                },
                gear = {fetch_gear = function() return resolved(gear) end},
            }
        end
        '''
    )
    backend_module = lua.execute(
        BACKEND_PATH.read_text(encoding="utf-8"), name=str(BACKEND_PATH)
    )
    lua.globals().Backend = backend_module
    lua.execute(
        r'''
        local gear = {}
        for index = 1, 1025 do
            local id = "gear-" .. tostring(index)
            gear[id] = {
                uuid = id,
                characterId = "character-1",
                name = "weapon-" .. tostring(index),
                parent_pattern = "pattern-1",
                rarity = 1,
                base_stats = {{name = "damage_stat", value = 0.6}},
            }
        end
        gear["malformed-record"] = {
            uuid = "malformed-record",
            characterId = "character-1",
            invalid = true,
            name = "random-item",
        }
        gear["other-character"] = {
            uuid = "other-character",
            characterId = "character-2",
            name = "weapon-other",
        }

        local snapshot
        Backend.new({services = make_services(gear)}):probe_snapshot():next(function(value) snapshot = value end)
        assert(snapshot.gear.raw_item_count == 1027)
        assert(snapshot.gear.item_count == 1026)
        assert(#snapshot.gear.items == 1026)
        assert(snapshot.gear.items_by_id["gear-1025"].available == true)
        assert(snapshot.gear.items.by_id["gear-1025"].gear_id == "gear-1025")
        assert(snapshot.gear.items_by_id["malformed-record"].available == false)
        assert(snapshot.gear.unavailable_item_count == 1)
        assert(snapshot.gear.items_by_id["other-character"] == nil)

        test_master_items = {}
        local function shovel_mark(master_id, pattern_loc_id, mark_loc_id, sub_display_name)
            return {
                name = master_id,
                item_type = "WEAPON_MELEE",
                slots = {"slot_primary"},
                parent_pattern = "sapper-shovel-pattern",
                weapon_progression_template = "sapper-shovel-template",
                weapon_family_display_name = {loc_id = "loc_sapper_shovel"},
                weapon_pattern_display_name = {loc_id = pattern_loc_id},
                weapon_mark_display_name = {loc_id = mark_loc_id},
                card_display_name = "Sapper Shovel",
                card_sub_display_name = sub_display_name,
            }
        end

        test_master_items["shovel-mk-1"] = shovel_mark("shovel-mk-1", "loc_munitorum", "loc_mk_1", "Munitorum • Mk I")
        test_master_items["shovel-mk-3"] = shovel_mark("shovel-mk-3", "loc_munitorum", "loc_mk_3", "Munitorum • Mk III")
        test_master_items["shovel-mk-7"] = shovel_mark("shovel-mk-7", "loc_munitorum", "loc_mk_7", "Munitorum • Mk VII")

        -- MasterItems.get_cached() may include family prototypes that share the
        -- live parent/slot/template contract but have no renderable mark identity.
        test_master_items["shovel-family-prototype"] = shovel_mark("shovel-family-prototype", "", "", '<unlocalized "": string not found>')
        test_master_items["shovel-bad-localization"] = shovel_mark("shovel-bad-localization", "loc_munitorum", "loc_bad", '<unlocalized "loc_bad": string not found>')
        test_master_items["shovel-bad-localization"].card_display_name = '<unlocalized "loc_sapper_shovel_bad": string not found>'

        local shovel_store = {
            offers = {{
                offerId = "offer-shovel",
                description = {lootChoices = {{masterId = "shovel-mk-1"}}},
                price = {amount = {type = "credits", amount = 9200}},
            }},
        }
        local shovel_snapshot
        local shovel_backend = Backend.new({services = make_services({}, shovel_store)})
        shovel_backend:probe_snapshot():next(function(value) shovel_snapshot = value end)
        local marks = shovel_snapshot.store.offers[1].marks
        assert(#marks == 3)
        assert(marks[1].master_id == "shovel-mk-1")
        assert(marks[2].master_id == "shovel-mk-3")
        assert(marks[3].master_id == "shovel-mk-7")
        for _, mark in ipairs(marks) do
            assert(string.find(mark.display_name, "<unlocalized", 1, true) == nil)
            assert(string.find(mark.sub_display_name, "<unlocalized", 1, true) == nil)
        end

        -- MasterItems can refresh its catalogue in place. Rebuild the derived
        -- mark index on its scalar version without strongly retaining the full
        -- catalogue table as an identity sentinel.
        test_master_items["shovel-mk-7"] = nil
        test_master_items_version = test_master_items_version + 1
        shovel_backend:probe_snapshot():next(function(value) shovel_snapshot = value end)
        assert(#shovel_snapshot.store.offers[1].marks == 2)

        -- Releasing transient backend reads must release the module-level mark
        -- index too, even when neither catalogue identity nor version changes.
        test_master_items["shovel-mk-7"] = shovel_mark("shovel-mk-7", "loc_munitorum", "loc_mk_7", "Munitorum â€¢ Mk VII")
        assert(shovel_backend:release_read_cache() == true)
        shovel_backend:probe_snapshot():next(function(value) shovel_snapshot = value end)
        assert(#shovel_snapshot.store.offers[1].marks == 3)

		local calls = {perk = 0, blessing = 0, expertise = 0, extract = 0, mastery = 0, mark = 0, invalidate = 0}
		local malformed_perk_response = false
		local crafting = {}
		function crafting:replace_perk_in_weapon(gear_id, index, trait_id, costs, tier)
			calls.perk = calls.perk + 1
			assert(select("#", gear_id, index, trait_id, costs, tier) == 5)
			assert(gear_id == "gear-1" and index == 1 and trait_id == "perk-1" and tier == 4)
			assert(costs == false)
			return resolved(malformed_perk_response and {} or {items = {{gear = {uuid = gear_id}}}})
		end
		function crafting:replace_trait_in_weapon(gear_id, index, trait_id, tier)
			calls.blessing = calls.blessing + 1
			assert(gear_id == "gear-1" and index == 2 and trait_id == "blessing-1" and tier == 4)
			return resolved({items = {{gear = {uuid = gear_id}}}})
		end
		function crafting:add_weapon_expertise() calls.expertise = calls.expertise + 1 return resolved({}) end
		function crafting:extract_weapon_mastery() calls.extract = calls.extract + 1 return resolved({}) end
		local mutation_backend
		local mastery = {purchase_traits = function() calls.mastery = calls.mastery + 1 return resolved({}) end}
		function mastery:switch_mark(gear_id, mark_id)
			calls.mark = calls.mark + 1
			assert(gear_id == "gear-1" and mark_id == "shovel-mk-7")
			mutation_backend._raw_gear[gear_id].name = mark_id

			return resolved({})
		end
		local gear = {invalidate_gear_cache = function() calls.invalidate = calls.invalidate + 1 end}

		mutation_backend = Backend.new({services = {crafting = crafting, gear = gear, mastery = mastery}})
		mutation_backend._raw_gear = {
			["gear-1"] = {
				uuid = "gear-1",
				name = "shovel-mk-3",
				item_type = "WEAPON_MELEE",
				parent_pattern = "sapper-shovel-pattern",
				slots = {"slot_primary"},
				weapon_progression_template = "sapper-shovel-template",
				expertise_level = 500,
				perks = {{id = "old-perk-1", rarity = 4}, {id = "old-perk-2", rarity = 4}},
				traits = {{id = "old-blessing-1", rarity = 4}, {id = "old-blessing-2", rarity = 4}},
			},
		}
		mutation_backend:replace_perk("gear-1", 1, "perk-1", 4)
		mutation_backend:replace_blessing("gear-1", 2, "blessing-1", 4)
		assert(calls.perk == 1 and calls.blessing == 1)

		-- An explicit mark target is a same-family, same-slot mutation. The native
		-- gear cache is invalidated exactly once so the controller can verify the
		-- PATCH from a fresh inventory snapshot; same-mark requests are no-ops.
		local mark_result
		mutation_backend:switch_mark("gear-1", "shovel-mk-7"):next(function(value) mark_result = value end)
		assert(calls.mark == 1 and calls.invalidate == 1)
		assert(mutation_backend._raw_gear["gear-1"].name == "shovel-mk-7")
		assert(mark_result.gear_id == "gear-1" and mark_result.mark_id == "shovel-mk-7" and mark_result.submitted == true)
		mutation_backend:switch_mark("gear-1", "shovel-mk-7")
		assert(calls.mark == 1 and calls.invalidate == 1)

		local foreign_mark = shovel_mark("foreign-mk-1", "loc_munitorum", "loc_mk_1", "Foreign Mk I")
		foreign_mark.parent_pattern = "foreign-pattern"
		test_master_items["foreign-mk-1"] = foreign_mark
		mutation_backend:switch_mark("gear-1", "foreign-mk-1")
		mutation_backend:switch_mark("", "shovel-mk-7")
		assert(calls.mark == 1 and calls.invalidate == 1)

		-- Every malformed operation fails closed before reaching Darktide services.
		mutation_backend:replace_perk("gear-1", 0, "perk-1", 4)
		mutation_backend:replace_perk("gear-1", 1, "perk-1", 5)
		mutation_backend:replace_perk("", 1, "perk-1", 4)
		mutation_backend:replace_blessing("gear-1", 3, "blessing-1", 4)
		mutation_backend:replace_blessing("gear-1", 2, "", 4)
		mutation_backend:replace_perk("gear-1", 1, "blessing-1", 4)
		mutation_backend:replace_blessing("gear-1", 2, "perk-1", 4)
		assert(calls.perk == 1 and calls.blessing == 1)

		-- Even structurally valid requests cannot reach Darktide before the same
		-- authoritative weapon is level 500 or when source slots are malformed.
		mutation_backend._raw_gear["gear-1"].expertise_level = 499
		mutation_backend:replace_perk("gear-1", 1, "perk-1", 4)
		mutation_backend:replace_blessing("gear-1", 2, "blessing-1", 4)
		mutation_backend._raw_gear["gear-1"].expertise_level = 500
		mutation_backend._raw_gear["gear-1"].perks = {}
		mutation_backend:replace_perk("gear-1", 1, "perk-1", 4)
		mutation_backend._raw_gear["gear-1"].perks = {{id = "old-perk-1", rarity = 4}, {id = "old-perk-2", rarity = 4}}
		assert(calls.perk == 1 and calls.blessing == 1)

		-- Remaining crafting mutations also reject malformed IDs, ranges, and
		-- duplicate mastery operations before any Darktide service call.
		mutation_backend:add_weapon_expertise("", 500)
		mutation_backend:add_weapon_expertise("gear-1", 0 / 0)
		mutation_backend:extract_weapon_mastery("", {"gear-1"})
		mutation_backend:extract_weapon_mastery("pattern-1", {"gear-1", "gear-1"})
		mutation_backend:purchase_mastery_traits("pattern-1", {{trait_id = "blessing-1", rarity = 5}})
		mutation_backend:purchase_mastery_traits("pattern-1", {{trait_id = "blessing-1", rarity = 4}, {trait_id = "blessing-1", rarity = 4}})
		assert(calls.expertise == 0 and calls.extract == 0 and calls.mastery == 0)

		-- Ambiguous/malformed responses stop at one request and are never retried.
		malformed_perk_response = true
		mutation_backend:replace_perk("gear-1", 1, "perk-1", 4)
		assert(calls.perk == 2)

		-- Full authoritative gear/wallet responses are transient validation data,
		-- not process-lifetime caches.
		mutation_backend._purchase_wallets.credits = {amount = 1000}
		assert(next(mutation_backend._raw_gear) ~= nil)
		assert(mutation_backend:release_read_cache() == true)
		assert(next(mutation_backend._raw_gear) == nil)
		assert(next(mutation_backend._purchase_wallets) == nil)
		assert(mutation_backend:release_read_cache() == true)

        print("Auto Crafter authoritative backend inventory tests passed.")
        '''
    )


if __name__ == "__main__":
    main()

from pathlib import Path

from lupa import LuaRuntime


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
                expertise_level = function() return 300 end,
                is_item_id_favorited = function() return false end,
                max_expertise_level = function() return 500 end,
                preview_stats_change = function() return {} end,
                weapon_card_display_name = function(item) return item.name end,
            }
        end
        package.preload["scripts/utilities/mastery"] = function() return {} end
        package.preload["scripts/backend/master_items"] = function()
            return {
				get_item = function(item_id) return {name = item_id} end,
                get_item_instance = function(raw_item)
                    if raw_item.invalid then return nil end
                    return raw_item
                end,
            }
        end
        package.preload["scripts/utilities/profile_utils"] = function() return {} end
        package.preload["scripts/settings/item/crafting_settings"] = function() return {} end
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

        function make_services(gear)
            return {
                store = {
                    get_credits_goods_store = function() return resolved({offers = {}}) end,
                    combined_wallets = function() return resolved({}) end,
                },
                gear = {fetch_gear = function() return resolved(gear) end},
            }
        end
        '''
    )
    backend_module = lua.execute(BACKEND_PATH.read_text(encoding="utf-8"))
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

		local calls = {perk = 0, blessing = 0}
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

		local mutation_backend = Backend.new({services = {crafting = crafting}})
		mutation_backend:replace_perk("gear-1", 1, "perk-1", 4)
		mutation_backend:replace_blessing("gear-1", 2, "blessing-1", 4)
		assert(calls.perk == 1 and calls.blessing == 1)

		-- Every malformed operation fails closed before reaching Darktide services.
		mutation_backend:replace_perk("gear-1", 0, "perk-1", 4)
		mutation_backend:replace_perk("gear-1", 1, "perk-1", 5)
		mutation_backend:replace_perk("", 1, "perk-1", 4)
		mutation_backend:replace_blessing("gear-1", 3, "blessing-1", 4)
		mutation_backend:replace_blessing("gear-1", 2, "", 4)
		assert(calls.perk == 1 and calls.blessing == 1)

		-- Ambiguous/malformed responses stop at one request and are never retried.
		malformed_perk_response = true
		mutation_backend:replace_perk("gear-1", 1, "perk-1", 4)
		assert(calls.perk == 2)

        print("Auto Crafter authoritative backend inventory tests passed.")
        '''
    )


if __name__ == "__main__":
    main()

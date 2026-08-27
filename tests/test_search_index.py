from pathlib import Path

from coverage_support import InstrumentedLuaRuntime as LuaRuntime


PROJECT_ROOT = Path(__file__).resolve().parents[1]
RUNTIME_ROOT = PROJECT_ROOT / "scripts" / "mods" / "BetterInventory"
INDEX_PATH = RUNTIME_ROOT / "BetterInventory_search_index.lua"
QUERY_PATH = RUNTIME_ROOT / "BetterInventory_search_query.lua"


def main() -> None:
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute(
        r'''
        Utf8 = {
            lower = function(value) return string.lower(value) end,
            string_length = function(value) return #value end,
        }
        localized = {
            loc_item_weapon_rarity_1 = "Profane",
            loc_item_weapon_rarity_2 = "Redeemed",
            loc_item_weapon_rarity_3 = "Anointed",
            loc_item_weapon_rarity_4 = "Exalted",
            loc_item_weapon_rarity_5 = "Transcendent",
            loc_item_weapon_rarity_6 = "Sainted",
            loc_family_sword = "Dueling Sword",
            loc_pattern_maccabian = "Maccabian",
            loc_mark_iv = "Mk IV",
            loc_uncanny = "Uncanny Strike",
            loc_cara = "Damage vs Carapace Enemies",
            loc_flak = "Damage vs Flak Armoured Enemies",
        }
        rarity_settings = {}
        for rarity = 1, 6 do
            rarity_settings[rarity] = {display_name = "loc_item_weapon_rarity_" .. tostring(rarity)}
        end
        master_items = {
            get_item = function(id)
                if id == "trait_uncanny" then
                    return {display_name = "loc_uncanny", trait = "blessing_uncanny_strike"}
                elseif id == "perk_cara" then
                    return {display_name = "loc_cara", trait = "perk_damage_carapace"}
                elseif id == "weapon_trait_melee_common_wield_increased_armored_damage" then
                    return {display_name = "loc_flak", trait = "perk_damage_flak"}
                end
            end,
        }
        decorated_name_calls = 0
        favorited_gear_id = "perfect"
        test_items = {
            weapon_card_display_name = function()
                decorated_name_calls = decorated_name_calls + 1
                error("GodRolls decorated name path must remain unused")
            end,
            expertise_level = function(item) return tostring(item.expertise or 0), true end,
            total_stats_value = function(item)
                local total = 0
                for index = 1, #(item.base_stats or {}) do
                    total = total + (item.base_stats[index].value or 0)
                end
                return math.floor(total * 100 + 0.5)
            end,
            trait_description = function(master_item)
                if master_item and master_item.trait == "perk_damage_carapace" then
                    return "+25% Damage vs Carapace Enemies"
                elseif master_item and master_item.trait == "perk_damage_flak" then
                    return "+25% Damage vs Flak Armoured Enemies"
                end

                return ""
            end,
            is_item_id_favorited = function(gear_id) return gear_id == favorited_gear_id end,
        }
        custom_records = {
            perfect = {name = "Pink Emperor Dueling Sword?"},
        }
        custom_tier_enabled = true
        custom_tier = {
            matches = function(item)
                return custom_tier_enabled and item.qualifies == true and item.rarity == 5
            end,
        }
        function make_weapon(gear_id, qualifies)
            return {
                gear_id = gear_id,
                id = "content/items/weapons/player/melee/dueling_sword",
                item_type = "WEAPON_MELEE",
                rarity = 5,
                expertise = 500,
                qualifies = qualifies,
                weapon_family_display_name = {loc_id = "loc_family_sword"},
                weapon_pattern_display_name = {loc_id = "loc_pattern_maccabian"},
                weapon_mark_display_name = {loc_id = "loc_mark_iv"},
                base_stats = {
                    {name = "damage", value = 0.8},
                    {name = "finesse", value = 0.8},
                    {name = "penetration", value = 0.8},
                    {name = "mobility", value = 0.6},
                    {name = "cleave", value = 0.8},
                },
                traits = {{id = "trait_uncanny", rarity = 4, value = 1}},
                perks = {
                    {id = "perk_cara", rarity = 4, value = 1},
                    {id = "weapon_trait_melee_common_wield_increased_armored_damage", rarity = 4, value = 1},
                },
            }
        end
        ''',
    )
    query = lua.execute(QUERY_PATH.read_text(encoding="utf-8"), name=str(QUERY_PATH))
    search_index = lua.execute(INDEX_PATH.read_text(encoding="utf-8"), name=str(INDEX_PATH))
    lua.globals().search_query = query
    dependencies = lua.table_from(
        {
            "compact_perk_search_terms": lua.eval(
                "function(id, description) "
                "compact_perk_calls = (compact_perk_calls or 0) + 1; "
                "if id == 'weapon_trait_melee_common_wield_increased_armored_damage' then "
                "return '+25% Flak Damage', '+25% Flak Dmg' end end"
            ),
            "normalize": query.normalize,
            "items": lua.globals().test_items,
            "master_items": lua.globals().master_items,
            "rarity_settings": lua.globals().rarity_settings,
            "custom_tier": lua.globals().custom_tier,
            "localize": lua.eval("function(key) return localized[key] or key end"),
            "customization_get": lua.eval(
                "function(gear_id) return custom_records[gear_id] end"
            ),
            "is_equipped": lua.eval(
                "function(item, context) return context and context.equipped == item.gear_id end"
            ),
            "is_new": lua.eval("function(item) return item.gear_id == 'new-item' end"),
            "is_loadout": lua.eval(
                "function(item) return item.gear_id == 'loadout-item' end"
            ),
            "is_perfect": lua.eval("function(item) return item.manual_perfect == true end"),
        }
    )
    index = search_index.new(dependencies)
    lua.globals().search_index_instance = index

    sainted_item = lua.globals().make_weapon("perfect", True)
    context = lua.table_from({"equipped": "perfect"})
    sainted, ok = search_index.project(index, sainted_item, context)
    assert ok is True
    assert sainted.rarity[1] == "sainted"
    assert sainted.native_rarity[1] == "transcendent"
    assert sainted.native_rarity[2] == "5"
    assert sainted.name[1] == "pink emperor dueling sword?"
    assert sainted.mark[1] == "mk iv"
    assert sainted.blessing[1] == "trait_uncanny"
    assert "uncanny strike" in [sainted.blessing[i] for i in range(1, len(sainted.blessing) + 1)]
    assert "damage vs carapace enemies" in [sainted.perk[i] for i in range(1, len(sainted.perk) + 1)]
    assert "damage vs flak armoured enemies" in [sainted.perk[i] for i in range(1, len(sainted.perk) + 1)]
    assert "+25% flak damage" in [sainted.perk[i] for i in range(1, len(sainted.perk) + 1)]
    assert "+25% flak dmg" in [sainted.perk[i] for i in range(1, len(sainted.perk) + 1)]
    assert lua.globals().compact_perk_calls == 2
    assert sainted.rating == 500
    assert sainted.base == 380
    assert sainted.favorite is True
    assert sainted.equipped is True
    assert sainted.perfect is True
    assert sainted.projected_bytes <= 2048
    assert lua.globals().decorated_name_calls == 0

    aliases = search_index.rarity_aliases(index)

    def compiled(text):
        return query.compile(text, lua.table_from({"rarity_aliases": aliases}))

    assert query.matches(compiled("sainted & uncanny & perk:carapace"), sainted) is True
    assert query.matches(compiled("flak"), sainted) is True
    assert query.matches(compiled('perk:"damage vs flak armoured enemies"'), sainted) is True
    assert query.matches(compiled('perk:"+25% flak dmg"'), sainted) is True
    assert query.matches(compiled("transcendent"), sainted) is False
    assert query.matches(compiled("native-rarity:transcendent"), sainted) is True
    assert query.matches(compiled("name:pink emperor"), sainted) is True

    ordinary_item = lua.globals().make_weapon("ordinary", False)
    ordinary, ok = search_index.project(index, ordinary_item, lua.table_from({}))
    assert ok is True
    assert ordinary.rarity[1] == "transcendent"
    assert query.matches(compiled("transcendent"), ordinary) is True
    assert query.matches(compiled("sainted"), ordinary) is False
    assert lua.globals().compact_perk_calls == 4

    # The same item revision returns the same bounded record without resolving
    # names or traits again. Revision and explicit invalidation rebuild it.
    cached, ok = search_index.project(index, sainted_item, context)
    assert ok is True
    assert lua.execute("return ... == ...", sainted, cached) is True
    assert index.metrics.builds == 2
    assert index.metrics.hits == 1
    assert lua.globals().compact_perk_calls == 4
    lua.execute("custom_records.perfect.name = 'Renamed Emperor Sword'")
    renamed, ok = search_index.project(index, sainted_item, context)
    assert ok is True
    assert renamed.name[1] == "renamed emperor sword"
    assert index.metrics.builds == 3
    lua.globals().old_search_record = sainted
    sainted_item.revision = 2
    rebuilt, ok = search_index.project(index, sainted_item, context)
    assert ok is True
    lua.globals().new_search_record = rebuilt
    assert lua.execute("return old_search_record ~= new_search_record") is True
    assert index.metrics.builds == 4
    assert search_index.invalidate(index, sainted_item) is True
    search_index.project(index, sainted_item, context)
    assert index.metrics.builds == 5
    lua.globals().favorited_gear_id = "other"
    unfavorited, ok = search_index.project(index, sainted_item, context)
    assert ok is True and unfavorited.favorite is False
    assert index.metrics.builds == 6

    # Custom-tier configuration changes invalidate effective rarity without
    # mutating native rarity or retaining the item in a strong-key cache.
    lua.globals().custom_tier_enabled = False
    assert search_index.invalidate_all(index) is True
    reclassified, ok = search_index.project(index, sainted_item, context)
    assert ok is True
    assert reclassified.rarity[1] == "transcendent"
    assert reclassified.native_rarity[1] == "transcendent"

    # Gadgets index their primary trait and perks as perk text rather than
    # pretending they have weapon blessings.
    gadget = lua.table_from(
        {
            "gear_id": "curio",
            "item_type": "GADGET",
            "rarity": 3,
            "expertise": 410,
            "traits": lua.table_from(
                [lua.table_from({"id": "perk_cara", "rarity": 4, "value": 1})]
            ),
            "perks": lua.table_from([]),
        }
    )
    curio, ok = search_index.project(index, gadget, lua.table_from({}))
    assert ok is True
    assert curio.type[2] == "curio"
    assert curio.rarity[1] == "anointed"
    assert len(curio.blessing) == 0
    assert query.matches(compiled("anointed & type:curio & perk:carapace"), curio) is True

    # Projected strings are hard-capped, malformed inputs fail open to the
    # runtime, and release drops providers and every cached record.
    tiny = search_index.new(
        lua.table_from(
            {
                "normalize": query.normalize,
                "items": lua.globals().test_items,
                "master_items": lua.globals().master_items,
                "rarity_settings": lua.globals().rarity_settings,
                "custom_tier": lua.globals().custom_tier,
                "localize": lua.eval("function(key) return string.rep('x', 100) end"),
                "max_projected_bytes": 64,
            }
        )
    )
    bounded, ok = search_index.project(tiny, ordinary_item, lua.table_from({}))
    assert ok is True
    assert bounded.projected_bytes <= 64
    missing, ok = search_index.project(index, "not-an-item", None)
    assert missing is None and ok is False
    assert search_index.release(index) is True
    assert next(iter(index.dependencies.items()), None) is None

    print("BetterInventory search index tests passed.")


if __name__ == "__main__":
    main()

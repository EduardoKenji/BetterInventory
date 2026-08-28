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
            loc_weapon_name = "Catachan Combat Blade",
            loc_curio_name = "Inquisitorial Rosette",
            loc_uncanny = "Uncanny Strike",
            loc_cara = "Damage vs Carapace Enemies",
            loc_flak = "Damage vs Flak Armoured Enemies",
            loc_unyielding = "Damage vs Unyielding Enemies",
            loc_health = "Maximum Health",
            loc_toughness = "Maximum Toughness",
            loc_wound = "Maximum Wounds",
            loc_inate_gadget_health = "Survivor",
            loc_ability_regeneration = "Combat Ability Regeneration",
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
                elseif id == "content/items/perks/melee/flak_damage" then
                    return {
                        display_name = "loc_flak",
                        trait = "weapon_trait_melee_common_wield_increased_armored_damage",
                    }
                elseif id == "content/items/perks/melee/unyielding_damage" then
                    return {
                        display_name = "loc_unyielding",
                        trait = "weapon_trait_melee_common_wield_increased_resistant_damage",
                    }
                elseif id == "content/items/perks/gadget/health" then
                    return {display_name = "loc_health", trait = "gadget_innate_health_increase"}
                elseif id == "content/items/perks/gadget/toughness" then
                    return {display_name = "loc_toughness", trait = "gadget_innate_toughness_increase"}
                elseif id == "content/items/perks/gadget/wound" then
                    return {display_name = "loc_wound", trait = "gadget_innate_max_wounds_increase"}
                elseif id == "content/items/traits/gadget_inate_trait/trait_inate_gadget_health_segment" then
                    return {display_name = "loc_inate_gadget_health", trait = "gadget_innate_max_wounds_increase"}
                elseif id == "content/items/perks/gadget/cooldown_reduction" then
                    return {display_name = "loc_ability_regeneration", trait = "gadget_cooldown_reduction"}
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
                if master_item and master_item.trait == "blessing_uncanny_strike" and enhanced_blessing_description then
                    return enhanced_blessing_description
                end

                if active_language == "zh-cn" then
                    if master_item and master_item.trait == "perk_damage_carapace" then
                        return "+25% 对硬壳敌人伤害"
                    elseif master_item and master_item.trait == "weapon_trait_melee_common_wield_increased_armored_damage" then
                        return "+25% 对防弹装甲敌人伤害"
                    elseif master_item and master_item.trait == "weapon_trait_melee_common_wield_increased_resistant_damage" then
                        return "+25% 对不屈敌人伤害"
                    elseif master_item and master_item.trait == "gadget_innate_health_increase" then
                        return "+17% 生命值"
                    end
                end

                if master_item and master_item.trait == "perk_damage_carapace" then
                    return "+25% Damage vs Carapace Enemies"
                elseif master_item and master_item.trait == "weapon_trait_melee_common_wield_increased_armored_damage" then
                    return "+25% Damage vs Flak Armoured Enemies"
                elseif master_item and master_item.trait == "weapon_trait_melee_common_wield_increased_resistant_damage" then
                    return "+25% Damage vs Unyielding Enemies"
                elseif master_item and master_item.trait == "gadget_innate_max_wounds_increase" then
                    return "+1 Maximum Wound. More wounds protect health after incapacitation."
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
                display_name = "loc_weapon_name",
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
                    {id = "content/items/perks/melee/flak_damage", rarity = 4, value = 1},
                    {id = "content/items/perks/melee/unyielding_damage", rarity = 4, value = 1},
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
            "compact_curio_perk_search_terms": lua.eval(
                "function(id) "
                "compact_curio_perk_calls = (compact_curio_perk_calls or 0) + 1; "
                "if id == 'gadget_cooldown_reduction' then return nil, 'Ability Regen' end end"
            ),
            "curio_trait_search_terms": lua.eval(
                "function(id) "
                "if id == 'gadget_innate_health_increase' or id == 'gadget_health_increase' then "
                "return active_language == 'zh-cn' and '生命' or 'Health', 'health' "
                "elseif id == 'gadget_innate_toughness_increase' or id == 'gadget_toughness_increase' then "
                "return active_language == 'zh-cn' and '韧性' or 'Toughness', 'toughness' "
                "elseif id == 'gadget_innate_max_wounds_increase' then "
                "return active_language == 'zh-cn' and '伤口' or 'Wound', 'wound wounds' "
                "elseif id == 'gadget_stamina_increase' then "
                "return active_language == 'zh-cn' and '体力' or 'Stamina', 'stamina' end end"
            ),
            "compact_perk_search_terms": lua.eval(
                "function(id, description) "
                "compact_perk_calls = (compact_perk_calls or 0) + 1; "
                "if id == 'weapon_trait_melee_common_wield_increased_armored_damage' then "
                "if active_language == 'zh-cn' then return '+25% 防弹装甲伤害', '+25% 防弹伤' end; "
                "return '+25% Flak Damage', '+25% Flak Dmg' "
                "elseif id == 'weapon_trait_melee_common_wield_increased_resistant_damage' then "
                "return '+25% Unyielding Damage', '+25% Unyielding Dmg' end end"
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
    assert lua.globals().compact_perk_calls == 3
    assert sainted.rating == 500
    assert sainted.base == 380
    assert sainted.favorite is True
    assert sainted.equipped is True
    assert sainted.perfect is True
    assert isinstance(sainted.text, str)
    assert sainted.projected_bytes <= 2048
    assert lua.globals().decorated_name_calls == 0

    aliases = search_index.rarity_aliases(index)

    def compiled(text):
        return query.compile(text, lua.table_from({"rarity_aliases": aliases}))

    assert query.matches(compiled("sainted & uncanny & perk:carapace"), sainted) is True
    assert query.matches(compiled("flak"), sainted) is True
    assert query.matches(compiled("unyielding"), sainted) is True
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
    assert lua.globals().compact_perk_calls == 6

    # The same item revision returns the same bounded record without resolving
    # names or traits again. Revision and explicit invalidation rebuild it.
    cached, ok = search_index.project(index, sainted_item, context)
    assert ok is True
    assert lua.execute("return ... == ...", sainted, cached) is True
    assert index.metrics.builds == 2
    assert index.metrics.hits == 1
    assert lua.globals().compact_perk_calls == 6
    lua.execute("custom_records.perfect.name = 'Renamed Emperor Sword'")

    # Keystroke scans can trust the projection validated by native presentation
    # capture. A later full projection still detects the changed fingerprint.
    trusted, ok = search_index.project(
        index, sainted_item, lua.table_from({"trust_cache": True})
    )
    assert ok is True
    assert trusted.name[1] == "pink emperor dueling sword?"
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

    # Enhanced Descriptions can expand blessing text enough to consume most of
    # the bounded projection. Essential perk names and compact aliases must be
    # indexed before optional long descriptions so bare weapon-perk searches
    # still work in the live mod stack.
    lua.execute("enhanced_blessing_description = string.rep('expanded blessing text ', 30)")
    enhanced_item = lua.globals().make_weapon("enhanced-descriptions-weapon", False)
    enhanced, ok = search_index.project(index, enhanced_item, lua.table_from({}))
    assert ok is True
    assert query.matches(compiled("flak"), enhanced) is True
    assert query.matches(compiled("unyielding"), enhanced) is True
    assert query.matches(compiled('perk:"+25% flak dmg"'), enhanced) is True
    assert enhanced.projected_bytes <= 2048
    lua.execute("enhanced_blessing_description = nil")

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
            "perks": lua.table_from(
                [
                    lua.table_from(
                        {
                            "id": "content/items/perks/melee/flak_damage",
                            "rarity": 4,
                            "value": 1,
                        }
                    )
                ]
            ),
        }
    )
    curio, ok = search_index.project(
        index, gadget, lua.table_from({"equipped": "curio"})
    )
    assert ok is True
    assert curio.type[2] == "curio"
    assert curio.rarity[1] == "anointed"
    assert len(curio.blessing) == 0
    assert curio.equipped is True
    assert "damage vs carapace enemies" in [
        curio.curio_primary[i] for i in range(1, len(curio.curio_primary) + 1)
    ]
    assert "damage vs flak armoured enemies" in [
        curio.curio_secondary[i] for i in range(1, len(curio.curio_secondary) + 1)
    ]
    assert query.matches(compiled("anointed & type:curio & perk:carapace"), curio) is True
    primary_rank = query.rank(compiled("carapace"), curio, True)
    secondary_rank = query.rank(compiled("flak"), curio, True)
    both_rank = query.rank(compiled("carapace & flak"), curio, True)
    assert both_rank > primary_rank > secondary_rank > 0

    # Production Curios use a distinct compact-label table. A cooldown perk's
    # internal trait says "cooldown", while the card says "Ability Regen";
    # the Curio provider must index that alias even if the long description is
    # unavailable. Full primary+secondary relevance outranks equipped
    # primary-only relevance, then equipped state and item level break ties.
    guardian = lua.table_from(
        {
            "gear_id": "guardian-gloriana",
            "item_type": "GADGET",
            "rarity": 5,
            "expertise": 410,
            "traits": lua.table_from(
                [
                    lua.table_from(
                        {
                            "id": "content/items/perks/gadget/toughness",
                            "rarity": 4,
                            "value": 1,
                        }
                    )
                ]
            ),
            "perks": lua.table_from(
                [
                    lua.table_from(
                        {
                            "id": "content/items/perks/gadget/cooldown_reduction",
                            "rarity": 4,
                            "value": 1,
                        }
                    )
                ]
            ),
        }
    )
    guardian_record, ok = search_index.project(index, guardian, lua.table_from({}))
    assert ok is True
    assert "ability regen" in [
        guardian_record.curio_secondary[i]
        for i in range(1, len(guardian_record.curio_secondary) + 1)
    ]
    guardian_query = compiled("toughness & ability")
    assert query.matches(guardian_query, guardian_record) is True
    guardian_rank = query.rank(guardian_query, guardian_record, True)
    assert guardian_rank > 0
    equipped_toughness_only = lua.table_from(
        {
            "text": "maximum toughness",
            "perk": lua.table_from(["maximum toughness"]),
            "curio_primary": lua.table_from(["maximum toughness"]),
            "curio_secondary": lua.table_from([]),
            "equipped": True,
            "rating": 430,
        }
    )
    equipped_partial_rank = query.rank(
        guardian_query,
        equipped_toughness_only,
        query.matches(guardian_query, equipped_toughness_only),
    )
    assert guardian_rank > equipped_partial_rank > 0
    assert lua.globals().compact_curio_perk_calls == 2

    # Full Curio description prose is searchable through the explicit perk
    # field, but it must not contaminate visible-line relevance or bare text.
    # A Wound primary description mentioning health therefore remains only a
    # one-line Toughness match. Exact relevance then uses equipped state and
    # visible item level descending (430, 420, 410).
    wound_with_toughness = lua.table_from(
        {
            "gear_id": "wound-toughness",
            "item_type": "GADGET",
            "rarity": 5,
            "expertise": 410,
            "traits": lua.table_from(
                [
                    lua.table_from(
                        {
                            "id": "content/items/traits/gadget_inate_trait/trait_inate_gadget_health_segment",
                            "rarity": 4,
                            "value": 1,
                        }
                    )
                ]
            ),
            "perks": lua.table_from(
                [
                    lua.table_from(
                        {
                            "id": "content/items/perks/gadget/toughness",
                            "rarity": 4,
                            "value": 1,
                        }
                    )
                ]
            ),
        }
    )
    wound_record, ok = search_index.project(index, wound_with_toughness, lua.table_from({}))
    assert ok is True
    assert query.matches(compiled("health & toughness"), wound_record) is False
    assert query.matches(compiled("perk:health & toughness"), wound_record) is True
    assert query.matches(compiled("wound & toughness"), wound_record) is True
    assert not any(
        "health" in wound_record.curio_primary[i]
        for i in range(1, len(wound_record.curio_primary) + 1)
    )
    assert "wound" in [
        wound_record.curio_primary[i]
        for i in range(1, len(wound_record.curio_primary) + 1)
    ]

    def projected_health_toughness(gear_id: str, expertise: int):
        item = lua.table_from(
            {
                "gear_id": gear_id,
                "item_type": "GADGET",
                "rarity": 5,
                "expertise": expertise,
                "traits": lua.table_from(
                    [
                        lua.table_from(
                            {
                                "id": "content/items/perks/gadget/health",
                                "rarity": 4,
                                "value": 1,
                            }
                        )
                    ]
                ),
                "perks": lua.table_from(
                    [
                        lua.table_from(
                            {
                                "id": "content/items/perks/gadget/toughness",
                                "rarity": 4,
                                "value": 1,
                            }
                        )
                    ]
                ),
            }
        )
        value, projected = search_index.project(index, item, lua.table_from({}))
        assert projected is True
        return value

    exact_query = compiled("health & toughness")
    exact_430 = projected_health_toughness("health-toughness-430", 430)
    exact_420 = projected_health_toughness("health-toughness-420", 420)
    exact_410 = projected_health_toughness("health-toughness-410", 410)
    exact_ranks = [
        query.rank(exact_query, value, query.matches(exact_query, value))
        for value in (exact_430, exact_420, exact_410)
    ]
    wound_rank = query.rank(
        exact_query, wound_record, query.matches(exact_query, wound_record)
    )
    assert exact_ranks[0] > exact_ranks[1] > exact_ranks[2] > wound_rank

    # Search projection consumes current-locale UTF-8 strings. Production-like
    # master-item perk paths resolve to gameplay trait IDs before compact label
    # lookup, and weapon/curio names, traits, perks, and rarity remain directly
    # searchable with Simplified Chinese characters and partial terms.
    lua.execute(
        r'''
        active_language = "zh-cn"
        localized.loc_item_weapon_rarity_3 = "圣洁"
        localized.loc_item_weapon_rarity_5 = "超凡"
        localized.loc_item_weapon_rarity_6 = "圣化"
        localized.loc_weapon_name = "卡塔昌战斗刀"
        localized.loc_family_sword = "决斗剑"
        localized.loc_pattern_maccabian = "马卡比"
        localized.loc_mark_iv = "四型"
        localized.loc_uncanny = "诡异打击"
        localized.loc_cara = "对硬壳敌人伤害"
        localized.loc_flak = "对防弹装甲敌人伤害"
        localized.loc_unyielding = "对不屈敌人伤害"
        localized.loc_curio_name = "审判庭玫瑰饰物"
        localized.loc_health = "最大生命值"
        custom_records.ordinary = nil
        '''
    )
    assert search_index.invalidate_all(index) is True
    chinese_weapon, ok = search_index.project(index, ordinary_item, lua.table_from({}))
    assert ok is True
    chinese_aliases = search_index.rarity_aliases(index)
    chinese_query = query.compile(
        "卡塔昌 & 诡异 & 防弹",
        lua.table_from({"rarity_aliases": chinese_aliases}),
    )
    assert query.matches(chinese_query, chinese_weapon) is True
    assert query.matches(
        query.compile("超凡", lua.table_from({"rarity_aliases": chinese_aliases})),
        chinese_weapon,
    ) is True
    assert "+25% 防弹伤" in [
        chinese_weapon.perk[i] for i in range(1, len(chinese_weapon.perk) + 1)
    ]

    chinese_curio_item = lua.table_from(
        {
            "gear_id": "chinese-curio",
            "display_name": "loc_curio_name",
            "item_type": "GADGET",
            "rarity": 3,
            "traits": lua.table_from(
                [
                    lua.table_from(
                        {"id": "content/items/perks/gadget/health", "rarity": 4, "value": 1}
                    )
                ]
            ),
            "perks": lua.table_from(
                [
                    lua.table_from(
                        {"id": "content/items/perks/melee/flak_damage", "rarity": 4, "value": 1}
                    )
                ]
            ),
        }
    )
    chinese_curio, ok = search_index.project(index, chinese_curio_item, lua.table_from({}))
    assert ok is True
    assert query.matches(
        query.compile(
            "审判庭 & 生命 & 防弹 & 圣洁",
            lua.table_from({"rarity_aliases": chinese_aliases}),
        ),
        chinese_curio,
    ) is True

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

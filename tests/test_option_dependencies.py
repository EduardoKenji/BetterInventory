import re
from pathlib import Path

from coverage_support import InstrumentedLuaRuntime as LuaRuntime


PROJECT_ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = (
    PROJECT_ROOT
    / "scripts"
    / "mods"
    / "BetterInventory"
    / "BetterInventory_option_dependencies.lua"
)
AUTO_CRAFTER_GREYED_IDS = (
    "auto_crafter_defer_bad_weapon_processing",
    "auto_crafter_include_favorite_inventory_bases",
    "auto_crafter_allocate_mastery_points",
    "auto_crafter_change_perks",
    "auto_crafter_change_blessings",
    "auto_crafter_perk_1_target",
    "auto_crafter_perk_2_target",
    "auto_crafter_show_perk_grid",
    "auto_crafter_blessing_1_target",
    "auto_crafter_blessing_2_target",
    "auto_crafter_show_blessing_grid",
)


def build(lua, module, ids):
    """Create an instance on a fake mod and bind one entry per id (title == id)."""
    lua.globals().test_option_ids = lua.table_from(list(ids))
    return lua.execute(
        """
        local module = ...
        local settings = {}
        local mod = {}
        function mod:get(id) return settings[id] end
        function mod:set(id, value) settings[id] = value end
        function mod:localize(id) return id end
        function mod:get_readable_name() return "BI" end
        get_mod = function() return nil end

        local instance = module.create({
            mod = mod,
            Layout = { columns = function(_, default) return default end },
            FavoriteIntegration = {},
        })
        local entries = {}

        for _, id in ipairs(test_option_ids) do
            entries[id] = { category = "BI", display_name = id }
        end

        local list = {}
        for _, id in ipairs(test_option_ids) do list[#list + 1] = entries[id] end
        instance.bind_option_dependencies({ settings = list })

        return { instance = instance, entries = entries, settings = settings }
        """,
        module,
    )


def main() -> None:
    lua = LuaRuntime(unpack_returned_tuples=True)
    module = lua.execute(MODULE_PATH.read_text(encoding="utf-8"), name=str(MODULE_PATH))

    # B19: these Auto Crafter rows were greyed by the refresh but missing from
    # the binding list, so they never bound and never greyed out.
    harness = build(lua, module, AUTO_CRAFTER_GREYED_IDS)
    entries, settings, instance = harness.entries, harness.settings, harness.instance
    for option_id in AUTO_CRAFTER_GREYED_IDS:
        assert entries[option_id].disabled is False, option_id

    settings.auto_crafter_level_mastery_20 = False
    instance.refresh_option_dependencies()
    for option_id in AUTO_CRAFTER_GREYED_IDS:
        if option_id == "auto_crafter_include_favorite_inventory_bases":
            assert entries[option_id].disabled is False
        else:
            assert entries[option_id].disabled is True, option_id
            assert entries[option_id].disabled_by[1] == "option_requires_auto_crafter_mastery_20"

    settings.auto_crafter_level_mastery_20 = True
    settings.auto_crafter_change_perks = False
    settings.auto_crafter_reuse_inventory_base = False
    instance.refresh_option_dependencies()
    assert entries.auto_crafter_include_favorite_inventory_bases.disabled is True
    assert entries.auto_crafter_perk_1_target.disabled is True
    assert entries.auto_crafter_show_perk_grid.disabled is True
    assert entries.auto_crafter_change_perks.disabled is False
    assert entries.auto_crafter_blessing_1_target.disabled is False

    settings.auto_crafter_change_perks = True
    settings.auto_crafter_reuse_inventory_base = True
    instance.refresh_option_dependencies()
    for option_id in AUTO_CRAFTER_GREYED_IDS:
        assert entries[option_id].disabled is False, option_id

    # Single source of truth: every row the refresh can grey is in the bound
    # list, and the bound list is exactly what the rule table declares.
    tracked = list(instance.TRACKED_SETTING_IDS.values())
    assert len(tracked) == len(set(tracked))
    rule_ids = []
    greyed_ids = []
    for rule in instance.OPTION_DEPENDENCY_RULES.values():
        rule_ids.extend(rule.ids.values())
        if rule.rule is not None:
            greyed_ids.extend(rule.ids.values())
    assert set(tracked) == set(rule_ids)
    assert set(greyed_ids) <= set(tracked)
    assert set(AUTO_CRAFTER_GREYED_IDS) <= set(greyed_ids)

    # Guard against a second hand-written id list: the only direct entry-table
    # reads allowed are the three non-id-bound group/character rows and the
    # MyFavorites preview, everything else goes through the rule table.
    source = MODULE_PATH.read_text(encoding="utf-8")
    direct_reads = set(re.findall(r"option_dependency_entries\.(\w+)", source))
    assert direct_reads <= {
        "automatic_curio_character_entries",
        "automatic_curio_classes_group",
        "automatic_curio_characters_group",
        "auto_crafter_myfavorites_color",
    }, direct_reads

    # Binding every tracked id and refreshing must leave no greyable row
    # unbound: each rule row was reached and wrote its state.
    harness = build(lua, module, tracked)
    harness.instance.refresh_option_dependencies()
    for rule in harness.instance.OPTION_DEPENDENCY_RULES.values():
        if rule.rule is None:
            continue
        for option_id in rule.ids.values():
            assert harness.entries[option_id].disabled is not None, option_id

    print("BetterInventory option dependency tests passed.")


if __name__ == "__main__":
    main()

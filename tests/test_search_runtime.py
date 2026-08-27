from pathlib import Path

from coverage_support import InstrumentedLuaRuntime as LuaRuntime


PROJECT_ROOT = Path(__file__).resolve().parents[1]
RUNTIME_ROOT = PROJECT_ROOT / "scripts" / "mods" / "BetterInventory"
QUERY_PATH = RUNTIME_ROOT / "BetterInventory_search_query.lua"
SEARCH_RUNTIME_PATH = RUNTIME_ROOT / "BetterInventory_search_runtime.lua"


def main() -> None:
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute(
        r'''
        now = 10
        configured_mode = "dim"
        prioritize_equipped = true
        remember = false
        present_calls = 0
        external_present_calls = 0
        project_calls = 0
        trusted_project_calls = 0
        validated_project_calls = 0
        released_indexes = 0

        function make_view(character, family, count)
            local view = {
                character = character,
                family = family,
                _offer_items_layout = {},
                _item_grid = {_all_grid_widgets = {}},
            }

            for index = 1, count do
                local item = {
                    gear_id = tostring(character) .. "-" .. tostring(index),
                    name = index % 2 == 0 and "even sword" or "odd axe",
                }
                view._offer_items_layout[index] = item
                view._item_grid._all_grid_widgets[index] = {
                    content = {
                        alpha_multiplier = 1,
                        entry = item,
                    },
                }
            end

            return view
        end

        stub_index = {
            new = function() return {released = false} end,
            project = function(index, item, context)
                project_calls = project_calls + 1
                if context and context.trust_cache == true then
                    trusted_project_calls = trusted_project_calls + 1
                else
                    validated_project_calls = validated_project_calls + 1
                end
                if item.fail_projection then return nil, false end

                if item.curio then
                    return {
                        curio_primary = {item.primary or ""},
                        curio_secondary = {item.secondary or ""},
                        equipped = item.equipped == true,
                        name = {item.name},
                        perk = {item.primary or "", item.secondary or ""},
                        text = {item.name, item.primary or "", item.secondary or ""},
                    }, true
                end

                return {name = {item.name}, text = {item.name}}, true
            end,
            invalidate = function() return true end,
            invalidate_all = function() return true end,
            release = function(index)
                index.released = true
                released_indexes = released_indexes + 1
                return true
            end,
            rarity_aliases = function() return {} end,
        }
        ''',
    )
    query = lua.execute(QUERY_PATH.read_text(encoding="utf-8"), name=str(QUERY_PATH))
    search_runtime = lua.execute(
        SEARCH_RUNTIME_PATH.read_text(encoding="utf-8"), name=str(SEARCH_RUNTIME_PATH)
    )
    lua.globals().search_query = query
    dependencies = lua.table_from(
        {
            "query": query,
            "new_index": lua.eval("function() return stub_index.new() end"),
            "project": lua.eval(
                "function(index, item, context) return stub_index.project(index, item, context) end"
            ),
            "invalidate": lua.eval(
                "function(index, item) return stub_index.invalidate(index, item) end"
            ),
            "invalidate_all": lua.eval(
                "function(index) return stub_index.invalidate_all(index) end"
            ),
            "release_index": lua.eval(
                "function(index) return stub_index.release(index) end"
            ),
            "rarity_aliases": lua.eval(
                "function(index) return stub_index.rarity_aliases(index) end"
            ),
            "view_family": lua.eval("function(view) return view.family end"),
            "character_id": lua.eval("function(view) return view.character end"),
            "mode": lua.eval("function() return configured_mode end"),
            "prioritize_equipped": lua.eval(
                "function() return prioritize_equipped end"
            ),
            "remember_query": lua.eval("function() return remember end"),
            "time": lua.eval("function() return now end"),
            "present": lua.eval(
                "function(view, slot_filter, item_type_filter, display_name) "
                "present_calls = present_calls + 1; return true end"
            ),
            "present_external": lua.eval(
                "function(view) external_present_calls = external_present_calls + 1; return true end"
            ),
        }
    )
    runtime = search_runtime.new(dependencies)
    lua.globals().search_runtime_instance = runtime
    assert search_runtime.register(runtime, None) is None
    unsupported = lua.globals().make_view("veteran", None, 1)
    assert search_runtime.register(runtime, unsupported) is None
    assert search_runtime.capture_presentation(runtime, unsupported, None, None, None) is False
    assert search_runtime.set_query(runtime, unsupported, "sword", 0) is False
    assert search_runtime.invalidate(runtime, unsupported, None, 0) is False
    assert search_runtime.invalidate_all(runtime, unsupported, 0) is False
    assert search_runtime.refresh(runtime, unsupported, 0) is False
    assert search_runtime.release(runtime, unsupported) is False
    assert search_runtime.query(runtime, unsupported) == ""
    assert search_runtime.is_active(runtime, unsupported) is None
    assert search_runtime.native_filter(runtime, unsupported, {}, True) is True
    assert search_runtime.rank(runtime, unsupported, {}) == 0
    assert search_runtime.apply_widget_alpha(runtime, unsupported) is False
    assert search_runtime.update(runtime, unsupported, 0) is False

    lua.globals().remember = True
    anonymous = lua.globals().make_view(None, "inventory", 1)
    assert search_runtime.register(runtime, anonymous) is not None
    assert search_runtime.release(runtime, anonymous) is True
    lua.globals().remember = False

    # Empty-query captures warm rich projections in bounded 16-item slices.
    # No sort/presentation is requested by the warm-up worker, and a later
    # settled query reuses all forty records through the trusted cache seam.
    cold_view = lua.globals().make_view("cold", "inventory", 40)
    assert search_runtime.capture_presentation(
        runtime, cold_view, "slot", "type", "title"
    ) is True
    cold_projects_before = lua.globals().project_calls
    assert search_runtime.update(runtime, cold_view, 1) is False
    assert lua.globals().project_calls - cold_projects_before == 16
    assert search_runtime.update(runtime, cold_view, 2) is False
    assert lua.globals().project_calls - cold_projects_before == 32
    assert search_runtime.update(runtime, cold_view, 3) is False
    assert lua.globals().project_calls - cold_projects_before == 40
    assert search_runtime.set_query(runtime, cold_view, "sword", 4) == (True, None)
    assert search_runtime.update(runtime, cold_view, 4.08) is True
    assert lua.globals().trusted_project_calls == 40
    assert search_runtime.release(runtime, cold_view) is True

    view = lua.globals().make_view("veteran", "inventory", 200)
    lua.globals().test_view = view
    assert search_runtime.register(runtime, view) is not None
    assert search_runtime.capture_presentation(runtime, view, "slot", "type", "title") is True
    inactive_layout = lua.table_from(
        {1: lua.table_from({"item": lua.table_from({"gear_id": "plain", "name": "plain"})})}
    )
    lua.globals().inactive_layout = inactive_layout
    lua.globals().inactive_composed = search_runtime.compose_layout(
        runtime, view, inactive_layout
    )
    assert lua.execute("return inactive_layout == inactive_composed") is True
    search_runtime.capture_presentation(runtime, view, "slot", "type", "title")
    trusted_before_main_query = lua.globals().trusted_project_calls
    validated_before_main_query = lua.globals().validated_project_calls
    present_before_main_query = lua.globals().present_calls
    valid, error = search_runtime.set_query(runtime, view, "sword", 10)
    assert valid is True and error is None
    # Typing only compiles and moves the debounce deadline. Projection and
    # matching are coalesced until the query settles.
    assert lua.globals().trusted_project_calls == trusted_before_main_query
    assert lua.globals().validated_project_calls == validated_before_main_query
    assert search_runtime.rank(runtime, view, view._offer_items_layout[2]) == 0
    search_runtime.capture_presentation(runtime, view, "slot", "type", "title")
    assert lua.globals().validated_project_calls == validated_before_main_query + 200
    assert search_runtime.apply_widget_alpha(runtime, view) is True
    assert search_runtime.rank(runtime, view, view._offer_items_layout[2]) == 1
    assert search_runtime.rank(runtime, view, view._offer_items_layout[1]) == 0
    assert search_runtime.native_filter(runtime, view, None, True) is True
    late_entry = lua.table_from({"gear_id": "late", "name": "late sword"})
    assert search_runtime.rank(runtime, view, late_entry) == 1
    late_filter_entry = lua.table_from({"gear_id": "late-filter", "name": "late sword"})
    lua.globals().configured_mode = "hide"
    assert search_runtime.native_filter(runtime, view, late_filter_entry, True) is True
    lua.globals().configured_mode = "dim"
    assert view._item_grid._all_grid_widgets[1].content.alpha_multiplier == 0.4
    assert view._item_grid._all_grid_widgets[2].content.alpha_multiplier == 1
    assert search_runtime.is_active(runtime, view) is True
    assert search_runtime.compose_layout(runtime, view, None) is None
    lua.globals().first_result_table = search_runtime.state(runtime, view).ranks

    # Present requests are coalesced for 80 ms and do not allocate or rerun the
    # native presentation for every keystroke.
    search_runtime.set_query(runtime, view, "axe", 10.02)
    search_runtime.set_query(runtime, view, "odd axe", 10.04)
    lua.globals().second_result_table = search_runtime.state(runtime, view).ranks
    assert lua.execute("return first_result_table == second_result_table") is True
    assert search_runtime.update(runtime, view, 10.11) is False
    assert lua.globals().present_calls == present_before_main_query
    assert search_runtime.update(runtime, view, 10.12) is True
    assert lua.globals().present_calls == present_before_main_query + 1
    assert lua.globals().trusted_project_calls == trusted_before_main_query + 200
    assert search_runtime.update(runtime, view, 11) is False
    settled_project_calls = lua.globals().project_calls
    for frame in range(120):
        assert search_runtime.update(runtime, view, 11 + frame / 60) is False
    assert lua.globals().project_calls == settled_project_calls

    # Repeating the effective query is a no-op: no compilation, scan, alpha
    # pass, allocation, or presentation-deadline extension is performed.
    repeated_project_calls = lua.globals().project_calls
    assert search_runtime.set_query(runtime, view, "odd axe", 11) == (True, None)
    assert lua.globals().project_calls == repeated_project_calls

    # Curio relevance is computed during the bounded projection scan and read
    # as O(1) cached ranks by the comparator. Partial text follows the exact
    # equipped/primary/secondary hierarchy in both dim and hide modes.
    lua.execute(
        r'''
        curio_view = {
            character = "veteran",
            family = "inventory",
            _offer_items_layout = {
                {gear_id = "equipped-both", curio = true, equipped = true, primary = "+17% health", secondary = "+5% health", name = "curio"},
                {gear_id = "equipped-primary", curio = true, equipped = true, primary = "+17% health", name = "curio"},
                {gear_id = "equipped-secondary", curio = true, equipped = true, secondary = "+5% health", name = "curio"},
                {gear_id = "both", curio = true, primary = "+17% health", secondary = "+5% health", name = "curio"},
                {gear_id = "primary", curio = true, primary = "+17% health", name = "curio"},
                {gear_id = "secondary", curio = true, secondary = "+5% health", name = "curio"},
                {gear_id = "name", curio = true, name = "health relic"},
                {gear_id = "unmatched", curio = true, name = "toughness relic"},
            },
            _item_grid = {_all_grid_widgets = {}},
        }
        '''
    )
    curio_view = lua.globals().curio_view
    search_runtime.capture_presentation(runtime, curio_view, "slot", "GADGET", "Curios")
    search_runtime.set_query(runtime, curio_view, "heal", 12)
    assert search_runtime.update(runtime, curio_view, 12.04) is False
    assert search_runtime.update(runtime, curio_view, 12.08) is True
    curio_ranks = [
        search_runtime.rank(runtime, curio_view, curio_view._offer_items_layout[index])
        for index in range(1, 9)
    ]
    assert curio_ranks == [7, 6, 5, 4, 3, 2, 1, 0], (
        curio_ranks,
        search_runtime.state(runtime, curio_view).query,
        search_runtime.is_active(runtime, curio_view),
    )
    lua.globals().configured_mode = "hide"
    assert search_runtime.rank(runtime, curio_view, curio_view._offer_items_layout[1]) == 7
    assert search_runtime.native_filter(
        runtime, curio_view, curio_view._offer_items_layout[8], True
    ) is False
    lua.globals().prioritize_equipped = False
    search_runtime.set_query(runtime, curio_view, "health", 13)
    assert search_runtime.update(runtime, curio_view, 13.08) is True
    assert search_runtime.rank(runtime, curio_view, curio_view._offer_items_layout[1]) == 4
    lua.globals().prioritize_equipped = True
    lua.globals().configured_mode = "dim"

    # Darktide's sacrifice view owns a separate grid implementation. Compose
    # only the live, already-native-sorted callback layout: external spacing is
    # preserved, matches become the stable outer partition, and no layout copy
    # is retained by the runtime.
    external = lua.table_from(
        {
            "character": "veteran",
            "family": "hadron_sacrifice",
            "_offer_items_layout": lua.table_from({}),
            "_item_grid": lua.table_from({"_all_grid_widgets": lua.table_from({})}),
        }
    )
    spacing_top = lua.table_from({"is_external": True})
    axe_entry = lua.table_from(
        {"item": lua.table_from({"gear_id": "axe", "name": "odd axe"})}
    )
    sword_entry = lua.table_from(
        {"item": lua.table_from({"gear_id": "sword", "name": "even sword"})}
    )
    spacing_bottom = lua.table_from({"is_external": True})
    external_layout = lua.table_from(
        {1: spacing_top, 2: axe_entry, 3: sword_entry, 4: spacing_bottom}
    )
    search_runtime.set_query(runtime, external, "sword", 20)
    composed = search_runtime.compose_layout(runtime, external, external_layout)
    lua.globals().external_composed = composed
    lua.globals().spacing_top = spacing_top
    lua.globals().spacing_bottom = spacing_bottom
    lua.globals().sword_entry = sword_entry
    lua.globals().axe_entry = axe_entry
    assert lua.execute(
        "return external_composed[1] == spacing_top and "
        "external_composed[2] == sword_entry and external_composed[3] == axe_entry "
        "and external_composed[4] == spacing_bottom"
    ) is True
    assert search_runtime.update(runtime, external, 20.08) is True
    assert lua.globals().external_present_calls == 1
    assert search_runtime.state(runtime, external).last_present_arguments is None

    lua.globals().configured_mode = "hide"
    hidden = search_runtime.compose_layout(runtime, external, external_layout)
    lua.globals().external_hidden = hidden
    assert len(hidden) == 3
    assert lua.execute(
        "return external_hidden[1] == spacing_top and "
        "external_hidden[2] == sword_entry and external_hidden[3] == spacing_bottom"
    ) is True

    # A missing widget grid fails soft, and a throwing presentation callback is
    # quarantined to this view after its first coalesced attempt.
    gridless = lua.globals().make_view("veteran", "inventory", 1)
    gridless._item_grid = None
    search_runtime.capture_presentation(runtime, gridless, None, None, None)
    search_runtime.set_query(runtime, gridless, "axe", 21)
    assert search_runtime.apply_widget_alpha(runtime, gridless) is False
    assert search_runtime.release(runtime, gridless) is True

    failing_dependencies = lua.table_from(
        {
            "query": query,
            "new_index": lua.eval("function() return {} end"),
            "project": lua.eval(
                "function(_, item) return {text = {item.name}, name = {item.name}}, true end"
            ),
            "view_family": lua.eval("function(view) return view.family end"),
            "character_id": lua.eval("function(view) return view.character end"),
            "present": lua.eval("function() error('present failed') end"),
        }
    )
    failing_runtime = search_runtime.new(failing_dependencies)
    failing_view = lua.globals().make_view("veteran", "inventory", 1)
    search_runtime.capture_presentation(
        failing_runtime, failing_view, "slot", "type", "title"
    )
    search_runtime.set_query(failing_runtime, failing_view, "axe", 30)
    assert search_runtime.update(failing_runtime, failing_view, 31) is False
    assert search_runtime.state(failing_runtime, failing_view).faulted is False
    assert search_runtime.update(failing_runtime, failing_view, 32) is False
    assert search_runtime.state(failing_runtime, failing_view).faulted is True
    assert search_runtime.update(failing_runtime, failing_view, 33) is False
    assert search_runtime.release(failing_runtime, failing_view) is True

    # Hide mode composes after the native filter; dim mode never removes an
    # entry and invalid projection fails open.
    lua.globals().configured_mode = "hide"
    matched = view._offer_items_layout[1]
    unmatched = view._offer_items_layout[2]
    assert search_runtime.native_filter(runtime, view, matched, True) is True
    assert search_runtime.native_filter(runtime, view, unmatched, True) is False
    assert search_runtime.native_filter(runtime, view, matched, False) is False
    matched.fail_projection = True
    search_runtime.invalidate(runtime, view, matched, 12)
    assert search_runtime.invalidate_all(runtime, view, 12) is True
    assert search_runtime.native_filter(runtime, view, matched, True) is True

    # Clearing a query restores only alpha values that this runtime still owns.
    matched.fail_projection = False
    lua.globals().configured_mode = "dim"
    search_runtime.set_query(runtime, view, "sword", 13)
    assert search_runtime.update(runtime, view, 13.08) is True
    first_widget = view._item_grid._all_grid_widgets[1]
    assert first_widget.content.alpha_multiplier == 0.4
    first_widget.content.alpha_multiplier = 0.7
    search_runtime.set_query(runtime, view, "", 14)
    assert search_runtime.update(runtime, view, 14.08) is True
    assert first_widget.content.alpha_multiplier == 0.7

    # Optional session memory is character/view-family scoped. Release always
    # drops weak results, projected records and widget ownership.
    lua.globals().remember = True
    search_runtime.set_query(runtime, view, "axe", 15)
    index = search_runtime.state(runtime, view).index
    assert search_runtime.release(runtime, view) is True
    assert index.released is True
    reopened = lua.globals().make_view("veteran", "inventory", 3)
    assert search_runtime.register(runtime, reopened).query == "axe"
    other_character = lua.globals().make_view("zealot", "inventory", 3)
    assert search_runtime.register(runtime, other_character).query == ""
    assert next(iter(runtime.memory.items()), None) is None
    assert search_runtime.release_all(runtime) == 4
    assert lua.globals().released_indexes == 8

    search_runtime.clear_memory(runtime)
    assert next(iter(runtime.memory.items()), None) is None

    # Repeated open/close cycles leave no live state and release every index.
    for index in range(100):
        transient = lua.globals().make_view(f"character-{index}", "inventory", 2)
        search_runtime.register(runtime, transient)
        search_runtime.release(runtime, transient)
    assert lua.globals().released_indexes == 108

    print("BetterInventory search runtime tests passed.")


if __name__ == "__main__":
    main()

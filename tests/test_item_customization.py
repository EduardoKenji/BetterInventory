from pathlib import Path

from lupa import LuaRuntime


PROJECT_ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = (
    PROJECT_ROOT
    / "scripts"
    / "mods"
    / "BetterInventory"
    / "BetterInventory_item_customization.lua"
)


def main() -> None:
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute(
        r"""
        function table.clone(value)
            if type(value) ~= "table" then
                return value
            end

            local copy = {}

            for key, child in pairs(value) do
                copy[table.clone(key)] = table.clone(child)
            end

            return copy
        end

        Color = {
            white = function(alpha) return { alpha, 255, 255, 255 } end,
            terminal_corner_hover = function(alpha) return { alpha, 90, 100, 80 } end,
        }

        Keyboard = {
            BACKSPACE = -1,
            strokes = {},
            keystrokes = function() return Keyboard.strokes end,
            button_index = function() return 0 end,
            pressed = function() return false end,
        }

        function require(path)
            if string.find(path, "slider_pass_templates", 1, true) then
                return {
                    value_slider = function() return {} end,
                }
            elseif string.find(path, "ui_font_settings", 1, true) then
                return {
                    body = {},
                }
            elseif string.find(path, "popup_handler_settings", 1, true) then
                return {
                    text_max_width = 800,
                }
            end

            return {}
        end

        settings = {}
        name_it_settings = { name_list = {} }
        test_name_it_mod = {}

        function test_name_it_mod:get(setting_id)
            return name_it_settings[setting_id]
        end

        function test_name_it_mod:set(setting_id, value)
            name_it_settings[setting_id] = value
        end

        function test_name_it_mod.get_custom_name_list()
            return name_it_settings.name_list
        end

        settings_flushes = 0
        test_dmf_mod = {
            save_unsaved_settings_to_file = function()
                settings_flushes = settings_flushes + 1
            end,
        }

        function get_mod(name)
            return name == "name_it" and test_name_it_mod or name == "DMF" and test_dmf_mod or nil
        end

        test_mod = {}
		test_mod_enabled = true
		enabled_cleanup_hooks = {}

        function test_mod:get(setting_id)
            local value = settings[setting_id]

            return type(value) == "table" and table.clone(value) or value
        end

        function test_mod:set(setting_id, value)
            settings[setting_id] = type(value) == "table" and table.clone(value) or value
        end

		function test_mod:is_enabled()
			return test_mod_enabled
		end

		function test_mod:hook_enable(target, method)
			enabled_cleanup_hooks[method] = target
		end

        captured_hooks = {}

        function test_mod:add_global_localize_strings(strings)
            global_strings = strings
        end

        function test_mod:hook_require() end

        function test_mod:hook(target, method, callback)
            captured_hooks[method] = callback
        end

        captured_safe_hooks = {}

        function test_mod:hook_safe(target, method, callback)
            captured_safe_hooks[method] = callback
        end

        captured_popup = nil
        Managers = {
            event = {
                trigger = function(self, event_name, context)
                    assert(event_name == "event_show_ui_popup")
                    captured_popup = context
                end,
            },
            ui = {
                view_instance = function() return active_inventory_view end,
            },
        }
        """
    )
    customization = lua.execute(MODULE_PATH.read_text(encoding="utf-8"))
    globals_ = lua.globals()
    mod = globals_.test_mod
    settings = globals_.settings

    customization.on_enabled(mod)
    assert len(settings.custom_item_name_and_colors) == 0

    changes = lua.table_from(
        {
            "name": "Test",
            "name_color": lua.table_from([255, 10, 20, 30]),
            "background_color": lua.table_from([255, 40, 50, 60]),
            "background_preserve_shading": True,
        }
    )
    assert customization.update(mod, "gear-1", changes) is True
    record = customization.get(mod, "gear-1")
    assert record.name == "Test"
    assert tuple(record.name_color[index] for index in range(1, 5)) == (
        255,
        10,
        20,
        30,
    )
    assert record.background_preserve_shading is True
    assert customization.remove(mod, "gear-1") is True
    assert customization.get(mod, "gear-1") is None
    assert globals_.settings_flushes == 0
    customization.update_runtime()
    assert globals_.settings_flushes == 1
    customization.update_runtime()
    assert globals_.settings_flushes == 1

    context = lua.table_from(
        {
            "gear_id": "gear-1",
            "name": "Dueling Sword Mk IV",
            "widget": lua.table_from(
                {"content": lua.table_from({"display_name": "Dueling Sword Mk IV"})}
            ),
        }
    )
    assert customization.show_color_picker(mod, "name", context, None) is True
    popup = globals_.captured_popup
    assert popup.type == "grid"
    assert popup.title_text_unlocalized == "Change item name color(Dueling Sword Mk IV)"
    assert len(popup.grid_layout) == 4
    assert len(popup.options) == 3
    assert [popup.options[index].text for index in range(1, 4)] == [
        "Confirm",
        "Reset to default",
        "Cancel",
    ]
    assert all(popup.options[index].no_localization is True for index in range(1, 4))
    assert popup.options[3].hotkey == "back"

    header_blueprint = popup.grid_blueprints.color_header
    header_widget = lua.table_from(
        {
            "content": lua.table_from(
                {"hex_hotspot": lua.table_from({"on_pressed": True})}
            ),
            "style": lua.table_from({}),
        }
    )
    header_blueprint.init(None, header_widget, popup.grid_layout[1])
    globals_.Keyboard.strokes = lua.table_from(["#112233"])
    header_blueprint.update(None, header_widget)
    assert header_widget.content.hex_text == "Hex: #112233 |"
    assert header_widget.content.hex_buffer == "112233"
    header_widget.content.hex_hotspot.on_pressed = False
    globals_.Keyboard.strokes = lua.table_from(["F"])
    header_blueprint.update(None, header_widget)
    assert header_widget.content.hex_buffer == "112233"

    slider_blueprint = popup.grid_blueprints.color_slider
    red_element = popup.grid_layout[2]
    red_widget = lua.table_from({"content": lua.table_from({}), "style": lua.table_from({})})
    slider_blueprint.init(None, red_widget, red_element)
    assert abs(red_widget.content.slider_value - (17 / 255)) < 0.0001
    red_widget.content.slider_value = 0.5
    slider_blueprint.update(None, red_widget)
    header_widget.content.hex_hotspot.on_pressed = False
    header_widget.content.hex_editing = False
    globals_.Keyboard.strokes = lua.table_from([])
    header_blueprint.update(None, header_widget)
    assert header_widget.content.hex_text == "Hex: #802233"
    popup.options[1].callback()
    stored_color = customization.get(mod, "gear-1").name_color
    assert stored_color[2] == 128
    assert context.widget.content.display_name == "Dueling Sword Mk IV"

    customization.show_color_picker(mod, "background", context, None)
    popup = globals_.captured_popup
    assert len(popup.grid_layout) == 5
    shading_blueprint = popup.grid_blueprints.shading_checkbox
    shading_widget = lua.table_from(
        {"content": lua.table_from({"hotspot": lua.table_from({})})}
    )
    shading_blueprint.init(None, shading_widget, popup.grid_layout[5])
    assert shading_widget.content.checked is True
    shading_widget.content.hotspot.on_pressed = True
    shading_blueprint.update(None, shading_widget)
    assert shading_widget.content.checked is False
    popup.options[1].callback()
    stored_background = customization.get(mod, "gear-1").background_color
    assert tuple(stored_background[index] for index in range(1, 5)) == (
        255,
        45,
        55,
        45,
    )
    assert customization.get(mod, "gear-1").background_preserve_shading is False
    assert settings.custom_item_preserve_card_shading is False

    popup.options[2].callback()
    assert customization.get(mod, "gear-1").background_color is None
    assert customization.get(mod, "gear-1").background_preserve_shading is None

    globals_.name_it_settings.name_list["legacy-gear"] = "Legacy Name"
    assert customization.import_name_it_names(mod) == 1
    assert customization.get(mod, "legacy-gear").name == "Legacy Name"
    assert customization.get(mod, "legacy-gear").name_target == "primary"

    globals_.name_it_settings.replace_pattern_name = True
    globals_.name_it_settings.name_list["legacy-pattern"] = "Legacy Pattern Name"
    assert customization.import_name_it_names(mod) == 1
    assert customization.get(mod, "legacy-pattern").name_target == "sub"

    customization.update(
        mod, "legacy-gear", lua.table_from({"name": "BetterInventory Name"})
    )
    assert globals_.name_it_settings.name_list["legacy-gear"] == "BetterInventory Name"
    assert customization.get(mod, "legacy-gear").name_target is None

    # Resetting an imported pattern-target name while retaining color data
    # must not leak the old subtitle target into the next internal name.
    customization.update(
        mod,
        "legacy-pattern",
        lua.table_from({"name_color": lua.table_from([255, 1, 2, 3])}),
    )
    customization.update(mod, "legacy-pattern", lua.table_from({"name": False}))
    assert customization.get(mod, "legacy-pattern").name_target is None
    customization.update(
        mod, "legacy-pattern", lua.table_from({"name": "New Primary Name"})
    )
    assert customization.get(mod, "legacy-pattern").name_target is None

    customization.remove(mod, "legacy-gear")
    assert globals_.name_it_settings.name_list["legacy-gear"] is None

    # Disabling BetterInventory hands name ownership to Name It. Re-enabling
    # imports Name It's complete state (including removals) while preserving
    # BetterInventory-only color data.
    customization.update(
        mod,
        "handoff-gear",
        lua.table_from(
            {
                "name": "Old BetterInventory Name",
                "name_color": lua.table_from([255, 1, 2, 3]),
                "character_id": "character-a",
            }
        ),
    )
    settings.enable_custom_item_name_and_colors = False
    customization.on_setting_changed(mod, "enable_custom_item_name_and_colors")
    assert settings._custom_item_name_it_owns_names is True
    globals_.name_it_settings.name_list["handoff-gear"] = "New Name It Name"
    globals_.name_it_settings.name_list["name-it-only"] = "Name It Addition"
    settings.enable_custom_item_name_and_colors = True
    assert (
        customization.on_setting_changed(mod, "enable_custom_item_name_and_colors")
        is True
    )
    assert customization.get(mod, "handoff-gear").name == "New Name It Name"
    assert customization.get(mod, "handoff-gear").name_color[2] == 1
    assert customization.get(mod, "name-it-only").name == "Name It Addition"
    assert settings._custom_item_name_it_owns_names is False

    globals_.name_it_settings.name_list["handoff-gear"] = None
    settings.enable_custom_item_name_and_colors = False
    customization.on_setting_changed(mod, "enable_custom_item_name_and_colors")
    settings.enable_custom_item_name_and_colors = True
    customization.on_setting_changed(mod, "enable_custom_item_name_and_colors")
    assert customization.get(mod, "handoff-gear").name is None
    assert customization.get(mod, "handoff-gear").name_color[2] == 1

    # Disabling the entire mod performs the same handoff, and on_enabled must
    # reconcile because DMF does not rerun on_all_mods_loaded for every toggle.
    customization.update(
        mod, "whole-mod-handoff", lua.table_from({"name": "Before Toggle"})
    )
    customization.on_disabled(mod)
    assert settings._custom_item_name_it_owns_names is True
    globals_.name_it_settings.name_list["whole-mod-handoff"] = "After Toggle"
    customization.on_enabled(mod)
    assert customization.get(mod, "whole-mod-handoff").name == "After Toggle"
    assert settings._custom_item_name_it_owns_names is False
    assert globals_.enabled_cleanup_hooks.on_gear_deleted == "GearService"
    assert globals_.enabled_cleanup_hooks.on_character_deleted == "GearService"

    settings.custom_item_name_keybind = "hotkey_menu_special_1"
    settings.custom_item_name_color_keybind = "hotkey_menu_special_1"
    settings.custom_item_background_color_keybind = "group_finder_refresh_groups"
    globals_.name_it_settings.keybind_change_name = "hotkey_menu_special_2"
    inventory_view_class = lua.table_from({})
    assert customization.install(mod, inventory_view_class, lua.table_from({})) is True
    view = lua.table_from(
        {
            "_definitions": lua.table_from(
                {
                    "legend_inputs": lua.table_from(
                        [
                            lua.table_from(
                                {
                                    "input_action": "hotkey_menu_special_2",
                                    "on_pressed_callback": "cb_on_change_name_pressed",
                                }
                            )
                        ]
                    )
                }
            )
        }
    )
    globals_.captured_hooks.init(lua.eval("function() end"), view)
    globals_.captured_hooks._setup_input_legend(
        lua.eval(
            "function(view) built_legend = table.clone(view._definitions.legend_inputs) end"
        ),
        view,
    )
    legend = view._definitions.legend_inputs
    built_legend = globals_.built_legend
    assert len(legend) == 3
    assert len(built_legend) == 3
    assert [legend[index].display_name for index in range(1, 4)] == [
        "better_inventory_change_name",
        "better_inventory_name_color",
        "better_inventory_background_color",
    ]
    assert [legend[index].input_action for index in range(1, 4)] == [
        "hotkey_menu_special_2",
        "hotkey_menu_special_1",
        "group_finder_refresh_groups",
    ]
    assert [built_legend[index].input_action for index in range(1, 4)] == [
        "hotkey_menu_special_2",
        "hotkey_menu_special_1",
        "group_finder_refresh_groups",
    ]
    assert all(
        legend[index].on_pressed_callback != "cb_on_change_name_pressed"
        for index in range(1, 4)
    )

    # The name popup exposes and focuses a real text field, then reserves room
    # for it between the title/description and the three action buttons.
    detached_input_widget = lua.table_from(
        {"content": lua.table_from({"visible": False, "is_writing": False})}
    )
    detached_handler = lua.table_from(
        {
            "_widgets_by_name": lua.table_from(
                {"better_inventory_name_input": detached_input_widget}
            )
        }
    )
    globals_.captured_safe_hooks.update(detached_handler)

    input_widget = lua.table_from(
        {"content": lua.table_from({"visible": False, "is_writing": False})}
    )
    popup_handler = lua.table_from(
        {
            "_widgets_by_name": lua.table_from(
                {
                    "better_inventory_name_input": input_widget,
                    "description_text": lua.table_from(
                        {
                            "content": lua.table_from(
                                {
                                    "text": "Enter a custom name. Leave it blank to restore the default name."
                                }
                            )
                        }
                    ),
                    "title_text": lua.table_from({"scenegraph_id": "title"}),
                }
            ),
            "scenegraph_position": lua.eval(
                "function(self, id) return { 0, id == 'title' and 10 or 20 } end"
            ),
            "set_scenegraph_position": lua.eval(
                "function(self, id, x, y) adjusted_positions[id] = y end"
            ),
        }
    )
    globals_.adjusted_positions = lua.table_from({})
    globals_.captured_safe_hooks.update(popup_handler)
    assert customization.show_name_editor(mod, context, lua.table_from({})) is True
    popup = globals_.captured_popup
    assert detached_input_widget.content.visible is False
    assert input_widget.content.visible is True
    assert input_widget.content.is_writing is True
    assert [popup.options[index].text for index in range(1, 4)] == [
        "Confirm",
        "Reset to default",
        "Cancel",
    ]
    assert popup.options[3].hotkey == "back"
    popup_height = globals_.captured_hooks._update_popup_text_height(
        lua.eval("function() return 100 end"), popup_handler
    )
    assert popup_height == 160
    assert globals_.adjusted_positions.title == -20
    assert globals_.adjusted_positions.button_pivot == 50

    # Saving refreshes both the selected inventory card and the matching card
    # already alive in the character overview underneath it.
    overview_item = lua.table_from({"gear_id": "gear-1"})
    overview_widget = lua.table_from(
        {
            "marker": "overview",
            "content": lua.table_from(
                {"element": lua.table_from({"item": overview_item})}
            )
        }
    )
    globals_.active_inventory_view = lua.table_from(
        {"_loadout_widgets": lua.table_from([overview_widget])}
    )
    globals_.refresh_calls = lua.table_from({})
    refresh_layout = lua.table_from(
        {
            "refresh_item_customization": lua.eval(
                "function(mod, widget) refresh_calls[#refresh_calls + 1] = widget end"
            )
        }
    )
    context.widget.marker = "selected"
    customization.show_color_picker(mod, "background", context, refresh_layout)
    globals_.captured_popup.options[1].callback()
    assert len(globals_.refresh_calls) == 2
    assert globals_.refresh_calls[1].marker == "selected"
    assert globals_.refresh_calls[2].marker == "overview"

    # Name It's Hadron action is retained, but routed to BetterInventory while
    # this module owns names and restored as the fallback when it does not.
    globals_.name_it_crafting_calls = 0
    crafting_parent = lua.table_from(
        {
            "cb_on_change_name_pressed": lua.eval(
                "function() name_it_crafting_calls = name_it_crafting_calls + 1 end"
            )
        }
    )
    crafting_child = lua.table_from(
        {
            "selected_grid_widget": lua.eval(
                "function() return crafting_selected_widget end"
            )
        }
    )
    globals_.crafting_selected_widget = lua.table_from(
        {
            "content": lua.table_from(
                {
                    "display_name": "Hadron Sword",
                    "element": lua.table_from(
                        {
                            "item": lua.table_from(
                                {
                                    "gear_id": "crafting-gear",
                                    "item_type": "WEAPON_MELEE",
                                }
                            )
                        }
                    ),
                }
            )
        }
    )
    globals_.active_inventory_view = crafting_child
    globals_.captured_safe_hooks.init(crafting_parent)
    settings.enable_custom_item_name_and_colors = True
    crafting_parent.cb_on_change_name_pressed(crafting_parent)
    assert globals_.captured_popup.title_text_unlocalized.startswith(
        "Change item name ("
    )
    assert globals_.name_it_crafting_calls == 0
    settings.enable_custom_item_name_and_colors = False
    crafting_parent.cb_on_change_name_pressed(crafting_parent)
    assert globals_.name_it_crafting_calls == 1

    # Character deletion removes both newly tagged records and legacy records
    # discoverable in Darktide's cache, with one batched storage update.
    customization.update(
        mod,
        "owned-by-deleted-character",
        lua.table_from(
            {"name_color": lua.table_from([255, 1, 2, 3]), "character_id": "deleted-character"}
        ),
    )
    customization.update(
        mod,
        "legacy-owned-by-deleted-character",
        lua.table_from({"name": "Legacy Orphan"}),
    )
    gear_service = lua.table_from(
        {
            "_cached_gear_list": lua.table_from(
                {
                    "legacy-owned-by-deleted-character": lua.table_from(
                        {"characterId": "deleted-character"}
                    )
                }
            )
        }
    )
    globals_.test_mod_enabled = False
    globals_.captured_hooks.on_character_deleted(
        lua.eval("function(service) service.character_delete_called = true end"),
        gear_service,
        "deleted-character",
    )
    assert gear_service.character_delete_called is True
    assert customization.get(mod, "owned-by-deleted-character") is None
    assert customization.get(mod, "legacy-owned-by-deleted-character") is None

    print("BetterInventory item customization tests passed.")


if __name__ == "__main__":
    main()

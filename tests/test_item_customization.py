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
            elseif string.find(path, "text_input_pass_templates", 1, true) then
                return {
                    simple_input_field = {},
                }
            elseif string.find(path, "ui_widget", 1, true) then
                return {
                    create_definition = function(_, scenegraph_id)
                        return {
                            scenegraph_id = scenegraph_id,
                            content = {},
                        }
                    end,
                }
            elseif string.find(path, "ui_scenegraph", 1, true) then
                return {
                    init_scenegraph = function(definition)
                        rebuilt_scenegraph_definition = definition
                        return { rebuilt = true }
                    end,
                }
            end

            return {}
        end

        settings = {}
        name_it_settings = { name_list = {} }
        name_it_available = true
        name_it_get_fails = false
        name_it_replace_pattern_get_fails = false
        name_it_set_calls = 0
        test_name_it_mod = {}

        function test_name_it_mod:get(setting_id)
            if name_it_replace_pattern_get_fails and setting_id == "replace_pattern_name" then
                error("simulated Name It setting read failure")
            end

            return name_it_settings[setting_id]
        end

        function test_name_it_mod:set(setting_id, value)
            name_it_set_calls = name_it_set_calls + 1
            name_it_settings[setting_id] = value
        end

        function test_name_it_mod.get_custom_name_list()
            if name_it_get_fails then
                error("simulated Name It read failure")
            end

            return name_it_settings.name_list
        end

        settings_flushes = 0
        settings_flush_attempts = 0
        settings_flush_should_fail = false
        settings_flush_should_swallow_failure = false
        test_dmf_mod = {
            save_unsaved_settings_to_file = function()
                settings_flush_attempts = settings_flush_attempts + 1

                if settings_flush_should_fail then
                    error("simulated settings write failure")
                end

                if settings_flush_should_swallow_failure then
                    return nil
                end

                settings_flushes = settings_flushes + 1
                return true
            end,
        }

        function get_mod(name)
            return name == "name_it" and name_it_available and test_name_it_mod or name == "DMF" and test_dmf_mod or nil
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

        popup_definitions = {
            scenegraph_definition = {
                center_pivot = {},
            },
            widget_definitions = {},
        }

        function test_mod:hook_require(path, callback)
            callback(popup_definitions)
        end

        warning_count = 0

        function test_mod:warning(message)
            warning_count = warning_count + 1
            last_warning = message
        end

        function test_mod:hook(target, method, callback)
            captured_hooks[method] = callback
        end

        captured_safe_hooks = {}

        function test_mod:hook_safe(target, method, callback)
            captured_safe_hooks[method] = callback
        end

        captured_popup = nil
        function capture_popup(self, event_name, context)
            assert(event_name == "event_show_ui_popup")
            captured_popup = context
        end

        Managers = {
            event = {
                trigger = capture_popup,
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

    # Startup sanitization removes malformed legacy records and fields without
    # discarding a valid customization that can still be recovered safely.
    settings.custom_item_name_and_colors = lua.table_from(
        {
            "recoverable": lua.table_from(
                {
                    "name": "  Safe\n Name  ",
                    "name_color": "invalid",
                    "background_color": lua.table_from([255, 1, 2, 3]),
                    "background_preserve_shading": "invalid",
                    "name_target": "invalid",
                    "character_id": 12,
                }
            ),
            "empty": lua.table_from({"character_id": "orphan-only"}),
            12: "invalid record",
        }
    )
    customization.on_enabled(mod)
    recovered = customization.get(mod, "recoverable")
    assert recovered.name == "Safe Name"
    assert recovered.name_color is None
    assert recovered.background_color[2] == 1
    assert recovered.background_preserve_shading is None
    assert recovered.name_target is None
    assert recovered.character_id is None
    assert customization.get(mod, "empty") is None
    assert settings.custom_item_name_and_colors[12] is None
    assert customization.remove(mod, "recoverable") is True

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
    customization.update_runtime(mod)
    assert globals_.settings_flushes == 1

    assert customization.update(
        mod, "bounded-name", lua.table_from({"name": "  A\n" + ("B" * 100) + "  "})
    ) is True
    bounded_name = customization.get(mod, "bounded-name").name
    assert "\n" not in bounded_name
    assert not bounded_name.startswith(" ")
    assert not bounded_name.endswith(" ")
    assert len(bounded_name) == 80
    assert customization.update(
        mod, "bounded-name", lua.table_from({"name": " \t\n "})
    ) is True
    assert customization.get(mod, "bounded-name") is None
    customization.update_runtime(mod)
    assert globals_.settings_flushes == 2
    customization.update_runtime(mod)
    assert globals_.settings_flushes == 2

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

    globals_.name_it_replace_pattern_get_fails = True
    globals_.name_it_settings.name_list["guarded-pattern"] = "Guarded Pattern Name"
    assert customization.import_name_it_names(mod) == 1
    assert customization.get(mod, "guarded-pattern").name_target == "primary"
    globals_.name_it_replace_pattern_get_fails = False

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
    globals_.captured_hooks.init(
        lua.eval(
            """
            function(initializing_view)
                assert(type(initializing_view.cb_on_better_inventory_change_name_pressed) == "function")
                assert(type(initializing_view.cb_on_better_inventory_name_color_pressed) == "function")
                assert(type(initializing_view.cb_on_better_inventory_background_color_pressed) == "function")
            end
            """
        ),
        view,
    )
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
        "hotkey_menu_special_1",
        "hotkey_menu_special_1",
        "group_finder_refresh_groups",
    ]
    assert [built_legend[index].input_action for index in range(1, 4)] == [
        "hotkey_menu_special_1",
        "hotkey_menu_special_1",
        "group_finder_refresh_groups",
    ]
    assert all(
        legend[index].on_pressed_callback != "cb_on_change_name_pressed"
        for index in range(1, 4)
    )

    # Rebuilding the legend is idempotent, and disabling BetterInventory's
    # editor restores Name It's action instead of losing it permanently.
    globals_.captured_hooks._setup_input_legend(lua.eval("function() end"), view)
    assert len(legend) == 3
    settings.enable_custom_item_name_and_colors = False
    globals_.captured_hooks._setup_input_legend(lua.eval("function() end"), view)
    assert len(legend) == 1
    assert legend[1].on_pressed_callback == "cb_on_change_name_pressed"
    settings.enable_custom_item_name_and_colors = True
    globals_.captured_hooks._setup_input_legend(lua.eval("function() end"), view)
    assert len(legend) == 3

    # Standalone mode uses BetterInventory's key and never resurrects a saved
    # Name It action while that optional mod is unavailable.
    globals_.name_it_available = False
    settings.custom_item_name_keybind = "hotkey_menu_special_1"
    globals_.captured_hooks._setup_input_legend(lua.eval("function() end"), view)
    assert len(legend) == 3

    settings.custom_item_name_color_keybind = "off"
    globals_.captured_hooks._setup_input_legend(lua.eval("function() end"), view)
    assert len(legend) == 2
    settings.custom_item_name_color_keybind = "hotkey_menu_special_1"
    globals_.captured_hooks._setup_input_legend(lua.eval("function() end"), view)
    assert len(legend) == 3
    assert legend[1].input_action == "hotkey_menu_special_1"
    settings.enable_custom_item_name_and_colors = False
    globals_.captured_hooks._setup_input_legend(lua.eval("function() end"), view)
    assert len(legend) == 0
    globals_.name_it_available = True
    settings.enable_custom_item_name_and_colors = True
    settings.custom_item_name_keybind = "hotkey_menu_special_1"
    globals_.captured_hooks._setup_input_legend(lua.eval("function() end"), view)
    assert len(legend) == 3

    # The global popup handler may predate hook_require's definition changes.
    # Its update hook must repair the live scenegraph and attach the field.
    dynamic_popup_handler = lua.table_from(
        {
            "_definitions": globals_.popup_definitions,
            "_widgets": lua.table_from([]),
            "_widgets_by_name": lua.table_from({}),
            "_create_widget": lua.eval(
                "function(_, name, definition) local widget = table.clone(definition); widget.name = name; return widget end"
            ),
        }
    )
    globals_.captured_safe_hooks.update(dynamic_popup_handler)
    repaired_input_widget = dynamic_popup_handler._widgets_by_name[
        "better_inventory_name_input"
    ]
    assert repaired_input_widget is not None
    assert dynamic_popup_handler._ui_scenegraph.rebuilt is True
    assert len(dynamic_popup_handler._widgets) == 1
    globals_.captured_safe_hooks.update(dynamic_popup_handler)
    assert len(dynamic_popup_handler._widgets) == 1

    # A broken handler is bounded to three repair attempts and one warning,
    # preventing a protected failure from becoming per-frame overhead.
    failing_popup_handler = lua.table_from(
        {
            "_definitions": globals_.popup_definitions,
            "_widgets": lua.table_from([]),
            "_widgets_by_name": lua.table_from({}),
            "_create_widget": lua.eval(
                "function() error('simulated widget creation failure') end"
            ),
        }
    )
    initial_warning_count = globals_.warning_count
    for _ in range(5):
        globals_.captured_safe_hooks.update(failing_popup_handler)
    assert failing_popup_handler._better_inventory_name_input_creation_attempts == 3
    assert globals_.warning_count == initial_warning_count + 1

    # Q can also be pressed before the popup handler update. The editor must
    # repair the live handler on demand instead of silently doing nothing.
    globals_.live_popup_handler = lua.table_from(
        {
            "_definitions": globals_.popup_definitions,
            "_widgets": lua.table_from([]),
            "_widgets_by_name": lua.table_from({}),
            "_create_widget": lua.eval(
                "function(_, name, definition) local widget = table.clone(definition); widget.name = name; return widget end"
            ),
        }
    )
    lua.execute(
        """
        Managers.ui.ui_constant_elements = function()
            return {
                element = function(_, name)
                    assert(name == "ConstantElementPopupHandler")
                    return live_popup_handler
                end,
            }
        end
        """
    )
    assert customization.show_name_editor(mod, context, lua.table_from({})) is True
    live_input_widget = globals_.live_popup_handler._widgets_by_name[
        "better_inventory_name_input"
    ]
    assert live_input_widget.content.visible is True
    assert live_input_widget.content.is_writing is True
    globals_.captured_popup.options[3].callback()
    assert live_input_widget.content.visible is False
    assert live_input_widget.content.is_writing is False

    # If Darktide cannot open the popup, typing state is rolled back.
    lua.execute("Managers.event = nil")
    assert customization.show_name_editor(mod, context, lua.table_from({})) is False
    assert live_input_widget.content.visible is False
    assert live_input_widget.content.is_writing is False
    lua.execute("Managers.event = { trigger = capture_popup }")
    lua.execute("Managers.ui.ui_constant_elements = nil")

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

    # Multiple backend deletion notifications in one frame are drained through
    # one table update instead of cloning the complete settings map per item.
    settings.enable_custom_item_name_and_colors = True
    globals_.test_mod_enabled = True
    customization.update(mod, "batch-delete-a", lua.table_from({"name": "A"}))
    customization.update(mod, "batch-delete-b", lua.table_from({"name": "B"}))
    globals_.captured_safe_hooks.on_gear_deleted(None, "batch-delete-a")
    globals_.captured_safe_hooks.on_gear_deleted(None, "batch-delete-b")
    assert customization.get(mod, "batch-delete-a") is not None
    assert customization.get(mod, "batch-delete-b") is not None
    customization.update_runtime(mod)
    assert customization.get(mod, "batch-delete-a") is None
    assert customization.get(mod, "batch-delete-b") is None

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

    # A failed Name It read must never be converted into a partial replacement
    # map containing only the item BetterInventory just edited.
    globals_.name_it_get_fails = True
    name_it_set_calls_before_failure = globals_.name_it_set_calls
    customization.update(mod, "name-it-read-failure", lua.table_from({"name": "Safe"}))
    assert globals_.name_it_set_calls == name_it_set_calls_before_failure
    globals_.name_it_get_fails = False

    # DMF settings writes remain pending after a protected failure and retry on
    # the next update instead of silently discarding the durability request.
    globals_.settings_flush_should_fail = True
    flushes_before_failure = globals_.settings_flushes
    attempts_before_failure = globals_.settings_flush_attempts
    customization.update_runtime(mod)
    assert globals_.settings_flush_attempts == attempts_before_failure + 1
    assert globals_.settings_flushes == flushes_before_failure
    status, pending = customization.persistence_status()
    assert status == "error"
    assert pending is True
    globals_.settings_flush_should_fail = False
    customization.update_runtime(mod, 1)
    assert globals_.settings_flushes == flushes_before_failure + 1

    # Current DMF can swallow an inner settings-write failure and return nil.
    # BetterInventory must retain dirty state, retry later, and avoid retrying
    # on every frame while the result remains unknown.
    customization.update(mod, "dmf-swallowed-failure", lua.table_from({"name": "Retry me"}))
    globals_.settings_flush_should_swallow_failure = True
    attempts_before_swallowed_failure = globals_.settings_flush_attempts
    flushes_before_swallowed_failure = globals_.settings_flushes
    customization.update_runtime(mod)
    assert globals_.settings_flush_attempts == attempts_before_swallowed_failure + 1
    assert globals_.settings_flushes == flushes_before_swallowed_failure
    status, pending = customization.persistence_status()
    assert status == "unknown"
    assert pending is True
    customization.update_runtime(mod)
    assert globals_.settings_flush_attempts == attempts_before_swallowed_failure + 1
    globals_.settings_flush_should_swallow_failure = False
    customization.update_runtime(mod, 1)
    assert globals_.settings_flush_attempts == attempts_before_swallowed_failure + 2
    assert globals_.settings_flushes == flushes_before_swallowed_failure + 1
    status, pending = customization.persistence_status()
    assert status == "saved"
    assert pending is False

    # Disabling the mod while the editor is open must release keyboard capture.
    globals_.captured_safe_hooks.update(popup_handler)
    assert customization.show_name_editor(mod, context, lua.table_from({})) is True
    assert input_widget.content.is_writing is True
    customization.on_disabled(mod)
    assert input_widget.content.visible is False
    assert input_widget.content.is_writing is False

    print("BetterInventory item customization tests passed.")


if __name__ == "__main__":
    main()

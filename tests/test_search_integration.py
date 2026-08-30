from pathlib import Path

from coverage_support import InstrumentedLuaRuntime as LuaRuntime


PROJECT_ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = (
    PROJECT_ROOT
    / "scripts"
    / "mods"
    / "BetterInventory"
    / "BetterInventory_search_integration.lua"
)


def main() -> None:
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute(
        r'''
        begins = 0
        cleanups = 0
        configured_sorts = 0
        requested_resorts = 0
        projected_releases = 0
        release_all_calls = 0
        clear_memory_calls = 0

        stub_query = {
            normalize = function(value) return string.lower(tostring(value or "")) end,
        }
        stub_index = {
            new = function(dependencies)
                last_index_dependencies = dependencies
                return {dependencies = dependencies}
            end,
            project = function() return {text = {"item"}}, true end,
            invalidate = function() return true end,
            invalidate_all = function() return true end,
            rarity_aliases = function() return {} end,
            release = function()
                projected_releases = projected_releases + 1
                return true
            end,
        }
        stub_runtime = {
            new = function(dependencies)
                runtime_instance = {dependencies = dependencies, states = {}}
                return runtime_instance
            end,
            capture_presentation = function(runtime, view, slot, item_type, title)
                runtime.index = runtime.index or runtime.dependencies.new_index(view)
                runtime.capture = {view, slot, item_type, title}
                return true
            end,
            apply_widget_alpha = function() return true end,
            clear_memory = function() clear_memory_calls = clear_memory_calls + 1 end,
            native_filter = function(_, _, _, native) return native end,
            invalidate_all = function() return true end,
            is_active = function() return true end,
            query = function() return "sword" end,
            rank = function(_, _, entry) return entry and entry.match and 1 or 0 end,
			matches = function(_, _, entry) return entry and entry.match == true end,
            release = function() return true end,
            release_all = function()
                release_all_calls = release_all_calls + 1
                return 3
            end,
            set_query = function(_, _, query)
                return query ~= "bad", query == "bad" and "invalid" or nil
            end,
            update = function() return true end,
        }
        stub_discard = {
            equipped_gear_ids = function()
                return {loadout_weapon = true}
            end,
            is_perfect_roll_weapon = function(item)
                return item and item.perfect == true
            end,
        }
        stub_items = {
            is_item_id_favorited = function() return false end,
        }
        stub_master_items = {}
        stub_profile_utils = {
            get_profile_presets = function() return {} end,
        }
        stub_rarity_settings = {}
        function require(path)
            if path == "scripts/utilities/items" then return stub_items end
            if path == "scripts/backend/master_items" then return stub_master_items end
            if path == "scripts/utilities/profile_utils" then return stub_profile_utils end
            if path == "scripts/settings/item/rarity_settings" then return stub_rarity_settings end
            error(path)
        end
        test_settings = {
            enable_inventory_search = true,
            enable_inventory_search_brunt = false,
            inventory_search_non_match_behavior = "dim",
            inventory_search_remember_query = false,
        }
        test_mod = {
            get = function(_, setting)
                return test_settings[setting]
            end,
        }
        function get_mod()
            return {
                io_dofile = function(_, path)
                    if string.find(path, "search_query", 1, true) then return stub_query end
                    if string.find(path, "search_index", 1, true) then return stub_index end
                    if string.find(path, "search_runtime", 1, true) then return stub_runtime end
                    if string.find(path, "discard_policy", 1, true) then return stub_discard end
                    error(path)
                end,
            }
        end
        ''',
    )
    integration = lua.execute(MODULE_PATH.read_text(encoding="utf-8"), name=str(MODULE_PATH))
    lua.execute(
        r'''
        legacy_warning = nil
        warning_mod = {warning = function(_, message) legacy_warning = message end}
        legacy_mod = {is_enabled = function() return true end}
        legacy_resolver = function(name)
            return name == "stuff_searcher" and legacy_mod or nil
        end
        ''',
    )
    assert integration.warn_legacy_searcher(lua.globals().warning_mod, None) is False
    assert integration.warn_legacy_searcher(
        lua.globals().warning_mod, lua.globals().legacy_resolver
    ) is True
    assert "Stuff Searcher" in lua.globals().legacy_warning
    assert integration.warn_legacy_searcher(
        lua.globals().warning_mod, lua.globals().legacy_resolver
    ) is False

    def family(class_name: str, service=None):
        view = lua.table_from({"__class_name": class_name})
        if service is not None:
            view._optional_store_service = service
        return integration.view_family(view, "global")

    assert family("InventoryWeaponsView") == "inventory"
    assert family("CraftingMechanicusModifyView") == "hadron"
    assert family("CraftingMechanicusBarterItemsView") is None
    assert family("MarksVendorView") == "melk"
    assert family("MarksGoodsVendorView") is None
    assert family("CreditsVendorView") == "armoury"
    assert family("CreditsVendorView", "global") == "armoury"
    assert family("CreditsVendorView", "other") == "vendor"
    assert family("CreditsGoodsVendorView") == "vendor"
    assert family("CosmeticsVendorView") is None
    unavailable = lua.table_from(
        {
            "__class_name": "InventoryWeaponsView",
            "_better_inventory_search_ui_unavailable": True,
        }
    )
    assert integration.view_family(unavailable, "global") is None

    lua.execute(
        r'''
        facade = {
            begin_view_session = function() begins = begins + 1 end,
            register_view_session_cleanup = function(_, _, callback)
                cleanups = cleanups + 1
                registered_cleanup = callback
            end,
            request_inventory_resort = function() requested_resorts = requested_resorts + 1 end,
        }
        providers = {
            CompactCurioPerkSearchTerms = function(_, id, description)
                compact_curio_provider_id = id
                compact_curio_provider_description = description
                return nil, "Ability Regen"
            end,
            CompactWeaponPerkSearchTerms = function(_, id, description)
                compact_provider_id = id
                compact_provider_description = description
                return "+25% Flak Damage", "+25% Flak Dmg"
            end,
            CurioTraitSearchTerms = function(_, id)
                curio_trait_provider_id = id
                return "Health", "health"
            end,
            CustomTier = {matches = function() return false end},
            ItemCustomization = {get = function() return nil end},
        }
        ''',
    )
    facade = lua.globals().facade
    installed = integration.install(
        facade,
        lua.globals().test_mod,
        lua.globals().providers,
        lua.eval("function() configured_sorts = configured_sorts + 1 end"),
        "global",
    )
    assert installed is True

    view = lua.table_from({"__class_name": "InventoryWeaponsView"})
    assert facade.search_capture_presentation(None, view, "slot", "weapon", "Weapons") is True
    assert lua.globals().begins == 1
    assert lua.globals().cleanups == 1
    assert lua.globals().configured_sorts == 1
    assert lua.globals().runtime_instance.capture[2] == "slot"
    assert lua.globals().last_index_dependencies.custom_tier is not None
    assert lua.execute("return last_index_dependencies.items == stub_items") is True
    lua.execute(
        r'''
        customization_value = last_index_dependencies.customization_get("item")
        equipped_item = {gear_id = "equipped", slots = {"slot_primary"}}
        direct_equipped_view = {
            is_item_equipped_in_any_slot = function() return true end,
        }
        fallback_equipped_view = {
            equipped_item_in_slot = function() return {gear_id = "equipped"} end,
        }
        direct_equipped = last_index_dependencies.is_equipped(
            equipped_item, {view = direct_equipped_view}
        )
        fallback_equipped = last_index_dependencies.is_equipped(
            equipped_item, {view = fallback_equipped_view}
        )
        missing_equipped = last_index_dependencies.is_equipped({}, {})
        loadout_match = last_index_dependencies.is_loadout({gear_id = "loadout_weapon"})
        new_match = last_index_dependencies.is_new({}, {entry = {new_item_marker = true}})
        compact_standard, compact_heavy = last_index_dependencies.compact_perk_search_terms(
            "weapon_trait_melee_common_wield_increased_armored_damage",
            "+25% Damage vs Flak Armoured Enemies"
        )
        compact_curio_standard, compact_curio_heavy = last_index_dependencies.compact_curio_perk_search_terms(
            "gadget_cooldown_reduction",
            "+3% Combat Ability Regeneration"
        )
        curio_trait_localized, curio_trait_canonical = last_index_dependencies.curio_trait_search_terms(
            "gadget_innate_health_increase"
        )

        normal_present_view = {
            _present_layout_by_slot_filter = function(_, slot, item_type, title)
                normal_present_arguments = {slot, item_type, title}
            end,
        }
        valid_present = runtime_instance.dependencies.present(
            normal_present_view, "slot", "weapon", "Weapons"
        )
        inventory_resort_present_view = {
            __class_name = "InventoryWeaponsView",
            _present_layout_by_slot_filter = function()
                inventory_full_present_calls = (inventory_full_present_calls or 0) + 1
            end,
        }
        inventory_resort_present = runtime_instance.dependencies.present(
            inventory_resort_present_view, "slot", "weapon", "Weapons"
        )
        inventory_resort_requests = requested_resorts
        requested_resorts = 0

        test_settings.inventory_search_non_match_behavior = "hide"
        inventory_hide_present = runtime_instance.dependencies.present(
            inventory_resort_present_view, "slot", "weapon", "Weapons"
        )
        test_settings.inventory_search_non_match_behavior = "dim"
        invalid_present = runtime_instance.dependencies.present({}, nil, nil, nil)
        current_mode = runtime_instance.dependencies.mode()
        remember_mode = runtime_instance.dependencies.remember_query()
        prioritize_equipped_mode = runtime_instance.dependencies.prioritize_equipped()
        ''',
    )
    assert lua.globals().customization_value is None
    assert lua.globals().direct_equipped is True
    assert lua.globals().fallback_equipped is True
    assert lua.globals().missing_equipped is False
    assert lua.globals().loadout_match is True
    assert lua.globals().compact_curio_standard is None
    assert lua.globals().compact_curio_heavy == "Ability Regen"
    assert lua.globals().compact_curio_provider_id == "gadget_cooldown_reduction"
    assert lua.globals().curio_trait_provider_id == "gadget_innate_health_increase"
    assert lua.globals().curio_trait_localized == "Health"
    assert lua.globals().curio_trait_canonical == "health"
    assert lua.globals().new_match is True
    assert lua.globals().compact_standard == "+25% Flak Damage"
    assert lua.globals().compact_heavy == "+25% Flak Dmg"
    assert lua.globals().compact_provider_id == "weapon_trait_melee_common_wield_increased_armored_damage"
    assert lua.globals().compact_provider_description == "+25% Damage vs Flak Armoured Enemies"
    assert lua.globals().valid_present is True
    assert lua.globals().inventory_resort_present is True
    assert lua.globals().inventory_resort_requests == 0
    assert lua.globals().inventory_full_present_calls == 2
    assert lua.globals().inventory_hide_present is True
    assert lua.globals().invalid_present is False
    assert lua.globals().normal_present_arguments[1] == "slot"
    assert lua.globals().current_mode == "dim"
    assert lua.globals().remember_mode is False
    assert lua.globals().prioritize_equipped_mode is True

    assert facade.search_query(view) == "sword"
    assert facade.search_rank(view, lua.table_from({"match": True})) == 1
    assert facade.search_filter_result(view, {}, True) is True
    assert facade.search_apply_widget_alpha(view) is True
    assert facade.search_invalidate_all(view, 1) is True
    assert facade.search_is_active(view) is True
    assert facade.search_update(view, 1) is True
    assert facade.search_set_query(view, "axe", 1) == (True, None)
    # Query changes use the runtime's single coalesced presentation instead of
    # also requesting an eager sorting presentation through the facade.
    assert lua.globals().requested_resorts == 0

    sacrifice = lua.table_from({"__class_name": "CraftingMechanicusBarterItemsView"})
    lua.globals().sacrifice = sacrifice
    assert facade.search_compose_layout is None
    assert lua.execute("return runtime_instance.dependencies.view_family(sacrifice) == nil") is True
    assert lua.globals().begins == 1
    assert lua.globals().cleanups == 1
    lua.execute(
        r'''
		shared_spacing = {is_external = true, widget_type = "spacing_vertical", entry_id = "bottom"}
		entry_a = {entry_id = "a", item = {gear_id = "a"}, match = false}
		entry_b = {entry_id = "b", item = {gear_id = "b"}, match = true}
		widget_a = {entry_id = "a", content = {element = entry_a}}
		widget_b = {entry_id = "b", content = {element = entry_b}}
		grid_state = {_selected_grid_index = 2}
		in_place_grid = {
			_grid = grid_state,
			_grid_layout = {shared_spacing, entry_a, entry_b, shared_spacing},
			_all_grid_alignment_widgets = {
				{entry_id = "top"}, {entry_id = "a"}, {entry_id = "b"}, {entry_id = "bottom"},
			},
			_widgets_by_entry_id = {
				top = {alignment_widget = {}},
				a = {widget = widget_a, alignment_widget = {}},
				b = {widget = widget_b, alignment_widget = {}},
				bottom = {alignment_widget = {}},
			},
			selected_grid_widget = function() return widget_b end,
			update_grid_layout = function(self, layout)
				in_place_updates = (in_place_updates or 0) + 1
				self._visible_grid_layout = layout
				self._grid_widgets = {}
				for index = 1, #layout do
					local record = self._widgets_by_entry_id[layout[index].entry_id]
					if record.widget then self._grid_widgets[#self._grid_widgets + 1] = record.widget end
				end
				self._grid._selected_grid_index = 1
			end,
		}
		in_place_view = {
			_item_grid = in_place_grid,
			_selected_sort_option_index = 1,
			_sort_options = {{
				sort_function = function(left, right)
					selected_sort_calls = (selected_sort_calls or 0) + 1
					return left.match == true and right.match ~= true
				end,
			}},
		}
		in_place_result = runtime_instance.dependencies.reorder(in_place_view)
		first_rank_sort = in_place_view._better_inventory_search_grid_buffers.rank_sort
		first_live_layout = in_place_grid._visible_grid_layout
		first_live_top = first_live_layout[1].entry_id
		first_live_item = first_live_layout[2]
		first_live_bottom = first_live_layout[4].entry_id
		first_selected_index = grid_state._selected_grid_index
		in_place_view._sort_options[1].sort_function = function(left, right)
			selected_sort_calls = (selected_sort_calls or 0) + 100
			return left.match ~= true and right.match == true
		end
		second_in_place_result = runtime_instance.dependencies.reorder(in_place_view, false)
		second_live_layout = in_place_grid._visible_grid_layout
		second_rank_sort = in_place_view._better_inventory_search_grid_buffers.rank_sort
		buffers_are_distinct = first_live_layout ~= second_live_layout
		first_buffer_was_not_cleared_while_live = #first_live_layout == 4
		hide_in_place_result = runtime_instance.dependencies.reorder(in_place_view, true)
		hidden_live_layout = in_place_grid._visible_grid_layout
		hidden_live_count = #hidden_live_layout
		hidden_live_item = hidden_live_layout[2]
		restore_in_place_result = runtime_instance.dependencies.reorder(in_place_view, false)
		restored_live_layout = in_place_grid._visible_grid_layout
		in_place_view._sort_options = nil
		in_place_view._selected_sort_option = nil
		fallback_in_place_result = runtime_instance.dependencies.reorder(in_place_view, false)
		fallback_live_layout = in_place_grid._visible_grid_layout
		fallback_live_item = fallback_live_layout[2]
		fallback_widget_b = in_place_grid._grid_widgets[1]
		for index = 1, 20 do
			stress_in_place_result = runtime_instance.dependencies.reorder(in_place_view, index % 2 == 0)
		end
		stress_buffers = in_place_view._better_inventory_search_grid_buffers
		stress_source_position_count = 0
		for _ in pairs(stress_buffers.source_positions) do
			stress_source_position_count = stress_source_position_count + 1
		end
        ''',
    )
    assert lua.globals().in_place_result is True
    assert lua.globals().second_in_place_result is True
    assert lua.globals().hide_in_place_result is True
    assert lua.globals().restore_in_place_result is True
    assert lua.globals().fallback_in_place_result is True
    assert lua.globals().in_place_updates == 25
    assert lua.globals().first_live_top == "top"
    assert lua.execute("return first_live_item == entry_b") is True
    assert lua.globals().first_live_bottom == "bottom"
    assert lua.globals().shared_spacing.entry_id == "bottom"
    assert lua.globals().first_selected_index == 1
    assert lua.globals().buffers_are_distinct is True
    assert lua.globals().first_buffer_was_not_cleared_while_live is True
    # Search partitions the already-native-sorted canonical layout by rank. It
    # must never re-run the selected comparator: GodRolls decorates
    # Items.display_name from that comparator with a full weapon projection.
    assert lua.globals().selected_sort_calls is None
    assert lua.execute("return first_rank_sort == second_rank_sort") is True
    assert lua.execute("return second_live_layout[2] == entry_b") is True
    assert lua.globals().hidden_live_count == 3
    assert lua.execute("return hidden_live_item == entry_b") is True
    assert len(lua.globals().restored_live_layout) == 4
    assert lua.execute("return fallback_live_item == entry_b") is True
    assert lua.execute("return fallback_widget_b == widget_b") is True
    assert lua.globals().stress_in_place_result is True
    assert lua.globals().stress_source_position_count == 2

    # Brunt has no native sort options. Its default-off gate suppresses runtime
    # registration; opting in exposes the same retained in-place lane above.
    lua.execute(
        r'''
        brunt_view = {__class_name = "CreditsGoodsVendorView"}
        brunt_family_disabled = runtime_instance.dependencies.view_family(brunt_view)
        test_settings.enable_inventory_search_brunt = true
        brunt_family_enabled = runtime_instance.dependencies.view_family(brunt_view)
        test_settings.enable_inventory_search_brunt = false
        ''',
    )
    assert lua.globals().brunt_family_disabled is None
    assert lua.globals().brunt_family_enabled == "vendor"

    lua.execute("runtime_instance.states[facade_state_view or {}] = nil")
    state_view = lua.table_from({"__class_name": "InventoryWeaponsView"})
    lua.globals().state_view = state_view
    lua.execute("runtime_instance.states[state_view] = true")
    assert facade.search_settings_changed("unrelated") == 0
    assert facade.search_settings_changed("customization_changed") == 1
    assert lua.globals().requested_resorts == 0
    assert facade.search_settings_changed("prioritize_equipped_favorites") == 1
    assert lua.globals().requested_resorts == 0
    lua.globals().test_settings.inventory_search_remember_query = False
    assert facade.search_settings_changed("inventory_search_remember_query") == 0
    assert lua.globals().clear_memory_calls == 1
    lua.globals().test_settings.enable_inventory_search = False
    assert facade.search_settings_changed("enable_inventory_search") == 3
    assert lua.globals().release_all_calls == 1
    assert lua.globals().clear_memory_calls == 2
    lua.globals().test_settings.enable_inventory_search = True
    assert facade.search_set_query(view, "bad", 1) == (False, "invalid")
    assert lua.globals().requested_resorts == 0

    lua.globals().registered_cleanup(view)
    assert facade.search_shutdown(True) == 3
    assert lua.globals().release_all_calls == 2
    assert lua.globals().clear_memory_calls == 3

    print("BetterInventory search integration tests passed.")


if __name__ == "__main__":
    main()

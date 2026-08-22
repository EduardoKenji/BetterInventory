from pathlib import Path

from coverage_support import InstrumentedLuaRuntime as LuaRuntime


PROJECT_ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = (
    PROJECT_ROOT
    / "scripts"
    / "mods"
    / "BetterInventory"
    / "BetterInventory_curio_acquisition.lua"
)
CURIO_VALUES_PATH = (
    PROJECT_ROOT
    / "scripts"
    / "mods"
    / "BetterInventory"
    / "BetterInventory_curio_values.lua"
)
CURIO_DOMAINS_PATH = (
    PROJECT_ROOT
    / "scripts"
    / "mods"
    / "BetterInventory"
    / "BetterInventory_curio_domains.lua"
)
CURIO_PROFILES_PATH = (
    PROJECT_ROOT
    / "scripts"
    / "mods"
    / "BetterInventory"
    / "BetterInventory_curio_profiles.lua"
)
CURIO_LEDGER_PATH = (
    PROJECT_ROOT
    / "scripts"
    / "mods"
    / "BetterInventory"
    / "BetterInventory_curio_ledger.lua"
)
CURIO_STORE_PATH = (
    PROJECT_ROOT
    / "scripts"
    / "mods"
    / "BetterInventory"
    / "BetterInventory_curio_store.lua"
)
CURIO_PURCHASE_PATH = (
    PROJECT_ROOT
    / "scripts"
    / "mods"
    / "BetterInventory"
    / "BetterInventory_curio_purchase.lua"
)


def main() -> None:
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute(
        r"""
        function math.clamp(value, minimum, maximum)
            return math.max(minimum, math.min(maximum, value))
        end

        TestPromise = {}

        local function is_promise(value)
            return type(value) == "table" and value.__test_promise == true
        end

        local function new_promise(value, error_value)
            local promise = {
                __test_promise = true,
                _value = value,
                _error = error_value,
            }

            function promise:next(callback)
                if self._error ~= nil then
                    return self
                end

                local results = {pcall(callback, self._value)}

                if not results[1] then
                    return new_promise(nil, results[2])
                end

                local result = results[2]

                if is_promise(result) then
                    return result
                end

                return new_promise(result, nil)
            end

            function promise:catch(callback)
                if self._error == nil then
                    return self
                end

                local results = {pcall(callback, self._error)}

                if not results[1] then
                    return new_promise(nil, results[2])
                end

                local result = results[2]

                if is_promise(result) then
                    return result
                end

                return new_promise(result, nil)
            end

            return promise
        end

        local function new_pending_promise()
            local promise = {
                __test_promise = true,
                _cancelled = false,
                _error = nil,
                _failure_callbacks = {},
                _settled = false,
                _success_callbacks = {},
            }

            function promise:is_pending()
                return not self._settled
            end

            local function settle_child(child, result, is_error)
                if is_error then
                    child:reject(result)
                elseif is_promise(result) then
                    result:next(function(value)
                        child:resolve(value)
                    end):catch(function(error_value)
                        child:reject(error_value)
                    end)
                else
                    child:resolve(result)
                end
            end

            function promise:next(callback, failure_callback)
                local child = new_pending_promise()

                local function on_success(value)
                    if type(callback) ~= "function" then
                        child:resolve(value)
                        return
                    end

                    local results = {pcall(callback, value)}

                    if not results[1] then
                        child:reject(results[2])
                    else
                        settle_child(child, results[2], false)
                    end
                end

                local function on_failure(error_value)
                    if type(failure_callback) ~= "function" then
                        child:reject(error_value)
                        return
                    end

                    local results = {pcall(failure_callback, error_value)}

                    if not results[1] then
                        child:reject(results[2])
                    else
                        settle_child(child, results[2], false)
                    end
                end

                if not self._settled then
                    table.insert(self._success_callbacks, on_success)
                    table.insert(self._failure_callbacks, on_failure)
                elseif self._error == nil then
                    on_success(self._value)
                else
                    on_failure(self._error)
                end

                return child
            end

            function promise:catch(callback)
                return self:next(nil, callback)
            end

            function promise:resolve(value)
                if self._settled then
                    return self
                end

                self._settled = true
                self._value = value

                for _, callback in ipairs(self._success_callbacks) do
                    callback(value)
                end

                return self
            end

            function promise:reject(error_value)
                if self._settled then
                    return self
                end

                self._settled = true
                self._error = error_value

                for _, callback in ipairs(self._failure_callbacks) do
                    callback(error_value)
                end

                return self
            end

            function promise:cancel()
                self._cancelled = true
                return self:reject("cancelled")
            end

            return promise
        end

        function TestPromise.resolved(value)
            return new_promise(value, nil)
        end

        function TestPromise.rejected(error_value)
            return new_promise(nil, error_value)
        end

        function TestPromise.pending()
            return new_pending_promise()
        end

        function TestPromise.all(...)
            local promises = {...}
            local values = {}

            for index = 1, #promises do
                local promise = promises[index]

                if not is_promise(promise) then
                    return TestPromise.rejected("non-promise passed to Promise.all")
                elseif promise._error ~= nil then
                    return TestPromise.rejected(promise._error)
                end

                values[index] = promise._value
            end

            return TestPromise.resolved(values)
        end

        trait_names = {
            health_trait = "gadget_innate_health_increase",
            toughness_trait = "gadget_innate_toughness_increase",
            stamina_trait = "gadget_stamina_increase",
            wound_trait = "gadget_innate_max_wounds_increase",
        }
        trait_values = {
            health_trait = 21,
            toughness_trait = 17,
            stamina_trait = 3,
            wound_trait = 1,
        }
        TestBuffTemplates = {
            gadget_innate_health_increase = {
                lerped_stat_buffs = {
                    max_health_modifier = {min = 0.15, max = 0.21},
                },
                localization_info = {max_health_modifier = "percentage"},
            },
            gadget_innate_toughness_increase = {
                lerped_stat_buffs = {
                    toughness_bonus = {min = 0.10, max = 0.17},
                },
                localization_info = {toughness_bonus = "percentage"},
            },
            gadget_stamina_increase = {
                class_name = "stepped_range_buff",
                stat_buffs = {stamina_modifier = {1, 2, 3}},
                localization_info = {},
            },
            gadget_innate_max_wounds_increase = {
                stat_buffs = {extra_max_amount_of_wounds = 1},
                localization_info = {},
            },
        }
        TestItems = {
            expertise_level = function(item)
                return item.level, true
            end,
            perk_item_by_id = function(trait_id)
                return {
                    source_id = trait_id,
                    trait = trait_names[trait_id],
                }
            end,
            trait_description = function(definition)
				if description_mode == "rich" then
					return "{#color(192, 255, 26)}" .. tostring(trait_values[definition.source_id]) .. "%{#reset()} primary"
				elseif description_mode == "unparseable" then
					return "Maximum Toughness"
				end

                return tostring(trait_values[definition.source_id]) .. "% primary"
            end,
        }
        TestMasterItems = {
            get_item = function(trait_id)
                return TestItems.perk_item_by_id(trait_id)
            end,
			get_item_instance = function(gear, gear_id)
				item_instance_resolve_count = (item_instance_resolve_count or 0) + 1
				return gear and gear.item
			end,
            get_store_item_instance = function(description)
                return description.item
            end,
        }
        TestStoreNames = {
            by_archetype = {
                credit = {
                    psyker = "psyker_store",
                },
            },
        }

        function require(path)
            if path == "scripts/utilities/items" then
                return TestItems
            elseif path == "scripts/backend/master_items" then
                return TestMasterItems
            elseif path == "scripts/foundation/utilities/promise" then
                return TestPromise
            elseif path == "scripts/settings/backend/store_names" then
                return TestStoreNames
            elseif path == "scripts/settings/buff/buff_templates" then
                return TestBuffTemplates
            elseif path == "scripts/ui/views/main_menu_view/main_menu_view_settings" then
                -- Simulate a future Darktide release increasing the operative
                -- capacity. BetterInventory must grow its stable DMF row pool
                -- from the authoritative game setting without a code change.
                return {max_num_characters = 12}
            elseif path == "scripts/mods/BetterInventory/BetterInventory_curio_values" then
                return TestCurioValues
            end

            error("Unexpected require: " .. tostring(path))
        end

        TestModLoader = {
            io_dofile = function(self, path)
                if string.find(path, "BetterInventory_curio_domains", 1, true) then
                    return TestCurioDomains
                elseif string.find(path, "BetterInventory_curio_profiles", 1, true) then
                    return TestCurioProfiles
                elseif string.find(path, "BetterInventory_curio_ledger", 1, true) then
                    return TestCurioLedger
                elseif string.find(path, "BetterInventory_curio_store", 1, true) then
                    return TestCurioStore
                elseif string.find(path, "BetterInventory_curio_purchase", 1, true) then
                    return TestCurioPurchase
                end

                return TestCurioValues
            end,
        }
        function get_mod()
            return TestModLoader
        end

        Color = setmetatable({}, {
            __index = function()
                return function(alpha)
                    return {alpha or 255, 255, 255, 255}
                end
            end,
        })

        function Localize(localization_id)
            if localization_id == "loc_class_psyker_name" then
                return "Psyker"
			elseif localization_id == "loc_currency_name_credits" then
				return "Ordo Dockets"
            end

            return localization_id
        end

        Application = {
            time_since_launch = function()
                return 100
            end,
        }

        server_clock = 100000
        server_time_calls = 0
        backend_account_key = "default"
        main_menu_active = false
		game_mode_name_value = "hub"

        settings = {
            enable_automatic_curio_acquisition = true,
			automatic_curio_scan_operative_selection = false,
			automatic_curio_once_per_store_rotation = false,
			automatic_curio_rescan_on_store_refresh = false,
			automatic_curio_favorite_purchased_curios = false,
			automatic_curio_target_mode = "characters",
            automatic_curio_min_item_level = 410,
			automatic_curio_owned_target_per_stat = 3,
            automatic_curio_min_health = 21,
            automatic_curio_min_toughness = 17,
			automatic_curio_min_stamina = 3,
            automatic_curio_diagnostic_logging = false,
			automatic_curio_disable_no_eligible_notification = false,
            automatic_curio_buy_health = true,
            automatic_curio_buy_toughness = true,
            automatic_curio_buy_stamina = false,
            automatic_curio_buy_wounds = false,
            automatic_curio_class_psyker = true,
			curio_health_color_r = 101,
			curio_health_color_g = 202,
			curio_health_color_b = 77,
			curio_toughness_color_r = 50,
			curio_toughness_color_g = 210,
			curio_toughness_color_b = 100,
        }
		setting_set_counts = {}
		character_options_refresh_calls = 0
        test_mod = {
            get = function(self, setting_id)
                return settings[setting_id]
            end,
			set = function(self, setting_id, value)
				setting_set_counts[setting_id] = (setting_set_counts[setting_id] or 0) + 1
				settings[setting_id] = value
			end,
			get_readable_name = function()
				return "Better Inventory"
			end,
            localize = function(self, localization_id)
				if localization_id == "automatic_curio_currency_spent_label" then
					return "Spent:"
				elseif localization_id == "automatic_curio_character_slot_placeholder" then
					return "Character"
				elseif localization_id == "automatic_curio_character_slot_unavailable" then
					return "(not currently found)"
				end

                return localization_id
            end,
            info = function(self, message)
                last_log = message
				table.insert(captured_logs, message)
            end,
        }

        target_profile = {
            character_id = "target-psyker",
            name = "Research Psyker",
            archetype = {
                name = "psyker",
                archetype_name = "loc_class_psyker_name",
            },
        }
        health_item = {
            item_type = "GADGET",
            level = 410,
            traits = {
                {
                    id = "health_trait",
                    rarity = 4,
                    value = 1,
                },
            },
        }
		profile_gear = {}
        test_offer = {
            offerId = "offer-health-410",
            state = "active",
            sku = {
                category = "item_instance",
            },
            description = {
                gear_id = "offered-gear-health",
                item = health_item,
            },
            price = {
                amount = {
                    amount = 25000,
                    type = "credits",
                },
            },
        }
        test_storefront = {
            data = {
                personal = {test_offer},
            },
        }
		revalidated_offer = {
			offerId = "offer-health-410",
			state = "active",
			sku = {
				category = "item_instance",
			},
			description = {
				-- Storefront decoration can assign a different per-fetch gear ID
				-- even though offerId remains the backend transaction identity.
				gear_id = "refetched-gear-health",
				item = health_item,
			},
			price = {
				amount = {
					amount = 25000,
					type = "credits",
				},
			},
		}
		revalidated_storefront = {
			data = {
				personal = {revalidated_offer},
			},
		}

        purchase_count = 0
        purchase_pending = false
        pending_purchase_promise = nil
		profile_fetch_pending = false
		pending_profile_promise = nil
		wallet_hook = nil
		wallet_balance = 100000
        fetched_store_count = 0
        storefront_hook = nil
        requested_wallet_character = nil
		wallet_request_count = 0
        purchased_wallet_owner = nil
        captured_notification = nil
		captured_logs = {}
        Managers = {
            state = {
                game_mode = {
                    game_mode_name = function()
						return game_mode_name_value
                    end,
                },
            },
            player = {
                local_player = function()
                    if main_menu_active then
                        return nil
                    end

                    return {
                        character_id = function()
                            return "currently-selected-character"
                        end,
                    }
                end,
                local_player_safe = function()
                    if main_menu_active then
                        return nil
                    end

                    return {
                        character_id = function()
                            return "currently-selected-character"
                        end,
                    }
                end,
            },
            progression = {
                is_fetching_session_report = function()
                    return false
                end,
            },
            backend = {
                account_id = function()
                    return backend_account_key
                end,
                authenticated = function()
                    return true
                end,
                get_server_time = function()
					server_time_calls = server_time_calls + 1
                    return server_clock
                end,
                interfaces = {
                    store = {
                        psyker_store = function(self, time, character_id)
                            fetched_store_count = fetched_store_count + 1
                            assert(character_id == "target-psyker")

							if storefront_hook then
								return TestPromise.resolved(storefront_hook(fetched_store_count))
							end

							if fetched_store_count == 2 then
								return TestPromise.resolved(revalidated_storefront)
							end

                            return TestPromise.resolved(test_storefront)
                        end,
                    },
                    wallet = {
                        account_wallets = function()
                            return TestPromise.resolved({})
                        end,
                        character_wallets = function(self, character_id)
							wallet_request_count = wallet_request_count + 1
                            requested_wallet_character = character_id

							if wallet_hook then
								local hook = wallet_hook
								wallet_hook = nil
								hook()
							end

                            return TestPromise.resolved({
                                {
                                    owner = character_id,
                                    lastTransactionId = 7,
                                    balance = {
										amount = wallet_balance,
                                        type = "credits",
                                    },
                                },
                            })
                        end,
                    },
                },
            },
            data_service = {
                profiles = {
                    fetch_all_profiles = function()
                        if profile_fetch_pending then
                            pending_profile_promise = pending_profile_promise or TestPromise.pending()
                            return pending_profile_promise
                        end

                        return TestPromise.resolved({
                            profiles = {target_profile},
							gear = profile_gear,
                        })
                    end,
                },
                store = {
                    purchase_item_with_wallet = function(self, offer, wallet)
                        purchase_count = purchase_count + 1
                        purchased_wallet_owner = wallet.owner

						if purchase_hook then
							purchase_hook()
						end

						if purchase_pending then
							pending_purchase_promise = TestPromise.pending()
							return pending_purchase_promise
						end

						return TestPromise.resolved({items = {{uuid = "purchased-curio-uuid"}}})
                    end,
                    invalidate_wallets_cache = function()
                        wallet_cache_invalidated = true
                    end,
                },
            },
            ui = {
                view_active = function(self, view_name)
                    return main_menu_active and view_name == "main_menu_view"
                end,
            },
            event = {
                trigger = function(self, event_name, payload, secondary_payload)
                    if event_name == "event_add_notification_message" and payload == "custom" then
                        captured_notification = secondary_payload
                    end
                end,
            },
        }
        """
    )

    curio_values = lua.execute(
        CURIO_VALUES_PATH.read_text(encoding="utf-8"), name=str(CURIO_VALUES_PATH)
    )
    lua.globals().TestCurioValues = curio_values
    curio_domains = lua.execute(
        CURIO_DOMAINS_PATH.read_text(encoding="utf-8"), name=str(CURIO_DOMAINS_PATH)
    )
    lua.globals().TestCurioDomains = curio_domains
    curio_profiles = lua.execute(
        CURIO_PROFILES_PATH.read_text(encoding="utf-8"), name=str(CURIO_PROFILES_PATH)
    )
    lua.globals().TestCurioProfiles = curio_profiles
    curio_ledger = lua.execute(
        CURIO_LEDGER_PATH.read_text(encoding="utf-8"), name=str(CURIO_LEDGER_PATH)
    )
    lua.globals().TestCurioLedger = curio_ledger
    curio_store = lua.execute(
        CURIO_STORE_PATH.read_text(encoding="utf-8"), name=str(CURIO_STORE_PATH)
    )
    lua.globals().TestCurioStore = curio_store
    curio_purchase = lua.execute(
        CURIO_PURCHASE_PATH.read_text(encoding="utf-8"), name=str(CURIO_PURCHASE_PATH)
    )
    lua.globals().TestCurioPurchase = curio_purchase
    module = lua.execute(MODULE_PATH.read_text(encoding="utf-8"), name=str(MODULE_PATH))
    globals_ = lua.globals()
    favorite_integration = lua.execute(
        r"""
        favorite_purchase_calls = {}
        return {
            favorite_purchase_items = function(mod, items, setting_id)
                if mod:get(setting_id) == true then
                    table.insert(favorite_purchase_calls, {
                        gear_id = items and items[1] and items[1].uuid,
                        setting_id = setting_id,
                    })
                end
            end,
        }
        """
    )
    module.set_favorite_integration(favorite_integration)

    assert (
        curio_values._test.buff_value("gadget_innate_health_increase", 0.69) == 19
    )
    assert (
        curio_values._test.buff_value("gadget_innate_health_increase", 0.75) == 20
    )
    assert (
        curio_values._test.buff_value("gadget_innate_toughness_increase", 0.72)
        == 15
    )

    candidate = module._test.normalized_offer(
        globals_.test_mod, globals_.target_profile, globals_.test_offer
    )
    assert candidate is not None
    assert candidate.character_id == "target-psyker"
    assert candidate.item_level == 410
    assert candidate.primary_trait == "gadget_innate_health_increase"
    assert candidate.primary_value == 21
    assert candidate.character_name == "Research Psyker"
    assert candidate.class_name == "Psyker"

    # Unknown future archetypes are included in class mode until BetterInventory
    # gains a dedicated checkbox instead of being silently excluded by a
    # hard-coded class list.
    future_profile = lua.table_from(
        {
            "character_id": "future-character",
            "name": "Future Operative",
            "archetype": lua.table_from(
                {"name": "future_class", "archetype_name": "loc_future_class"}
            ),
        }
    )
    assert module._test.class_is_enabled(globals_.test_mod, future_profile) is True

    # A confirmed empty backend result cannot populate character targeting.
    # It falls back to Classes, while the unconfirmed empty cache used during
    # initial discovery does not mutate the new Characters default.
    assert globals_.settings.automatic_curio_target_mode == "characters"
    module._test.cache_profiles(globals_.test_mod, lua.table_from([]))
    assert globals_.settings.automatic_curio_target_mode == "classes"

    # Character mode uses the stable backend ID, not display name or class.
    globals_.settings.automatic_curio_target_mode = "characters"
    assert module._test.profile_is_enabled(
        globals_.test_mod, globals_.target_profile
    ) is True
    module.set_character_enabled(
        globals_.test_mod, "target-psyker", False
    )
    assert module._test.profile_is_enabled(
        globals_.test_mod, globals_.target_profile
    ) is False
    module.set_character_enabled(
        globals_.test_mod, "target-psyker", True
    )
    assert globals_.settings.automatic_curio_character_selection is None
    globals_.settings.automatic_curio_target_mode = "classes"

    # Rich-text colour parameters from Enhanced Descriptions must not replace
    # the visible Curio roll during parsing or exclude an otherwise valid offer.
    globals_.description_mode = "rich"
    rich_candidate = module._test.normalized_offer(
        globals_.test_mod, globals_.target_profile, globals_.test_offer
    )
    assert rich_candidate is not None
    assert rich_candidate.primary_value == 21

    # Store payloads carry a 0..1 interpolation scalar, not a display percent.
    # A 0.75 Health roll maps through the vanilla 15..21% buff range to 20%.
    globals_.settings.automatic_curio_min_health = 18
    globals_.health_item.traits[1].value = 0.75
    interpolated_candidate = module._test.normalized_offer(
        globals_.test_mod, globals_.target_profile, globals_.test_offer
    )
    assert interpolated_candidate is not None
    assert interpolated_candidate.primary_value == 20
    globals_.settings.automatic_curio_min_health = 21
    globals_.health_item.traits[1].value = 1

    # Item level and primary roll are independent inclusive minimums. Meeting
    # the level threshold must not allow an under-threshold Health roll.
    globals_.trait_values.health_trait = 20
    globals_.health_item.traits[1].value = 0.75
    assert (
        module._test.normalized_offer(
            globals_.test_mod, globals_.target_profile, globals_.test_offer
        )
        is None
    )
    globals_.trait_values.health_trait = 21
    globals_.health_item.traits[1].value = 1

    # Revalidation must compare backend-stable transaction/filter fields. Storefront
    # decoration fields may legitimately change between two immediate fetches.
    rich_candidate.gear_id = "different-decoration-id"
    assert module._test.same_candidate(candidate, rich_candidate)
    rich_candidate.price = candidate.price + 1
    assert not module._test.same_candidate(candidate, rich_candidate)

    globals_.health_item.traits[1].id = "toughness_trait"
    globals_.health_item.traits[1].value = 1
    rich_toughness_candidate = module._test.normalized_offer(
        globals_.test_mod, globals_.target_profile, globals_.test_offer
    )
    assert rich_toughness_candidate is not None
    assert rich_toughness_candidate.primary_trait == "gadget_innate_toughness_increase"
    assert rich_toughness_candidate.primary_value == 17
    globals_.trait_values.toughness_trait = 16
    globals_.health_item.traits[1].value = 0.8
    assert (
        module._test.normalized_offer(
            globals_.test_mod, globals_.target_profile, globals_.test_offer
        )
        is None
    )
    globals_.trait_values.toughness_trait = 17
    globals_.health_item.traits[1].value = 1
    globals_.health_item.traits[1].id = "health_trait"

    # Stamina has its own inclusive primary-roll floor. The default +3 filter
    # excludes +2 Curios even when their item level passes the general floor.
    globals_.settings.automatic_curio_buy_stamina = True
    globals_.health_item.traits[1].id = "stamina_trait"
    globals_.health_item.traits[1].value = 0.5
    assert (
        module._test.normalized_offer(
            globals_.test_mod, globals_.target_profile, globals_.test_offer
        )
        is None
    )
    globals_.health_item.traits[1].value = 1
    stamina_candidate = module._test.normalized_offer(
        globals_.test_mod, globals_.target_profile, globals_.test_offer
    )
    assert stamina_candidate is not None
    assert stamina_candidate.primary_value == 3
    globals_.settings.automatic_curio_buy_stamina = False
    globals_.health_item.traits[1].id = "health_trait"

    # The ownership rule retains only the best N levels for each operative and
    # primary stat. Equal candidates stop once N qualifying Curios are owned,
    # while strict upgrades advance the bounded set until all three reach 430.
    globals_.profile_gear = lua.execute(
        r"""
        local gear = {}

        for index = 1, 3 do
            local gear_id = "owned-health-" .. tostring(index)
            gear[gear_id] = {
                uuid = gear_id,
                characterId = "target-psyker",
                item = {
                    item_type = "GADGET",
                    level = 410,
                    traits = {{id = "health_trait", value = 1}},
                },
            }
        end

        return gear
        """
    )
    owned_policy = curio_store._test.owned_curio_policy(
        globals_.test_mod, globals_.profile_gear
    )
    owned_candidate = lua.table_from(
        {
            "character_id": "target-psyker",
            "item_level": 410,
            "primary_trait": "gadget_innate_health_increase",
        }
    )
    assert not curio_store._test.candidate_improves_owned(
        owned_candidate, owned_policy
    )
    owned_candidate.item_level = 420
    assert curio_store._test.candidate_improves_owned(owned_candidate, owned_policy)
    curio_store._test.record_owned_candidate(owned_candidate, owned_policy)
    owned_candidate.item_level = 430
    assert curio_store._test.candidate_improves_owned(owned_candidate, owned_policy)
    curio_store._test.record_owned_candidate(owned_candidate, owned_policy)
    owned_candidate.item_level = 420
    assert curio_store._test.candidate_improves_owned(owned_candidate, owned_policy)
    curio_store._test.record_owned_candidate(owned_candidate, owned_policy)
    assert not curio_store._test.candidate_improves_owned(
        owned_candidate, owned_policy
    )
    owned_candidate.item_level = 430
    assert curio_store._test.candidate_improves_owned(owned_candidate, owned_policy)
    curio_store._test.record_owned_candidate(owned_candidate, owned_policy)
    assert curio_store._test.candidate_improves_owned(owned_candidate, owned_policy)
    curio_store._test.record_owned_candidate(owned_candidate, owned_policy)
    assert not curio_store._test.candidate_improves_owned(
        owned_candidate, owned_policy
    )

    owned_candidate.character_id = "another-operative"
    assert curio_store._test.candidate_improves_owned(owned_candidate, owned_policy)
    owned_candidate.character_id = "target-psyker"
    owned_candidate.primary_trait = "gadget_innate_toughness_increase"
    assert curio_store._test.candidate_improves_owned(owned_candidate, owned_policy)

    # Three under-threshold Toughness rolls do not fill the qualifying target.
    under_roll_gear = lua.execute(
        r"""
        local gear = {}

        for index = 1, 3 do
            local gear_id = "owned-toughness-low-" .. tostring(index)
            gear[gear_id] = {
                uuid = gear_id,
                characterId = "target-psyker",
                item = {
                    item_type = "GADGET",
                    level = 430,
                    traits = {{id = "toughness_trait", value = 0.8}},
                },
            }
        end

        return gear
        """
    )
    under_roll_policy = curio_store._test.owned_curio_policy(
        globals_.test_mod, under_roll_gear
    )
    owned_candidate.item_level = 410
    assert curio_store._test.candidate_improves_owned(
        owned_candidate, under_roll_policy
    )

    # The top-N insertion path stays bounded without sorting or allocating a
    # comparator per Curio. Production scans resolve only selected operatives'
    # gear instead of materializing every account item.
    assert "table.sort(levels" not in CURIO_STORE_PATH.read_text(encoding="utf-8")
    filtered_gear = lua.execute(
        r"""
        local gear = {}

        for index = 1, 3 do
            local gear_id = "selected-health-" .. tostring(index)
            gear[gear_id] = {
                uuid = gear_id,
                characterId = "target-psyker",
                item = {
                    item_type = "GADGET",
                    level = 410 + index * 10,
                    traits = {{id = "health_trait", value = 1}},
                },
            }
        end

        for index = 1, 50 do
            local gear_id = "unselected-item-" .. tostring(index)
            gear[gear_id] = {
                uuid = gear_id,
                characterId = "another-operative",
                item = {item_type = "WEAPON_MELEE", level = 500},
            }
        end

        return gear
        """
    )
    globals_.item_instance_resolve_count = 0
    filtered_policy = curio_store._test.owned_curio_policy(
        globals_.test_mod,
        filtered_gear,
        lua.table_from([globals_.target_profile]),
    )
    assert globals_.item_instance_resolve_count == 3
    filtered_levels = filtered_policy.levels["target-psyker"][
        "gadget_innate_health_increase"
    ]
    assert [filtered_levels[index] for index in range(1, 4)] == [440, 430, 420]

    # Policies are scan-local: after callers drop them, the module retains no
    # strong references that could grow across store rotations.
    retained_policy_count = lua.eval(
        r"""
        function(store, mod, gear)
            local references = setmetatable({}, {__mode = "v"})

            for index = 1, 64 do
                references[index] = store._test.owned_curio_policy(mod, gear)
            end

            collectgarbage("collect")
            local retained = 0

            for _ in pairs(references) do
                retained = retained + 1
            end

            return retained
        end
        """
    )(curio_store, globals_.test_mod, globals_.profile_gear)
    assert retained_policy_count == 0

    # Zero explicitly disables the ownership gate, even without a gear list.
    globals_.settings.automatic_curio_owned_target_per_stat = 0
    disabled_policy = curio_store._test.owned_curio_policy(globals_.test_mod, None)
    assert disabled_policy.target == 0
    assert curio_store._test.candidate_improves_owned(
        owned_candidate, disabled_policy
    )
    globals_.settings.automatic_curio_owned_target_per_stat = 3
    globals_.profile_gear = lua.table_from({})
    owned_candidate.primary_trait = "gadget_innate_health_increase"

    # Localized text is notification-only. Even if it cannot be parsed, the
    # stable trait ID remains eligible and the backend roll supplies the value.
    globals_.description_mode = "unparseable"
    fallback_candidate = module._test.normalized_offer(
        globals_.test_mod, globals_.target_profile, globals_.test_offer
    )
    assert fallback_candidate is not None
    assert fallback_candidate.primary_value == 21
    globals_.description_mode = None

    globals_.health_item.level = 409
    assert (
        module._test.normalized_offer(
            globals_.test_mod, globals_.target_profile, globals_.test_offer
        )
        is None
    )
    globals_.health_item.level = 410

    assert len(module._test.ARCHETYPE_SETTINGS) == 0  # Lua maps have no array length.
    archetype_count = lua.eval("function(values) local count = 0 for _ in pairs(values) do count = count + 1 end return count end")
    assert archetype_count(module._test.ARCHETYPE_SETTINGS) == 7

    # DMF validates the character rows as part of BetterInventory's static data
    # schema. The runtime hook only binds names and backend IDs; it must never add
    # or remove rows. Simulate the twelve rows generated from Darktide's reported
    # operative capacity before the first profile response.
    undiscovered_character_options = lua.execute(
        r"""
        local result = {
            settings = {{
                category = "Better Inventory",
                display_name = "automatic_curio_characters_group",
                widget_type = "group_header",
            }},
        }

        for index = 1, 12 do
            local setting_id = "automatic_curio_character_slot_" .. tostring(index)
            table.insert(result.settings, {
                category = "Better Inventory",
                display_name = setting_id,
                widget_type = "checkbox",
                get_function = function()
                    return settings[setting_id]
                end,
                on_activated = function(value)
                    settings[setting_id] = value
                    return true
                end,
            })
        end

        return result
        """
    )
    assert module.inject_character_options(
        globals_.test_mod, undiscovered_character_options
    ) is False
    module.set_character_options_refresh_callback(
        lua.eval(
            "function() character_options_refresh_calls = character_options_refresh_calls + 1 end"
        )
    )
    assert module.maximum_operative_slots(globals_.test_mod) == 12
    assert len(undiscovered_character_options.settings) == 13
    for slot_index in range(1, 13):
        discovery_slot = undiscovered_character_options.settings[slot_index + 1]
        assert discovery_slot.display_name == f"Character {slot_index}"
        assert discovery_slot._better_inventory_curio_character_available is False
        assert discovery_slot._better_inventory_curio_character_slot_index == slot_index
        assert discovery_slot.get_function() is False
    first_slot_write_count = globals_.setting_set_counts.automatic_curio_character_slot_1
    module.refresh_character_options(globals_.test_mod)
    assert globals_.setting_set_counts.automatic_curio_character_slot_1 == first_slot_write_count

    # Automatic discard owns the first Morningstar phase. The Curio Buyer must
    # remain dormant until that system is settled, then target the scanned
    # profile's wallet rather than the currently selected character's wallet.
    globals_.settings.automatic_curio_diagnostic_logging = True
    globals_.settings.automatic_curio_favorite_purchased_curios = True
    module.begin_morningstar_pass(globals_.test_mod)
    module.update(globals_.test_mod, 10, True)
    assert globals_.purchase_count == 0
    module.update(globals_.test_mod, 6, False)
    assert globals_.purchase_count == 1
    assert globals_.fetched_store_count == 2  # scan plus final revalidation
    assert globals_.requested_wallet_character == "target-psyker"
    assert globals_.purchased_wallet_owner == "target-psyker"
    assert len(globals_.favorite_purchase_calls) == 1
    assert globals_.favorite_purchase_calls[1].gear_id == "purchased-curio-uuid"
    assert globals_.favorite_purchase_calls[1].setting_id == "automatic_curio_favorite_purchased_curios"
    assert globals_.captured_notification.line_1 == "automatic_curio_purchased_title"
    assert (
        "{#color(101,202,77)}Research Psyker(Psyker): 21% automatic_curio_health (410){#reset()}"
        in globals_.captured_notification.line_2
    )
    assert globals_.captured_notification.line_3 == "\nSpent: 25 000 Ordo Dockets"
    assert lua.eval(
        "function(logs) for i = 1, #logs do if string.find(logs[i], 'non%-transactional field%(s%) changed') then return true end end return false end"
    )(globals_.captured_logs)
    # DMF 2.x retains this original generated template across view reopenings.
    # The asynchronous profile result must refresh it in place, including the
    # availability signal consumed by BetterInventory's dependency binder.
    assert undiscovered_character_options.settings[2].display_name == "Research Psyker(Psyker)"
    assert undiscovered_character_options.settings[2]._better_inventory_curio_character_available is True
    assert undiscovered_character_options.settings[2]._better_inventory_curio_character_id == "target-psyker"
    assert globals_.character_options_refresh_calls >= 1

    # A successful discovery is reused by both UIs. DMF keeps all twelve rows;
    # the matching slot binds to the stable backend ID and unused rows stay
    # disabled placeholders.
    known_profiles = module.known_profiles(globals_.test_mod)
    assert len(known_profiles) == 1
    assert known_profiles[1].character_id == "target-psyker"
    character_options = lua.execute(
        r"""
        local result = {
            settings = {{
                category = "Better Inventory",
                display_name = "automatic_curio_characters_group",
                widget_type = "group_header",
            }},
        }

        for index = 1, 12 do
            local setting_id = "automatic_curio_character_slot_" .. tostring(index)
            table.insert(result.settings, {
                category = "Better Inventory",
                display_name = setting_id,
                widget_type = "checkbox",
                get_function = function()
                    return settings[setting_id]
                end,
                on_activated = function(value)
                    settings[setting_id] = value
                    return true
                end,
            })
        end

        return result
        """
    )
    assert module.inject_character_options(
        globals_.test_mod, character_options
    ) is True
    assert len(character_options.settings) == 13
    character_option = character_options.settings[2]
    assert character_option.display_name != "automatic_curio_character_options_placeholder"
    assert character_option.display_name == "Research Psyker(Psyker)"
    assert character_option._better_inventory_curio_character_available is True
    assert character_option.get_function() is True
    globals_.settings.automatic_curio_character_slot_1 = False
    module.on_setting_changed(globals_.test_mod, "automatic_curio_character_slot_1")
    assert character_option.get_function() is False
    assert module.character_is_enabled(globals_.test_mod, "target-psyker") is False
    globals_.settings.automatic_curio_character_slot_1 = True
    module.on_setting_changed(globals_.test_mod, "automatic_curio_character_slot_1")
    assert character_option.get_function() is True
    assert module.character_is_enabled(globals_.test_mod, "target-psyker") is True
    assert character_options.settings[3].display_name == "Character 2"
    assert character_options.settings[3]._better_inventory_curio_character_available is False

    module.update(globals_.test_mod, 60, False)
    assert globals_.purchase_count == 1

    # The full purchase queue applies the owned-set gate before wallet or POST
    # work. Three equal qualifying Curios suppress an equal storefront offer.
    globals_.profile_gear = lua.execute(
        r"""
        local gear = {}
        for index = 1, 3 do
            local gear_id = "queue-owned-health-" .. tostring(index)
            gear[gear_id] = {
                uuid = gear_id,
                characterId = "target-psyker",
                item = {
                    item_type = "GADGET",
                    level = 410,
                    traits = {{id = "health_trait", value = 1}},
                },
            }
        end
        return gear
        """
    )
    wallet_requests_before_owned_gate = globals_.wallet_request_count
    module.begin_morningstar_pass(globals_.test_mod)
    module.update(globals_.test_mod, 6, False)
    assert globals_.purchase_count == 1
    assert globals_.wallet_request_count == wallet_requests_before_owned_gate
    assert lua.eval(
        "function(logs) for i = 1, #logs do if string.find(logs[i], 'does not improve') then return true end end return false end"
    )(globals_.captured_logs)
    globals_.profile_gear = lua.table_from({})

    # With every primary type disabled, a new Morningstar pass performs no
    # transaction and reports the requested no-match summary.
    globals_.settings.automatic_curio_buy_health = False
    globals_.settings.automatic_curio_buy_toughness = False
    globals_.settings.automatic_curio_diagnostic_logging = False
    logs_before_quiet_scan = len(globals_.captured_logs)
    module.begin_morningstar_pass(globals_.test_mod)
    module.update(globals_.test_mod, 6, False)
    assert globals_.purchase_count == 1
    assert globals_.captured_notification.line_1 == "automatic_curio_none_title"
    assert len(globals_.captured_logs) == logs_before_quiet_scan

    # Suppressing the no-match message does not affect the scan or purchases.
    globals_.settings.automatic_curio_disable_no_eligible_notification = True
    globals_.captured_notification = None
    module.begin_morningstar_pass(globals_.test_mod)
    module.update(globals_.test_mod, 6, False)
    assert globals_.purchase_count == 1
    assert globals_.captured_notification is None
    globals_.settings.automatic_curio_disable_no_eligible_notification = False

    # A purchase already sent to the backend can still finish after the user
    # disables the buyer. It must be reported, while cancellation prevents any
    # further transaction in that stale pass.
    globals_.settings.automatic_curio_buy_health = True
    globals_.settings.enable_automatic_curio_acquisition = True
    globals_.buyer_module = module
    lua.execute(
        """
        purchase_hook = function()
            purchase_hook = nil
            settings.enable_automatic_curio_acquisition = false
            buyer_module.on_setting_changed(test_mod, "enable_automatic_curio_acquisition")
        end
        """
    )
    module.begin_morningstar_pass(globals_.test_mod)
    module.update(globals_.test_mod, 6, False)
    assert globals_.purchase_count == 2
    assert globals_.captured_notification.line_1 == "automatic_curio_purchased_title"
    assert "Research Psyker(Psyker): 21% automatic_curio_health (410)" in globals_.captured_notification.line_2

    # A matching Curio remains worth reporting when its target wallet cannot
    # cover the price. This is an eligible-but-unaffordable result, not a no-match.
    globals_.settings.enable_automatic_curio_acquisition = True
    globals_.settings.automatic_curio_buy_toughness = True
    globals_.wallet_balance = 0
    globals_.health_item.traits[1].id = "toughness_trait"
    globals_.health_item.traits[1].value = 1
    module.begin_morningstar_pass(globals_.test_mod)
    module.update(globals_.test_mod, 6, False)
    assert globals_.purchase_count == 2
    assert globals_.captured_notification.line_1 == "automatic_curio_insufficient_title"
    assert (
        "{#color(50,210,100)}Research Psyker(Psyker): 17% automatic_curio_toughness (410){#reset()}"
        in globals_.captured_notification.line_2
    )
    assert globals_.captured_notification.line_3 is None

    # Slot identity follows character_id rather than display order or name.
    # Renaming preserves the explicit exclusion; deleting requires two complete
    # successful discoveries before reclaiming the slot; a recreated same-name
    # operative receives a new ID and therefore defaults enabled.
    module.set_character_enabled(globals_.test_mod, "target-psyker", False)
    renamed_profile = lua.table_from(
        {
            "character_id": "target-psyker",
            "name": "Renamed Psyker",
            "archetype": lua.table_from(
                {"name": "psyker", "archetype_name": "loc_class_psyker_name"}
            ),
        }
    )
    second_profile = lua.table_from(
        {
            "character_id": "second-psyker",
            "name": "Second Psyker",
            "archetype": lua.table_from(
                {"name": "psyker", "archetype_name": "loc_class_psyker_name"}
            ),
        }
    )
    module._test.cache_profiles(
        globals_.test_mod, lua.table_from([renamed_profile, second_profile])
    )
    slots = module.character_slots(globals_.test_mod)
    assert slots[1].character_id == "target-psyker"
    assert slots[1].character_name == "Renamed Psyker"
    assert module.character_is_enabled(globals_.test_mod, "target-psyker") is False
    assert slots[2].character_id == "second-psyker"

    module._test.cache_profiles(globals_.test_mod, lua.table_from([second_profile]))
    slots = module.character_slots(globals_.test_mod)
    assert slots[1].character_id == "target-psyker"
    assert slots[1].missing_confirmations == 1
    assert module.character_is_enabled(globals_.test_mod, "target-psyker") is False

    module._test.cache_profiles(globals_.test_mod, lua.table_from([second_profile]))
    slots = module.character_slots(globals_.test_mod)
    assert slots[1].character_id is None
    assert globals_.settings.automatic_curio_character_selection is None

    recreated_profile = lua.table_from(
        {
            "character_id": "recreated-psyker",
            "name": "Renamed Psyker",
            "archetype": lua.table_from(
                {"name": "psyker", "archetype_name": "loc_class_psyker_name"}
            ),
        }
    )
    module._test.cache_profiles(
        globals_.test_mod, lua.table_from([second_profile, recreated_profile])
    )
    slots = module.character_slots(globals_.test_mod)
    assert slots[1].character_id == "recreated-psyker"
    assert module.character_is_enabled(globals_.test_mod, "recreated-psyker") is True

    # v1.9.3 scheduling uses backend milliseconds and the next store boundary,
    # not a rolling 60-minute timer. The fallback is used by this fixture
    # because its synthetic storefront intentionally has no expiry metadata.
    assert module._test.fallback_rotation_boundary(100000) == 3600000
    assert module._test.sane_rotation_boundary(3600000, 100000) == 3600000
    assert module._test.sane_rotation_boundary(100000000, 100000) is None
    observed_storefront = lua.execute(
        "return {data = {currentRotationEnd = 1800000, catalog = {validTo = 1700000}, personal = {{price = {validTo = 1600000}}}}}"
    )
    assert module._test.observed_rotation_boundary(observed_storefront) == 1600000

    compatible, boundary, missing = module._test.rotation_boundary_compatible(
        None, 1600000, False
    )
    assert compatible is True
    assert boundary == 1600000
    assert missing is False
    compatible, _, _ = module._test.rotation_boundary_compatible(
        1600000, 1700000, False
    )
    assert compatible is False
    compatible, _, _ = module._test.rotation_boundary_compatible(
        1600000, None, False
    )
    assert compatible is False
    compatible, boundary, missing = module._test.rotation_boundary_compatible(
        None, None, False
    )
    assert compatible is True
    assert boundary is None
    assert missing is True

    # Pre-hotfix schema 1 boundaries may have been poisoned by a stale response.
    # Migrate account metadata but force one corrected scan; schema 2 boundaries
    # remain trusted after they were confirmed by the new synchronization rule.
    legacy_history = lua.execute(
        "return {schema_version = 1, accounts = {account = {next_refresh_at_ms = 3600000, last_successful_scan_at_ms = 100000, last_used_at_ms = 100000, last_context = 'morningstar'}}}"
    )
    migrated_history = module._test.sanitize_rotation_history(legacy_history, 100000)
    assert migrated_history.schema_version == 3
    assert migrated_history.accounts.account.next_refresh_at_ms is None
    assert migrated_history.accounts.account.last_successful_scan_at_ms is None
    assert migrated_history.accounts.account.last_used_at_ms == 100000
    assert migrated_history.accounts.account.last_context == "morningstar"
    current_history = lua.execute(
        "return {schema_version = 2, accounts = {account = {next_refresh_at_ms = 3600000, last_successful_scan_at_ms = 100000}}}"
    )
    sanitized_current = module._test.sanitize_rotation_history(current_history, 100000)
    assert sanitized_current.accounts.account.next_refresh_at_ms == 3600000
    assert sanitized_current.accounts.account.last_successful_scan_at_ms == 100000

    pending_item = lua.table_from(
        {
            "character_id": "legacy-character",
            "character_name": "Legacy Psyker",
            "class_name": "Psyker",
            "item_level": 410,
            "label_id": "automatic_curio_health",
            "primary_value": 21,
            "price": 100,
            "unit": "%",
            "currency": "credits",
        }
    )
    legacy_report = lua.table_from(
        {
            "account_key": "account",
            "context": "operative_selection",
            "created_at_ms": 100000,
            "report_id": "legacy-report",
            "purchased": lua.table_from([pending_item]),
            "insufficient": lua.table_from([]),
            "spent": lua.table_from({"credits": 100, "marks": 0}),
        }
    )
    migrated_reports = module._test.sanitize_pending_reports(
        None, legacy_report
    )
    assert len(migrated_reports) == 1
    assert migrated_reports[1].report_id == "legacy-report"
    duplicate_reports = module._test.sanitize_pending_reports(
        lua.table_from([legacy_report, legacy_report]), None
    )
    assert len(duplicate_reports) == 1

    def set_storefront_boundary(boundary: int) -> None:
        globals_.test_storefront.data.currentRotationEnd = boundary
        globals_.test_storefront.data.catalog = lua.table_from({"validTo": boundary})
        globals_.test_offer.price.validTo = boundary
        globals_.revalidated_storefront.data.currentRotationEnd = boundary
        globals_.revalidated_storefront.data.catalog = lua.table_from(
            {"validTo": boundary}
        )
        globals_.revalidated_offer.price.validTo = boundary

    globals_.settings.enable_automatic_curio_acquisition = True
    globals_.settings.automatic_curio_once_per_store_rotation = True
    globals_.settings.automatic_curio_scan_operative_selection = False
    globals_.settings.automatic_curio_rescan_on_store_refresh = False
    globals_.settings.automatic_curio_buy_health = True
    globals_.settings.automatic_curio_buy_toughness = False
    globals_.wallet_balance = 100000
    globals_.health_item.traits[1].id = "health_trait"
    globals_.health_item.traits[1].value = 21
    globals_.test_offer.offerId = "scheduled-offer-health"
    globals_.revalidated_offer.offerId = "scheduled-offer-health"
    globals_.server_clock = 100000
    purchases_before_rotation_test = globals_.purchase_count
    module.begin_morningstar_pass(globals_.test_mod)
    module.update(globals_.test_mod, 6, False)
    assert globals_.purchase_count == purchases_before_rotation_test + 1

    rotation_history = globals_.settings["_automatic_curio_rotation_history"]
    first_next_refresh = rotation_history.accounts["default"].next_refresh_at_ms
    assert first_next_refresh == 3600000
    assert module._test.rotation_gate_status(globals_.test_mod) is False

    # A second context entry during the same rotation must not buy again.
    module.begin_morningstar_pass(globals_.test_mod)
    module.update(globals_.test_mod, 6, False)
    assert globals_.purchase_count == purchases_before_rotation_test + 1

    # One second past reset grace is a new rotation even though less than an
    # hour elapsed since a hypothetical 17:59 scan.
    set_storefront_boundary(first_next_refresh + 3600000)
    globals_.server_clock = first_next_refresh + 5000
    module.begin_morningstar_pass(globals_.test_mod)
    module.update(globals_.test_mod, 6, False)
    assert globals_.purchase_count == purchases_before_rotation_test + 2

    # Operative Selection can be active without a local Morningstar player.
    globals_.main_menu_active = True
    globals_.settings.automatic_curio_scan_operative_selection = True
    rotation_history = globals_.settings["_automatic_curio_rotation_history"]
    second_next_refresh = rotation_history.accounts["default"].next_refresh_at_ms
    module.enter_operative_selection(globals_.test_mod)
    module.update(globals_.test_mod, 1, False)
    assert globals_.purchase_count == purchases_before_rotation_test + 2

    set_storefront_boundary(second_next_refresh + 3600000)
    globals_.server_clock = second_next_refresh + 5000
    module.leave_operative_selection()
    module.enter_operative_selection(globals_.test_mod)
    module.update(globals_.test_mod, 1, False)
    assert globals_.purchase_count == purchases_before_rotation_test + 3
    assert len(globals_.settings["_automatic_curio_rotation_history"].accounts["default"].pending_reports) == 1

    # Idle refresh watcher arms once at the boundary, then performs one pass
    # on the following scheduler tick. It must not loop every frame.
    globals_.settings.automatic_curio_rescan_on_store_refresh = True
    rotation_history = globals_.settings["_automatic_curio_rotation_history"]
    third_next_refresh = rotation_history.accounts["default"].next_refresh_at_ms
    set_storefront_boundary(third_next_refresh + 3600000)
    globals_.server_clock = third_next_refresh + 5000
    purchases_before_idle_refresh = globals_.purchase_count
    module.update(globals_.test_mod, 1, False)
    assert globals_.purchase_count == purchases_before_idle_refresh
    module.update(globals_.test_mod, 1, False)
    assert globals_.purchase_count == purchases_before_idle_refresh + 1

    # A completed context does not repeat rotation/history/report maintenance
    # every frame. The one-second boundary remains the scheduler wake-up.
    globals_.server_time_calls = 0
    for _ in range(5):
        module.update(globals_.test_mod, 0.1, False)
    assert globals_.server_time_calls == 0
    module.update(globals_.test_mod, 0.5, False)
    assert globals_.server_time_calls > 0

    module.update(globals_.test_mod, 1, False)
    assert globals_.purchase_count == purchases_before_idle_refresh + 1
    module.cancel()

    # Operative Selection keeps a bounded account-scoped report as a durable
    # fallback. Its persisted dispatch status survives module/VM recreation and
    # prevents duplicate white-text notifications during loading.
    pending_history = globals_.settings["_automatic_curio_rotation_history"]
    pending_report = pending_history.accounts["default"].pending_reports[1]
    assert pending_report is not None
    assert pending_report.context == "operative_selection"
    assert pending_report.notification_dispatched is True
    assert len(pending_report.purchased) == 1
    assert pending_report.purchased[1].character_id == "target-psyker"

    globals_.captured_notification = None
    globals_.main_menu_active = False
    globals_.backend_account_key = "other-account"
    module.begin_morningstar_pass(globals_.test_mod)
    module.update(globals_.test_mod, 0, False)
    assert globals_.captured_notification is None
    assert len(globals_.settings["_automatic_curio_rotation_history"].accounts["default"].pending_reports) == 2
    globals_.backend_account_key = "default"
    module.update(globals_.test_mod, 0, False)
    assert globals_.captured_notification is None
    assert len(globals_.settings["_automatic_curio_rotation_history"].accounts["default"].pending_reports) == 1
    module.update(globals_.test_mod, 0, False)
    assert globals_.captured_notification is None
    assert len(globals_.settings["_automatic_curio_rotation_history"].accounts["default"].pending_reports) == 0

    # A report whose immediate notification failed must still be delivered.
    # Changing the ID models a distinct persisted fallback without coupling the
    # test to module reloading.
    pending_report.report_id = "prior-session-operative-report"
    pending_report.notification_dispatched = False
    pending_history.accounts["default"].pending_reports = lua.table_from([pending_report])
    globals_.settings["_automatic_curio_rotation_history"] = pending_history
    globals_.backend_account_key = "other-account"
    module.cancel()
    module.begin_morningstar_pass(globals_.test_mod)
    module.update(globals_.test_mod, 0, False)
    assert globals_.captured_notification is None
    globals_.backend_account_key = "default"
    module.update(globals_.test_mod, 0, False)
    assert globals_.captured_notification.line_1 == "automatic_curio_purchased_title"
    assert "Research Psyker(Psyker): 21% automatic_curio_health (410)" in globals_.captured_notification.line_2
    assert len(globals_.settings["_automatic_curio_rotation_history"].accounts["default"].pending_reports) == 0
    module.cancel()

    # Crossing a predicted boundary does not prove that the backend has
    # published the new storefront. An expired response must not be evaluated
    # or allowed to consume the following rotation through the hourly fallback.
    globals_.settings.automatic_curio_rescan_on_store_refresh = True
    globals_.settings.automatic_curio_once_per_store_rotation = True
    globals_.settings.automatic_curio_buy_health = True
    globals_.settings.automatic_curio_buy_toughness = False
    globals_.main_menu_active = False
    globals_.test_offer.offerId = "stale-boundary-health"
    globals_.revalidated_offer.offerId = "stale-boundary-health"
    globals_.captured_notification = None
    stale_boundary = globals_.settings["_automatic_curio_rotation_history"].accounts[
        "default"
    ].next_refresh_at_ms
    globals_.server_clock = stale_boundary + 5000
    lua.execute(
        """
        storefront_is_stale = true
        fresh_store_fetch_count = 0
        stale_storefront = {
            data = {
                currentRotationEnd = %d,
                catalog = {validTo = %d},
                personal = {test_offer},
            },
        }
        storefront_hook = function()
            if storefront_is_stale then
                return stale_storefront
            end

            fresh_store_fetch_count = fresh_store_fetch_count + 1
            return fresh_store_fetch_count %% 2 == 1 and test_storefront or revalidated_storefront
        end
        """
        % (stale_boundary, stale_boundary)
    )
    purchases_before_stale_boundary = globals_.purchase_count
    module.begin_morningstar_pass(globals_.test_mod)
    module.update(globals_.test_mod, 6, False)
    assert globals_.purchase_count == purchases_before_stale_boundary
    assert globals_.captured_notification is None
    assert (
        globals_.settings["_automatic_curio_rotation_history"].accounts[
            "default"
        ].next_refresh_at_ms
        == stale_boundary
    )

    # Once the backend advertises a boundary beyond the consumed rotation, the
    # bounded retry may evaluate and purchase the newly published offer.
    fresh_boundary = stale_boundary + 3600000
    set_storefront_boundary(fresh_boundary)
    globals_.storefront_is_stale = False
    module.update(globals_.test_mod, 5, False)
    assert globals_.purchase_count == purchases_before_stale_boundary + 1
    assert (
        globals_.settings["_automatic_curio_rotation_history"].accounts[
            "default"
        ].next_refresh_at_ms
        == fresh_boundary
    )
    globals_.storefront_hook = None
    module.cancel()

    # If context leaves after scan/revalidation but before first purchase POST,
    # rotation remains retryable. Re-entering same rotation may purchase once.
    globals_.main_menu_active = False
    globals_.settings.automatic_curio_rescan_on_store_refresh = False
    globals_.settings.automatic_curio_buy_health = True
    globals_.settings.automatic_curio_buy_toughness = False
    globals_.wallet_balance = 100000
    globals_.health_item.traits[1].id = "health_trait"
    globals_.health_item.traits[1].value = 21
    globals_.test_offer.offerId = "interrupted-offer-health"
    globals_.revalidated_offer.offerId = "interrupted-offer-health"
    rotation_history = globals_.settings["_automatic_curio_rotation_history"]
    committed_before_interrupted = rotation_history.accounts["default"].next_refresh_at_ms
    set_storefront_boundary(committed_before_interrupted + 3600000)
    globals_.server_clock = committed_before_interrupted + 5000
    purchases_before_interrupted = globals_.purchase_count
    globals_.buyer_module = module
    lua.execute(
        "wallet_hook = function() buyer_module.cancel() end"
    )
    module.begin_morningstar_pass(globals_.test_mod)
    module.update(globals_.test_mod, 6, False)
    assert globals_.purchase_count == purchases_before_interrupted
    assert rotation_history.accounts["default"].next_refresh_at_ms == committed_before_interrupted

    module.begin_morningstar_pass(globals_.test_mod)
    module.update(globals_.test_mod, 6, False)
    assert globals_.purchase_count == purchases_before_interrupted + 1
    assert rotation_history.accounts["default"].next_refresh_at_ms > committed_before_interrupted
    module.cancel()

    # Read-only profile requests are owned by the current context. Leaving the
    # menu cancels a pending GET, clears its debug count, and invalidates late
    # callbacks without touching purchase POST ownership.
    globals_.main_menu_active = True
    globals_.settings.automatic_curio_scan_operative_selection = True
    globals_.profile_fetch_pending = True
    globals_.pending_profile_promise = None
    generation_before_pending = module.read_request_generation()
    module.enter_operative_selection(globals_.test_mod)
    module.update(globals_.test_mod, 1, False)
    assert globals_.pending_profile_promise is not None
    assert module.active_read_request_count() == 1
    assert module.read_request_generation() == generation_before_pending + 1
    module.update(globals_.test_mod, 0.5, False)
    assert module.oldest_read_request_age() >= 0.5

    pending_profile_promise = globals_.pending_profile_promise
    assert module.account_mutation_inflight() is False
    assert module.defer_for_account_operation(globals_.test_mod) is True
    assert module.active_read_request_count() == 0
    assert module.oldest_read_request_age() == 0
    assert pending_profile_promise._cancelled is True

    # A canceled promise cannot mutate the newly idle state if a backend test
    # double attempts to resolve it after cancellation.
    pending_profile_promise.resolve(
        pending_profile_promise,
        lua.table_from({"profiles": lua.table_from([])}),
    )
    assert module.active_read_request_count() == 0
    globals_.profile_fetch_pending = False

    # Once a Curio purchase POST has been dispatched, Auto Crafter must not
    # preempt it. Ownership becomes available immediately after settlement.
    module.cancel()
    globals_.main_menu_active = False
    globals_.settings.automatic_curio_scan_operative_selection = False
    globals_.settings.automatic_curio_once_per_store_rotation = False
    globals_.purchase_pending = True
    globals_.test_offer.offerId = "pending-purchase-health"
    globals_.revalidated_offer.offerId = "pending-purchase-health"
    module.begin_morningstar_pass(globals_.test_mod)
    module.update(globals_.test_mod, 6, False)
    assert globals_.pending_purchase_promise is not None
    assert module.account_mutation_inflight() is True
    assert module.is_busy() is True
    deferred, defer_reason = module.defer_for_account_operation(globals_.test_mod)
    assert deferred is False
    assert "purchase request in flight" in defer_reason
    globals_.pending_purchase_promise.resolve(
        globals_.pending_purchase_promise, lua.table_from({"items": lua.table_from([])})
    )
    assert module.account_mutation_inflight() is False
    globals_.purchase_pending = False
    globals_.pending_purchase_promise = None

    # Disabled, settled buyer becomes fully dormant. Enabling remains enough
    # to wake it without relying on a prior lifecycle callback.
    globals_.settings.enable_automatic_curio_acquisition = False
    module.on_setting_changed(globals_.test_mod, "enable_automatic_curio_acquisition")
    assert module.needs_update(globals_.test_mod) is False
    globals_.settings.enable_automatic_curio_acquisition = True
    globals_.game_mode_name_value = "mission"
    assert module.needs_update(globals_.test_mod) is False
    globals_.game_mode_name_value = "hub"
    assert module.needs_update(globals_.test_mod) is True

    print("BetterInventory automatic Curio acquisition tests passed.")


if __name__ == "__main__":
    main()

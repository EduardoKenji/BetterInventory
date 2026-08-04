from pathlib import Path

from lupa import LuaRuntime


PROJECT_ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = (
    PROJECT_ROOT
    / "scripts"
    / "mods"
    / "BetterInventory"
    / "BetterInventory_curio_acquisition.lua"
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

        function TestPromise.resolved(value)
            return new_promise(value, nil)
        end

        function TestPromise.rejected(error_value)
            return new_promise(nil, error_value)
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
            health_trait = 17,
            toughness_trait = 17,
            stamina_trait = 3,
            wound_trait = 1,
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
            end

            error("Unexpected require: " .. tostring(path))
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

        settings = {
            enable_automatic_curio_acquisition = true,
            automatic_curio_min_item_level = 410,
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
        test_mod = {
            get = function(self, setting_id)
                return settings[setting_id]
            end,
            localize = function(self, localization_id)
				if localization_id == "automatic_curio_currency_spent_label" then
					return "Spent:"
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
                    value = 0.17,
                },
            },
        }
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
		wallet_balance = 100000
        fetched_store_count = 0
        requested_wallet_character = nil
        purchased_wallet_owner = nil
        captured_notification = nil
		captured_logs = {}
        Managers = {
            state = {
                game_mode = {
                    game_mode_name = function()
                        return "hub"
                    end,
                },
            },
            player = {
                local_player = function()
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
                authenticated = function()
                    return true
                end,
                get_server_time = function()
                    return 100000
                end,
                interfaces = {
                    store = {
                        psyker_store = function(self, time, character_id)
                            fetched_store_count = fetched_store_count + 1
                            assert(character_id == "target-psyker")

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
                            requested_wallet_character = character_id
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
                        return TestPromise.resolved({
                            profiles = {target_profile},
                            gear = {},
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

                        return TestPromise.resolved({items = {}})
                    end,
                    invalidate_wallets_cache = function()
                        wallet_cache_invalidated = true
                    end,
                },
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

    module = lua.execute(MODULE_PATH.read_text(encoding="utf-8"))
    globals_ = lua.globals()

    candidate = module._test.normalized_offer(
        globals_.test_mod, globals_.target_profile, globals_.test_offer
    )
    assert candidate is not None
    assert candidate.character_id == "target-psyker"
    assert candidate.item_level == 410
    assert candidate.primary_trait == "gadget_innate_health_increase"
    assert candidate.primary_value == 17
    assert candidate.class_name == "Psyker"

    # Rich-text colour parameters from Enhanced Descriptions must not replace
    # the visible Curio roll during parsing or exclude an otherwise valid offer.
    globals_.description_mode = "rich"
    rich_candidate = module._test.normalized_offer(
        globals_.test_mod, globals_.target_profile, globals_.test_offer
    )
    assert rich_candidate is not None
    assert rich_candidate.primary_value == 17

    # Revalidation must compare backend-stable transaction/filter fields. Storefront
    # decoration fields may legitimately change between two immediate fetches.
    rich_candidate.gear_id = "different-decoration-id"
    assert module._test.same_candidate(candidate, rich_candidate)
    rich_candidate.price = candidate.price + 1
    assert not module._test.same_candidate(candidate, rich_candidate)

    globals_.health_item.traits[1].id = "toughness_trait"
    rich_toughness_candidate = module._test.normalized_offer(
        globals_.test_mod, globals_.target_profile, globals_.test_offer
    )
    assert rich_toughness_candidate is not None
    assert rich_toughness_candidate.primary_trait == "gadget_innate_toughness_increase"
    assert rich_toughness_candidate.primary_value == 17
    globals_.health_item.traits[1].id = "health_trait"

    # Localized text is notification-only. Even if it cannot be parsed, the
    # stable trait ID remains eligible and the backend roll supplies the value.
    globals_.description_mode = "unparseable"
    fallback_candidate = module._test.normalized_offer(
        globals_.test_mod, globals_.target_profile, globals_.test_offer
    )
    assert fallback_candidate is not None
    assert fallback_candidate.primary_value == 17
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

    # Automatic discard owns the first Morningstar phase. The Curio Buyer must
    # remain dormant until that system is settled, then target the scanned
    # profile's wallet rather than the currently selected character's wallet.
    module.begin_morningstar_pass(globals_.test_mod)
    module.update(globals_.test_mod, 10, True)
    assert globals_.purchase_count == 0
    module.update(globals_.test_mod, 6, False)
    assert globals_.purchase_count == 1
    assert globals_.fetched_store_count == 2  # scan plus final revalidation
    assert globals_.requested_wallet_character == "target-psyker"
    assert globals_.purchased_wallet_owner == "target-psyker"
    assert globals_.captured_notification.line_1 == "automatic_curio_purchased_title"
    assert (
        "{#color(101,202,77)}Psyker: 17% automatic_curio_health (410){#reset()}"
        in globals_.captured_notification.line_2
    )
    assert globals_.captured_notification.line_3 == "\nSpent: 25 000 Ordo Dockets"
    assert lua.eval(
        "function(logs) for i = 1, #logs do if string.find(logs[i], 'non%-transactional field%(s%) changed') then return true end end return false end"
    )(globals_.captured_logs)

    module.update(globals_.test_mod, 60, False)
    assert globals_.purchase_count == 1

    # With every primary type disabled, a new Morningstar pass performs no
    # transaction and reports the requested no-match summary.
    globals_.settings.automatic_curio_buy_health = False
    globals_.settings.automatic_curio_buy_toughness = False
    module.begin_morningstar_pass(globals_.test_mod)
    module.update(globals_.test_mod, 6, False)
    assert globals_.purchase_count == 1
    assert globals_.captured_notification.line_1 == "automatic_curio_none_title"

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
    assert "Psyker: 17% automatic_curio_health (410)" in globals_.captured_notification.line_2

    # A matching Curio remains worth reporting when its target wallet cannot
    # cover the price. This is an eligible-but-unaffordable result, not a no-match.
    globals_.settings.enable_automatic_curio_acquisition = True
    globals_.settings.automatic_curio_buy_toughness = True
    globals_.wallet_balance = 0
    globals_.health_item.traits[1].id = "toughness_trait"
    module.begin_morningstar_pass(globals_.test_mod)
    module.update(globals_.test_mod, 6, False)
    assert globals_.purchase_count == 2
    assert globals_.captured_notification.line_1 == "automatic_curio_insufficient_title"
    assert (
        "{#color(50,210,100)}Psyker: 17% automatic_curio_toughness (410){#reset()}"
        in globals_.captured_notification.line_2
    )
    assert globals_.captured_notification.line_3 is None

    print("BetterInventory automatic Curio acquisition tests passed.")


if __name__ == "__main__":
    main()

from pathlib import Path

from coverage_support import InstrumentedLuaRuntime as LuaRuntime


PROJECT_ROOT = Path(__file__).resolve().parents[1]
RUNTIME_ROOT = PROJECT_ROOT / "scripts" / "mods" / "BetterInventory"
BACKEND_PATH = RUNTIME_ROOT / "auto_crafter" / "darktide" / "backend.lua"
PLANNER_PATH = RUNTIME_ROOT / "auto_crafter" / "core" / "planner.lua"
PANEL_PATH = RUNTIME_ROOT / "auto_crafter" / "darktide" / "panel.lua"


def main() -> None:
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute(
        r'''
        local function promise(value, failure)
            return {
                value = value,
                failure = failure,
                next = function(self, callback)
                    if self.failure then
                        return self
                    end

                    local ok, result = pcall(callback, self.value)

                    if not ok then
                        return promise(nil, result)
                    end

                    if type(result) == "table" and type(result.next) == "function" then
                        return result
                    end

                    return promise(result)
                end,
                catch = function(self, callback)
                    if self.failure then
						local result = callback(self.failure)

						if type(result) == "table" and type(result.next) == "function" then
							return result
						end

						return promise(result)
                    end

                    return self
                end,
            }
        end

        local crowbar_template = {
            base_stats = {
                crowbar_p1_m1_dps_stat = {display_name = "loc_stats_display_damage_stat", is_stat_trait = true},
                crowbar_p1_m1_defence_stat = {display_name = "loc_stats_display_defense_stat", is_stat_trait = true},
                crowbar_p1_m1_armor_pierce_stat = {display_name = "loc_stats_display_ap_stat", is_stat_trait = true},
                crowbar_p1_m1_first_target_stat = {display_name = "loc_stats_display_first_target_stat", is_stat_trait = true},
                crowbar_p1_m1_mobility_stat = {display_name = "loc_stats_display_mobility_stat", is_stat_trait = true},
            },
        }
        local crowbar_item = {
            name = "content/items/weapons/player/melee/crowbar_p1_m1",
            display_name = "Crowbar",
            parent_pattern = "crowbar_p1",
            slots = {"slot_primary"},
            weapon_template = "crowbar_p1_m1",
            _weapon_template = crowbar_template,
        }
		local crowbar_alt_item = {
			name = "content/items/weapons/player/melee/crowbar_p1_m2",
			display_name = "Crowbar Mk II",
			parent_pattern = "crowbar_p1",
			slots = {"slot_primary"},
			weapon_template = "crowbar_p1_m2",
			_weapon_template = crowbar_template,
		}
		local crowbar_locked_item = {
			name = "content/items/weapons/player/melee/crowbar_p1_m3",
			display_name = "Crowbar Mk III",
			parent_pattern = "crowbar_p1",
			slots = {"slot_primary"},
			weapon_template = "crowbar_p1_m3",
			_weapon_template = crowbar_template,
		}
		local pistol_item = {
			name = "content/items/weapons/player/ranged/pistol_p1_m1",
			display_name = "Pistol Mk I",
			parent_pattern = "pistol_p1",
			slots = {"slot_secondary"},
			weapon_template = "pistol_p1_m1",
			_weapon_template = crowbar_template,
		}
		local pistol_alt_item = {
			name = "content/items/weapons/player/ranged/pistol_p1_m2",
			display_name = "Pistol Mk II",
			parent_pattern = "pistol_p1",
			slots = {"slot_secondary"},
			weapon_template = "pistol_p1_m2",
			_weapon_template = crowbar_template,
		}
		local cross_slot_item = {
			name = "invalid_cross_slot",
			display_name = "Invalid Ranged Crowbar",
			parent_pattern = "crowbar_p1",
			slots = {"slot_secondary"},
			weapon_template = "invalid_cross_slot",
		}
		local wrong_family_item = {
			name = "invalid_wrong_family",
			display_name = "Invalid Family",
			parent_pattern = "wrong_pattern",
			slots = {"slot_primary"},
			weapon_template = "invalid_wrong_family",
		}
		local missing_template_item = {
			name = "invalid_missing_template",
			display_name = "Invalid Template",
			parent_pattern = "crowbar_p1",
			slots = {"slot_primary"},
		}
		local function add_weapon_lore(item, family_loc_id, pattern_loc_id, mark_loc_id, sub_display_name)
			item.weapon_family_display_name = {loc_id = family_loc_id}
			item.weapon_pattern_display_name = {loc_id = pattern_loc_id}
			item.weapon_mark_display_name = {loc_id = mark_loc_id}
			item.sub_display_name = sub_display_name
		end
		add_weapon_lore(crowbar_item, "loc_crowbar", "loc_crowbar_pattern", "loc_crowbar_mk_1", "Pattern • Mk I")
		add_weapon_lore(crowbar_alt_item, "loc_crowbar", "loc_crowbar_pattern", "loc_crowbar_mk_2", "Pattern • Mk II")
		add_weapon_lore(crowbar_locked_item, "loc_crowbar", "loc_crowbar_pattern", "loc_crowbar_mk_3", "Pattern • Mk III")
		add_weapon_lore(pistol_item, "loc_pistol", "loc_pistol_pattern", "loc_pistol_mk_1", "Pattern • Mk I")
		add_weapon_lore(pistol_alt_item, "loc_pistol", "loc_pistol_pattern", "loc_pistol_mk_2", "Pattern • Mk II")
		add_weapon_lore(cross_slot_item, "loc_crowbar", "loc_crowbar_pattern", "loc_invalid_cross_slot", "Pattern • Invalid")
		add_weapon_lore(wrong_family_item, "loc_wrong_family", "loc_wrong_pattern", "loc_invalid_wrong_family", "Pattern • Invalid")
		TestMasterItems = {
			crowbar_master = crowbar_item,
			crowbar_master_alt = crowbar_alt_item,
			crowbar_master_locked = crowbar_locked_item,
			pistol_master = pistol_item,
			pistol_master_alt = pistol_alt_item,
			invalid_cross_slot = cross_slot_item,
			invalid_wrong_family = wrong_family_item,
			invalid_missing_template = missing_template_item,
		}
		TestFavoriteItems = {}
		TestExpertise = 300
		TestGear = {
			["gear-a"] = {uuid = "gear-a", rarity = 0, base_stats = {{name = "damage", value = 0.5}}},
			["gear-b"] = {uuid = "gear-b", rarity = 0, base_stats = {{name = "damage", value = 0.5}}},
		}
		TestMasteryPurchaseFails = false
		TestMasteryUnlocked = true
		TestMasteryRequiredLevel = 1
		TestPurchasedTraits = nil
		TestBatchUpgradeIds = {}
		TestPreviewCalls = 0
		TestWalletInvalidations = 0
		TestPurchaseAttempts = 0
		TestTransactionMismatchOnce = false
		local modules = {
            ["scripts/foundation/utilities/promise"] = {
				all = function(...)
					local results = {}

					for index, operation in ipairs({...}) do
						if operation.failure then
							return operation
						end

						results[index] = operation.value
					end

					return promise(results)
				end,
                resolved = function(value) return promise(value) end,
                rejected = function(value) return promise(nil, value) end,
            },
            ["scripts/utilities/items"] = {
				expertise_level = function() return tostring(TestExpertise), true end,
				max_expertise_level = function() return 500 end,
				preview_stats_change = function(_, _, stats)
					TestPreviewCalls = TestPreviewCalls + 1
					local result = {}

					for _, stat in ipairs(stats) do
						result[stat.display_name] = {
							value = stat.name == "crowbar_p1_m1_defence_stat" and 60 or 80,
						}
					end

					return result
				end,
				is_item_id_favorited = function(gear_id) return TestFavoriteItems[gear_id] == true end,
				set_item_id_as_favorite = function(gear_id, state) TestFavoriteItems[gear_id] = state end,
                weapon_card_display_name = function(item) return item.display_name end,
                weapon_card_sub_display_name = function(item) return item.sub_display_name or "n/a" end,
                trait_category = function() return "crowbar_traits" end,
                trait_description = function(item, rarity)
                    return string.format(item.trait_text, rarity)
                end,
            },
			["scripts/utilities/mastery"] = {
				is_mastery_unlocked = function()
					return TestMasteryUnlocked, TestMasteryRequiredLevel
				end,
			},
			["scripts/backend/master_items"] = {
				get_cached = function() return TestMasterItems end,
                get_item = function(name)
                    if name == "perk_flak" or name == "headtaker" then
                        return {name = name, display_name = "internal/perk/path", trait_text = "+25%% Damage vs Flak Armoured (T%d)"}
                    end
					return TestMasterItems[name]
                end,
                get_store_item_instance = function() error("Brunt lootChoices has no rolled item id") end,
                get_item_instance = function(gear) return gear and gear.base_stats and gear or nil end,
            },
			["scripts/utilities/profile_utils"] = {
				get_profile_presets = function() return {} end,
			},
			["scripts/settings/item/crafting_settings"] = {
				recipes = {
					upgrade_item = {
						is_valid_item = function(item) return item and item.rarity < 2 end,
						get_costs = function(context) return {plasteel = 10, rarity = context.item.rarity} end,
					},
				},
			},
            ["scripts/utilities/weapon/weapon_template"] = {
                weapon_template_from_item = function(item) return item and item._weapon_template end,
            },
            ["scripts/settings/ui/ui_sound_events"] = {},
        }

        function require(name)
            return modules[name]
        end

        Color = setmetatable({}, {
            __index = function()
                return function() return {255, 255, 255, 255} end
            end,
            __call = function() return {255, 255, 255, 255} end,
        })

        local localized = {
            loc_stats_display_damage_stat = "Damage",
            loc_stats_display_defense_stat = "Defenses",
            loc_stats_display_ap_stat = "Penetration",
            loc_stats_display_first_target_stat = "First Target",
            loc_stats_display_mobility_stat = "Mobility",
            loc_stats_display_finesse_stat = "Finesse",
        }

        function Localize(key)
            return localized[key] or key
        end

		TestCharacterData = {favorite_items = {}}
		TestProfile = {current_level = 30, loadout = {}, loadout_item_ids = {}}
		TestDeletedGearIds = nil
		Managers = {
			player = {
				local_player = function()
					return {
						character_id = function() return "character-1" end,
						profile = function() return TestProfile end,
					}
				end,
			},
			save = {
				character_data = function(_, _) return TestCharacterData end,
			},
		}

        TestServices = {
            store = {
                get_credits_goods_store = function()
                    return promise({
                        offers = {
                            {
                                description = {lootChoices = {"crowbar_master", "crowbar_master", "invalid_cross_slot", "invalid_wrong_family", "invalid_missing_template", "missing_mark"}},
                                offerId = "crowbar_offer",
                                price = {amount = {amount = 11600, type = "credits"}},
                                sku = {category = "weapon"},
                            },
							{
								description = {lootChoices = {"pistol_master", "pistol_master_alt", "invalid_cross_slot"}},
								offerId = "pistol_offer",
								price = {amount = {amount = 9200, type = "credits"}},
								sku = {category = "weapon"},
							},
                        },
                    })
                end,
                combined_wallets = function()
					local wallet = {balance = {amount = 1000000, type = "credits"}, lastTransactionId = 42}

					return promise({
						wallets = {wallet},
						by_type = function(_, wallet_type)
							return wallet_type == "credits" and wallet or nil
						end,
					})
                end,
				invalidate_wallets_cache = function()
					TestWalletInvalidations = TestWalletInvalidations + 1
				end,
				purchase_item_with_wallet = function(_, _, wallet)
					TestPurchaseAttempts = TestPurchaseAttempts + 1

					if TestTransactionMismatchOnce and TestPurchaseAttempts == 1 then
						return promise(nil, {description = "Transaction id mismatch"})
					end

					assert(wallet and wallet.lastTransactionId == 42)

                    return promise({
                        items = {
                            {
                                uuid = "crowbar_gear",
                                name = "content/items/weapons/player/melee/crowbar_p1_m1",
                                display_name = "Crowbar",
                                parent_pattern = "crowbar_p1",
                                rarity = 0,
                                _weapon_template = crowbar_template,
                                base_stats = {
                                    {name = "crowbar_p1_m1_dps_stat", value = 0.78},
                                    {name = "crowbar_p1_m1_defence_stat", value = 0.60},
                                },
                            },
                        },
                    })
                end,
            },
            gear = {
				delete_gear_batch = function(_, gear_ids)
					TestDeletedGearIds = gear_ids

					return promise({{gearId = gear_ids[1]}})
				end,
				fetch_gear = function() return promise(TestGear) end,
            },
            crafting = {
				upgrade_weapon_rarity = function(_, gear_id, costs)
					assert(costs and costs.plasteel == 10)
					TestBatchUpgradeIds[#TestBatchUpgradeIds + 1] = gear_id
					return promise({gear_id = gear_id})
				end,
                get_traits_mastery_costs = function()
                    return {tierCosts = {["1"] = 1, ["2"] = 2, ["3"] = 3, ["4"] = 4}, tierThresholds = {["1"] = 0, ["2"] = 5, ["3"] = 10, ["4"] = 20}}
                end,
                get_item_crafting_metadata = function()
                    return promise({perks = {
                        [1] = {rarity = 1, perks = {"perk_flak"}},
                        -- Patch metadata has repeated canonical IDs in the
                        -- same rank. Discovery must expose one mutation target.
                        [4] = {rarity = 4, perks = {"perk_flak", "perk_flak"}},
                    }})
                end,
                trait_sticker_book = function() return promise({}) end,
            },
			mastery = {
				purchase_traits = function(_, pattern_id, operations)
					TestPurchasedTraits = {operations = operations, pattern_id = pattern_id}
					return promise(TestMasteryPurchaseFails and operations or {})
				end,
				get_mastery_by_pattern = function()
                    return promise({current_xp = 0, mastery_level = 0, milestones = {{level = 1, xpLimit = 100}}})
                end,
            },
        }
        '''
    )

    backend_module = lua.execute(
        BACKEND_PATH.read_text(encoding="utf-8"), name=str(BACKEND_PATH)
    )
    backend = backend_module.new(lua.table_from({"services": lua.globals().TestServices}))
    snapshot_promise = backend.probe_snapshot(backend)
    assert snapshot_promise.failure is None
    snapshot = snapshot_promise.value
    offer = snapshot.store.offers[1]
    assert snapshot.crafting_access.unlocked is True
    assert snapshot.crafting_access.character_level == 30
    assert snapshot.crafting_access.mastery_verification_required is False
    assert snapshot.crafting_access.required_character_level == 4

    # Native Hadron progression unlocks at level 4. Psych Ward may not expose
    # mission-board state, so a known sufficient level remains usable there.
    lua.globals().TestProfile.current_level = 1
    level_one_snapshot = backend.probe_snapshot(backend).value
    assert level_one_snapshot.crafting_access.unlocked is False
    assert level_one_snapshot.crafting_access.mastery_verification_required is True
    lua.globals().TestProfile.current_level = 10
    low_level_snapshot = backend.probe_snapshot(backend).value
    assert low_level_snapshot.crafting_access.unlocked is True
    lua.globals().TestProfile.current_level = 30
    lua.execute(
        r'''
        Managers.data_service = {
            mission_board = {
                get_hub_facilities_progression_data = function()
                    return {omnissiah = {unlocked = false}}
                end,
            },
        }
        '''
    )
    facility_locked_snapshot = backend.probe_snapshot(backend).value
    assert facility_locked_snapshot.crafting_access.unlocked is False
    lua.execute(
        r'''
        Managers.data_service.mission_board.get_hub_facilities_progression_data = function()
            return {}
        end
        '''
    )
    missing_facility_snapshot = backend.probe_snapshot(backend).value
    assert missing_facility_snapshot.crafting_access.unlocked is False
    lua.globals().Managers.data_service = None
    assert len(offer.base_stats) == 5
    assert len(offer.marks) == 3
    assert offer.marks[1].master_id == "crowbar_master"
    assert offer.marks[2].master_id == "crowbar_master_alt"
    assert offer.marks[2].display_name == "Crowbar Mk II"
    assert offer.marks[3].master_id == "crowbar_master_locked"
    assert offer.marks[3].display_name == "Crowbar Mk III"
    # Mark discovery is independent from mastery level, but malformed, unresolved,
    # cross-family, cross-slot, duplicate, and missing-template candidates fail closed.
    assert snapshot.store.offer_count == 2
    ranged_offer = snapshot.store.offers[2]
    assert ranged_offer.slot_type == "slot_secondary"
    assert len(ranged_offer.marks) == 2
    assert ranged_offer.marks[1].master_id == "pistol_master"
    assert ranged_offer.marks[2].master_id == "pistol_master_alt"
    stat_keys = {offer.base_stats[index].name: offer.base_stats[index].display_name_key for index in range(1, 6)}
    assert stat_keys["crowbar_p1_m1_dps_stat"] == "loc_stats_display_damage_stat"
    assert stat_keys["crowbar_p1_m1_defence_stat"] == "loc_stats_display_defense_stat"

    # Account-wide gear cache must be narrowed to active character. Live profile
    # swaps otherwise let Auto Crafter reuse another operative's weapon.
    lua.execute(
        r'''
        TestGear = {
            current = {uuid = "current", characterId = "character-1", rarity = 0, base_stats = {{name = "damage", value = 0.5}}},
            other = {uuid = "other", characterId = "character-2", rarity = 0, base_stats = {{name = "damage", value = 0.5}}},
            shared = {uuid = "shared", rarity = 0, base_stats = {{name = "damage", value = 0.5}}},
        }
        '''
    )
    character_snapshot = backend.probe_snapshot(backend).value
    assert character_snapshot.character_id == "character-1"
    character_gear_ids = {character_snapshot.gear["items"][index].gear_id for index in range(1, 3)}
    assert character_gear_ids == {"current", "shared"}
    lua.execute(
        r'''
        TestGear = {
            ["gear-a"] = {uuid = "gear-a", rarity = 0, base_stats = {{name = "damage", value = 0.5}}},
            ["gear-b"] = {uuid = "gear-b", rarity = 0, base_stats = {{name = "damage", value = 0.5}}},
        }
        '''
    )
    backend.probe_snapshot(backend)

    purchase_promise = backend.purchase_offer(backend, lua.table_from({
        "offerId": "crowbar_offer",
        "price": {"amount": {"amount": 11600, "type": "credits"}},
    }))
    assert purchase_promise.failure is None
    purchased = purchase_promise.value["items"][1]
    assert purchased.damage == 78
    assert purchased.base_stats["crowbar_p1_m1_dps_stat"] == 78
    assert purchased.potential_damage == 80
    assert purchased.potential_base_stats["crowbar_p1_m1_dps_stat"] == 80
    assert purchased.potential_base_stats["crowbar_p1_m1_defence_stat"] == 60
    assert lua.globals().TestWalletInvalidations == 0
    assert lua.globals().TestPurchaseAttempts == 1

    # An explicit optimistic-concurrency rejection is safe to retry exactly once
    # after another authoritative wallet refresh. No other failure is retried.
    lua.globals().TestTransactionMismatchOnce = True
    lua.globals().TestPurchaseAttempts = 0
    lua.globals().TestWalletInvalidations = 0
    retry_purchase = backend.purchase_offer(backend, lua.table_from({
        "offerId": "crowbar_offer",
        "price": {"amount": {"amount": 11600, "type": "credits"}},
    }))
    assert retry_purchase.failure is None
    assert lua.globals().TestPurchaseAttempts == 2
    assert lua.globals().TestWalletInvalidations == 1
    lua.globals().TestTransactionMismatchOnce = False

    batch_upgrade = backend.upgrade_weapon_rarities(backend, lua.table_from(["gear-a", "gear-b"]))
    assert batch_upgrade.failure is None
    assert batch_upgrade.value.count == 2
    assert lua.globals().TestBatchUpgradeIds[1] == "gear-a"
    assert lua.globals().TestBatchUpgradeIds[2] == "gear-b"

    allocation = backend.purchase_mastery_trait(backend, "crowbar_p1", "headtaker", 4)
    assert allocation.failure is None
    assert allocation.value.submitted is True
    assert lua.globals().TestPurchasedTraits.pattern_id == "crowbar_p1"
    assert lua.globals().TestPurchasedTraits.operations[1].trait_name == "headtaker"
    assert lua.globals().TestPurchasedTraits.operations[1].rarity == 4
    mastery_costs = backend.get_mastery_trait_costs(backend)
    assert mastery_costs.failure is None
    assert mastery_costs.value.tier_costs["4"] == 4
    assert mastery_costs.value.tier_thresholds["3"] == 10
    lua.globals().TestMasteryPurchaseFails = True
    rejected_allocation = backend.purchase_mastery_trait(backend, "crowbar_p1", "headtaker", 4)
    assert "mastery blessing allocation was rejected by the backend" in rejected_allocation.failure.description
    lua.globals().TestMasteryPurchaseFails = False
    batch_allocation = backend.purchase_mastery_traits(backend, "crowbar_p1", lua.table_from([
        {"trait_id": "headtaker", "rarity": 1},
        {"trait_id": "headtaker", "rarity": 2},
    ]))
    assert batch_allocation.failure is None
    assert batch_allocation.value.count == 2
    assert lua.globals().TestPurchasedTraits.operations[1].trait_name == "headtaker"
    assert lua.globals().TestPurchasedTraits.operations[2].rarity == 2

    # A max-level weapon needs no zero-delta preview response to remain reusable.
    lua.globals().TestExpertise = 500
    lua.globals().TestPreviewCalls = 0
    lua.execute(
        r'''
        TestGear = {
            maxed_crowbar = {
                uuid = "maxed_crowbar",
                name = "content/items/weapons/player/melee/crowbar_p1_m1",
                display_name = "Crowbar",
                parent_pattern = "crowbar_p1",
                rarity = 5,
                base_stats = {
                    {name = "crowbar_p1_m1_dps_stat", value = 0.80},
                    {name = "crowbar_p1_m1_defence_stat", value = 0.60},
                },
            },
        }
        '''
    )
    maxed_snapshot = backend.probe_snapshot(backend).value
    maxed = maxed_snapshot.gear["items"][1]
    assert maxed.potential_base_stats["crowbar_p1_m1_dps_stat"] == 80
    assert maxed.potential_base_stats["crowbar_p1_m1_defence_stat"] == 60
    assert lua.globals().TestPreviewCalls == 0
    lua.globals().TestExpertise = 300
    lua.globals().TestGear = lua.table_from({})
    favorite_promise = backend.favorite_item(backend, "crowbar_gear")
    assert favorite_promise.failure is None
    assert favorite_promise.value.favorited is True
    assert lua.globals().TestFavoriteItems["crowbar_gear"] is True
    discard_promise = backend.discard_items(backend, lua.table_from(["bad-gear-1"]))
    assert discard_promise.failure is None
    assert lua.globals().TestDeletedGearIds[1] == "bad-gear-1"
    lua.globals().TestCharacterData.favorite_items["protected-gear"] = True
    protected_discard = backend.discard_items(backend, lua.table_from(["protected-gear"]))
    assert protected_discard.failure is not None

    catalog_promise = backend.discover_weapon_catalog(backend, offer)
    assert catalog_promise.failure is None
    assert catalog_promise.value.perk_count == 1
    assert catalog_promise.value.perks[1].display_name == "+25% Damage vs Flak Armoured (T4)"
    assert catalog_promise.value.perks[1].tier == 4
    assert catalog_promise.value.mastery.unlocked is True
    assert catalog_promise.value.mastery.required_character_level == 1

    planner = lua.execute(
        PLANNER_PATH.read_text(encoding="utf-8"), name=str(PLANNER_PATH)
    )

    def plan(dump_stat: str):
        return planner.build(
            snapshot,
            lua.table_from(
                {
                    "target_offer": offer,
                    "dump_stat": dump_stat,
                    "cap_by_dockets": True,
                    "docket_cap": 1000000,
                }
            ),
        )

    legacy_auto_plan = plan("auto")
    assert len(legacy_auto_plan.dump_stat_candidates) == 5
    ordered_names = [legacy_auto_plan.dump_stat_candidates[index].name for index in range(1, 6)]
    assert ordered_names == [
        "crowbar_p1_m1_dps_stat",
        "crowbar_p1_m1_mobility_stat",
        "crowbar_p1_m1_first_target_stat",
        "crowbar_p1_m1_armor_pierce_stat",
        "crowbar_p1_m1_defence_stat",
    ]
    assert legacy_auto_plan.resolved_dump_stat == "crowbar_p1_m1_dps_stat"
    assert planner.default_dump_stat(legacy_auto_plan) == "crowbar_p1_m1_dps_stat"
    defense_plan = plan("defenses")
    assert defense_plan.resolved_dump_stat == "crowbar_p1_m1_defence_stat"
    assert defense_plan.dump_stat_identity.name == "crowbar_p1_m1_defence_stat"
    assert defense_plan.dump_stat_identity.display_name_key == "loc_stats_display_defense_stat"
    penetration_plan = plan("penetration")
    assert penetration_plan.resolved_dump_stat == "crowbar_p1_m1_armor_pierce_stat"
    assert penetration_plan.estimate.base_level_min == 290
    assert penetration_plan.estimate.base_level_max == 330
    assert penetration_plan.estimate.dockets_floor == 11600
    assert penetration_plan.estimate.dockets_cap == 1000000
    assert penetration_plan.estimate.purchase_count_cap == 86

    # Account mutations must never bypass the native Hadron or selected-family
    # mastery gates. Acquisition-only configurations remain valid at level 1.
    snapshot.crafting_access = lua.table_from(
        {
            "unlocked": False,
            "character_level": 1,
            "required_character_level": 4,
        }
    )
    locked_crafting_plan = planner.build(
        snapshot,
        lua.table_from(
            {
                "target_offer": offer,
                "dump_stat": "crowbar_p1_m1_dps_stat",
				"cap_by_dockets": True,
				"docket_cap": 1000000,
                "consecrate_transcendent": True,
                "level_mastery_20": False,
                "upgrade_expertise_500": False,
                "change_perks": False,
                "change_blessings": False,
            }
        ),
    )
    assert locked_crafting_plan.preflight.ok is False
    assert "Hadron crafting is not unlocked" in locked_crafting_plan.preflight.summary
    acquisition_only_plan = planner.build(
        snapshot,
        lua.table_from(
            {
                "target_offer": offer,
                "dump_stat": "crowbar_p1_m1_dps_stat",
				"cap_by_dockets": True,
				"docket_cap": 1000000,
                "consecrate_transcendent": False,
                "level_mastery_20": False,
                "upgrade_expertise_500": False,
                "change_perks": False,
                "change_blessings": False,
            }
        ),
    )
    assert "Hadron crafting is not unlocked" not in acquisition_only_plan.preflight.summary
    snapshot.crafting_access = lua.table_from(
        {
            "unlocked": True,
            "character_level": 30,
            "required_character_level": 4,
        }
    )
    locked_mastery_catalog = lua.table_from(
        {
			"mastery": lua.table_from(
				{
					"unlocked": False,
					"required_character_level": 10,
				}
			),
        }
    )
    locked_mastery_plan = planner.build(
        snapshot,
        lua.table_from(
            {
                "target_offer": offer,
                "dump_stat": "crowbar_p1_m1_dps_stat",
				"cap_by_dockets": True,
				"docket_cap": 1000000,
                "trait_catalog": locked_mastery_catalog,
                "consecrate_transcendent": False,
                "level_mastery_20": True,
                "upgrade_expertise_500": False,
                "change_perks": False,
                "change_blessings": False,
            }
        ),
    )
    assert locked_mastery_plan.preflight.ok is False
    assert "selected weapon-family mastery unlocks at character level 10" in locked_mastery_plan.preflight.summary
    snapshot.crafting_access = lua.table_from(
        {
            "unlocked": True,
            "character_level": 10,
			"mastery_verification_required": True,
            "required_character_level": 4,
        }
    )
    undiscovered_mastery_plan = planner.build(
        snapshot,
        lua.table_from(
            {
                "target_offer": offer,
                "dump_stat": "crowbar_p1_m1_dps_stat",
				"cap_by_dockets": True,
				"docket_cap": 1000000,
                "consecrate_transcendent": False,
                "level_mastery_20": True,
                "upgrade_expertise_500": False,
                "change_perks": False,
                "change_blessings": False,
            }
        ),
    )
    assert undiscovered_mastery_plan.preflight.ok is False
    assert "selected weapon-family mastery unlock is not verified" in undiscovered_mastery_plan.preflight.summary
    snapshot.crafting_access = lua.table_from(
        {
            "unlocked": True,
            "character_level": 30,
			"mastery_verification_required": False,
            "required_character_level": 4,
        }
    )

    custom_plan = planner.build(
        snapshot,
        lua.table_from(
            {
                "target_offer": offer,
                "custom_stats_enabled": True,
                "custom_stat_targets": lua.table_from([60, 80, 80, 80, 80]),
            }
        ),
    )
    assert custom_plan.custom_stats_enabled is True
    assert custom_plan.custom_stats_valid is True
    assert custom_plan.custom_stat_total == 380
    assert len(custom_plan.custom_stat_targets) == 5
    assert custom_plan.custom_stat_target_map["crowbar_p1_m1_dps_stat"] == 60
    assert custom_plan.custom_stat_target_map["crowbar_p1_m1_defence_stat"] == 80

    invalid_custom_plan = planner.build(
        snapshot,
        lua.table_from(
            {
                "target_offer": offer,
                "custom_stats_enabled": True,
                "custom_stat_targets": lua.table_from([60, 79, 80, 80, 80]),
            }
        ),
    )
    assert invalid_custom_plan.custom_stats_valid is False
    assert invalid_custom_plan.custom_stat_total == 379
    assert invalid_custom_plan.preflight.ok is False
    assert "custom stat total must equal 380" in invalid_custom_plan.preflight.summary

    rarity_costs = lua.table_from(
        {
            str(rarity): lua.table_from(
                [
                    lua.table_from({"type": "plasteel", "amount": 10}),
                    lua.table_from({"type": "diamantine", "amount": 2}),
                ]
            )
            for rarity in range(5)
        }
    )
    expertise_costs = lua.table_from(
        {
            str(bucket): lua.table_from(
                [lua.table_from({"type": "plasteel", "amount": 1})]
            )
            for bucket in range(290, 501, 10)
        }
    )
    snapshot.crafting_costs = lua.table_from(
        {
            "available": True,
            "weapon": lua.table_from(
                {
                    "baseItemLevelSpan": lua.table_from({"min": 1, "max": 380}),
                    "costScalingSpan": lua.table_from({"min": 1, "max": 1}),
                    "rarityUpgrade": lua.table_from(
                        {"startCost": rarity_costs}
                    ),
                    "addExpertise": lua.table_from(
                        {"startCost": expertise_costs}
                    ),
                }
            ),
        }
    )
    material_plan = plan("penetration")
    assert material_plan.estimate.plasteel_min == 210
    assert material_plan.estimate.plasteel_max == 250
    assert material_plan.estimate.diamantine_min == 8
    assert material_plan.estimate.diamantine_max == 8
    assert material_plan.estimate.phases.consecrate.plasteel_min == 40
    assert material_plan.estimate.phases.expertise.plasteel_min == 170

    # Live recipe minimums are hard preflight bounds; absent wallet currencies
    # remain unknown rather than being treated as zero.
    snapshot.wallets.currencies["plasteel"] = lua.table_from({"amount": 209})
    snapshot.wallets.currencies["diamantine"] = lua.table_from({"amount": 8})
    low_material_plan = plan("penetration")
    assert low_material_plan.preflight.ok is False
    assert "insufficient plasteel" in low_material_plan.preflight.summary
    snapshot.wallets.currencies["plasteel"] = None
    snapshot.wallets.currencies["diamantine"] = None

    snapshot.crafting_costs.sacrifice_mastery = lua.table_from(
        {
            "sacrifice_muiltiplier": 1,
            "minimumExpertiseLevel": 0,
            "baseReward": 0,
            "masteryXpPerExpertiseLevel": 10,
        }
    )
    snapshot.crafting_costs.weapon.perkReplace = lua.table_from(
        {
            "startCost": lua.table_from(
                {
                    "4": lua.table_from(
                        [lua.table_from({"type": "credits", "amount": 2000})]
                    )
                }
            )
        }
    )
    snapshot.crafting_costs.weapon.traitReplace = lua.table_from(
        {
            "startCost": lua.table_from(
                {
                    "4": lua.table_from(
                        [lua.table_from({"type": "credits", "amount": 4500})]
                    )
                }
            )
        }
    )
    snapshot.wallets.currencies["credits"] = lua.table_from({"amount": 400000})
    snapshot.wallets.currencies["plasteel"] = lua.table_from({"amount": 10000})
    snapshot.wallets.currencies["diamantine"] = lua.table_from({"amount": 1000})
    mastery_plan = planner.build(
        snapshot,
        lua.table_from(
            {
                "target_offer": offer,
                "dump_stat": "penetration",
                "cap_by_dockets": True,
                "docket_cap": 1000000,
                "acquisition_mode": "target_search",
                "change_perks": True,
                "change_blessings": True,
                "level_mastery_20": True,
                "trait_catalog": lua.table_from(
                    {
                        "mastery": lua.table_from(
                            {
                                "current_xp": 0,
                                "milestones": lua.table_from(
                                    [
                                        lua.table_from(
                                            {"level": level, "xpLimit": level * 500}
                                        )
                                        for level in range(1, 21)
                                    ]
                                ),
                            }
                        )
                    }
                ),
            }
        ),
    )
    assert mastery_plan.estimate.phases.mastery.count_min == 30
    assert mastery_plan.estimate.phases.mastery.count_max == 34
    assert mastery_plan.estimate.phases.mastery.dockets_min == 348000
    assert mastery_plan.estimate.phases.mastery.dockets_max == 394400
    assert mastery_plan.estimate.phases.traits.dockets_min == 13000
    assert mastery_plan.estimate.phases.traits.dockets_max == 13000
    assert mastery_plan.estimate.dockets_min == 361000
    assert mastery_plan.estimate.dockets_max == 407400
    assert mastery_plan.estimate.costs.generous.dockets == 461000
    assert mastery_plan.estimate.costs.unlucky.dockets == 707400
    assert mastery_plan.estimate.costs.generous.plasteel == 510
    assert mastery_plan.estimate.costs.unlucky.plasteel == 590
    assert mastery_plan.estimate.costs.generous.diamantine == 68
    assert mastery_plan.estimate.costs.unlucky.diamantine == 76
    assert mastery_plan.estimate.costs.remaining_generous.dockets == -61000
    assert mastery_plan.estimate.costs.remaining_unlucky.dockets == -307400

    first_weapon_plan = planner.build(
        snapshot,
        lua.table_from(
            {
                "target_offer": offer,
                "dump_stat": "penetration",
                "cap_by_dockets": True,
                "docket_cap": 1000000,
                "acquisition_mode": "first_weapon",
                "consecrate_transcendent": False,
                "level_mastery_20": False,
                "upgrade_expertise_500": False,
                "change_perks": False,
                "change_blessings": False,
            }
        ),
    )
    assert first_weapon_plan.estimate.costs.generous.dockets == 11600
    assert first_weapon_plan.estimate.costs.unlucky.dockets == 11600

    disabled_acquisition_plan = planner.build(
        snapshot,
        lua.table_from(
            {
                "target_offer": offer,
                "dump_stat": "penetration",
                "cap_by_dockets": True,
                "docket_cap": 1000000,
                "acquisition_mode": "disabled",
                "consecrate_transcendent": False,
                "level_mastery_20": False,
                "upgrade_expertise_500": False,
                "change_perks": False,
                "change_blessings": False,
            }
        ),
    )
    assert disabled_acquisition_plan.estimate.costs.generous.dockets == 0
    assert disabled_acquisition_plan.estimate.costs.unlucky.dockets == 0

    lua.execute(
        '''
        TestPanelSettings = {
            value = "crowbar_p1_m1_defence_stat",
            get = function(self, _) return self.value end,
            set = function(self, _, value) self.value = value return true end,
        }
        '''
    )
    panel_module = __import__("auto_crafter_test_support").load_panel(lua)
    estimate_panel = panel_module.new(lua.table_from({}))
    estimate_panel._plan = mastery_plan
    assert estimate_panel._estimate_currency_values(estimate_panel, "wallet") == (
        "400k", "10k", "1k", False, False, False
    )
    assert estimate_panel._estimate_currency_values(estimate_panel, "generous") == (
        "461k", "510", "68", False, False, False
    )
    assert estimate_panel._estimate_currency_values(estimate_panel, "unlucky") == (
        "707k", "590", "76", False, False, False
    )
    assert estimate_panel._estimate_currency_values(estimate_panel, "remaining_generous") == (
        "-61k", "9.5k", "932", True, False, False
    )
    assert estimate_panel._estimate_currency_values(estimate_panel, "remaining_unlucky") == (
        "-307k", "9.4k", "924", True, False, False
    )
    assert panel_module.weapon_name_with_mark("Power Falchion", "Achlys • Mk VI") == "Achlys Mk VI Power Falchion"
    assert panel_module.weapon_name_with_mark("Branx Mk XI Paired Transonic Blades", "Mk XI") == "Branx Mk XI Paired Transonic Blades"
    idle_workflow = lua.table_from({"phase": "idle"})
    active_manual_workflow = lua.table_from({"search": lua.table_from({"running": True})})
    settling_workflow = lua.table_from({"operation_inflight": True})
    staged_queue = lua.table_from({"state": "staged"})
    running_queue = lua.table_from({"state": "running"})
    assert panel_module.workflow_active(idle_workflow, staged_queue) is False
    assert panel_module.workflow_active(active_manual_workflow, staged_queue) is True
    assert panel_module.workflow_active(settling_workflow, staged_queue) is True
    assert panel_module.workflow_active(idle_workflow, running_queue) is True
    lua.globals().PanelModule = panel_module
    lua.execute(
        r'''
        local queue_snapshot_calls = 0
        local import_snapshot_calls = 0
        local queue_signature_calls = 0
        local import_signature_calls = 0
        local selected_offer_calls = 0
        local pivot_calls = 0
        local rendered = 0
        local queue_snapshot = {queue_id = "queue-a", state = "empty", jobs = {}}
        local import_snapshot = {state = "idle"}
        local native_offer = {
            offerId = "offer-a",
            description = {lootChoices = {{masterId = "master-a"}}},
        }
        local polling_panel = PanelModule.new({
            games_lantern_queue_snapshot = function()
                queue_snapshot_calls = queue_snapshot_calls + 1
                return queue_snapshot
            end,
            games_lantern_import_snapshot = function()
                import_snapshot_calls = import_snapshot_calls + 1
                return import_snapshot
            end,
            get_selected_offer = function()
                selected_offer_calls = selected_offer_calls + 1
                return native_offer
            end,
        })
        local queue_signature = polling_panel._games_lantern_queue_signature
        local import_signature = polling_panel._games_lantern_import_signature
        polling_panel._games_lantern_queue_signature = function(self, snapshot)
            queue_signature_calls = queue_signature_calls + 1
            return queue_signature(self, snapshot)
        end
        polling_panel._games_lantern_import_signature = function(self, snapshot)
            import_signature_calls = import_signature_calls + 1
            return import_signature(self, snapshot)
        end
        polling_panel._panel = {}
        polling_panel._view = {}
        polling_panel._update_pivot = function()
            pivot_calls = pivot_calls + 1
            return true
        end
        polling_panel.render = function()
            rendered = rendered + 1
            return true
        end

        polling_panel:update(0.5)
        polling_panel:update(0.5)
        local stable_selected_offer = polling_panel._selected_offer
        local stable_selected_offer_calls = selected_offer_calls
        local stable_pivot_calls = pivot_calls
        for _ = 1, 60 do polling_panel:update(1 / 60) end

        assert(queue_snapshot_calls == 1 and import_snapshot_calls == 1)
        assert(queue_signature_calls == 1 and import_signature_calls == 1)
        assert(selected_offer_calls - stable_selected_offer_calls <= 2)
        assert(pivot_calls - stable_pivot_calls <= 2)
        assert(rawequal(stable_selected_offer, polling_panel._selected_offer))
        assert(polling_panel._selected_offer_key == "offer:offer-a")

        polling_panel:invalidate_games_lantern_snapshots()
        polling_panel:update(1 / 60)
        assert(queue_snapshot_calls == 2 and import_snapshot_calls == 2)
        assert(queue_signature_calls == 2 and import_signature_calls == 2)

        native_offer = {
            offerId = "offer-b",
            description = {lootChoices = {{masterId = "master-b"}}},
        }
        for _ = 1, 30 do polling_panel:update(1 / 60) end
        assert(not rawequal(stable_selected_offer, polling_panel._selected_offer))
        assert(polling_panel._selected_offer_key == "offer:offer-b")
        assert(rendered >= 1)
        '''
    )
    panel = panel_module.new(lua.table_from({"settings": lua.globals().TestPanelSettings}))

    # Lua's common `condition and value or fallback` idiom loses explicit false.
    # Default-on workflow checkboxes must be able to persist and display false.
    lua.execute(
        '''
        TestPanelBooleanSettings = {
            values = {
                auto_crafter_buy_until_target = false,
                auto_crafter_consecrate_transcendent = false,
                auto_crafter_upgrade_expertise_500 = false,
            },
            get = function(self, key) return self.values[key] end,
            set = function(self, key, value) self.values[key] = value return true end,
        }
        '''
    )
    boolean_panel = panel_module.new(
        lua.table_from({"settings": lua.globals().TestPanelBooleanSettings})
    )
    for setting_id in (
        "auto_crafter_buy_until_target",
        "auto_crafter_consecrate_transcendent",
        "auto_crafter_upgrade_expertise_500",
    ):
        assert boolean_panel._setting(boolean_panel, setting_id, True) is False
        assert boolean_panel._set_setting(boolean_panel, setting_id, True) is True
        assert boolean_panel._setting(boolean_panel, setting_id, False) is True

    assert boolean_panel._acquisition_mode(boolean_panel) == "target_search"
    boolean_panel._set_setting(boolean_panel, "auto_crafter_buy_until_target", False)
    assert boolean_panel._acquisition_mode(boolean_panel) == "disabled"
    boolean_panel._set_setting(boolean_panel, "auto_crafter_buy_until_target", "first_weapon")
    assert boolean_panel._acquisition_mode_text(boolean_panel) == "Automatically buy first weapon and proceed"
    assert boolean_panel._step_acquisition_mode(boolean_panel, 1) is True
    assert boolean_panel._acquisition_mode(boolean_panel) == "target_search"
    assert boolean_panel._dump_comparison(boolean_panel) == "exact"
    assert boolean_panel._toggle_dump_comparison(boolean_panel) is True
    assert boolean_panel._dump_comparison(boolean_panel) == "at_most"

    color_settings = lua.execute(
        '''
        return {
            values = {
                auto_crafter_favorite_result = true,
                auto_crafter_myfavorites_color = 4,
            },
            get = function(self, key) return self.values[key] end,
            set = function(self, key, value) self.values[key] = value return true end,
        }
        '''
    )
    color_panel = panel_module.new(
        lua.table_from(
            {
                "settings": color_settings,
                "is_myfavorites_available": lua.eval("function() return true end"),
                "myfavorites_color_preview": lua.eval(
                    'function(index) return "{#color(138,43,226)}Color " .. tostring(index) .. "  ■{#reset()}" end'
                ),
            }
        )
    )
    assert color_panel._myfavorites_available(color_panel) is True
    assert "Color 4" in color_panel._myfavorites_color_text(color_panel)
    color_panel._step_enum_setting(
        color_panel, "auto_crafter_myfavorites_color", lua.table_from([1, 2, 3, 4, 5]), 1, 1
    )
    assert color_settings["values"].auto_crafter_myfavorites_color == 5

    widget_snapshot = lua.execute(
        'return {phase = "idle", store = {offers = {}, offer_count = 0}, gear = {item_count = 0}}'
    )
    color_entries = color_panel._entries(color_panel, widget_snapshot)
    color_labels = [
        color_entries[index].initial_content.label
        for index in range(1, len(color_entries) + 1)
    ]
    assert "MyFavorites color" in color_labels

    no_color_panel = panel_module.new(
        lua.table_from(
            {
                "settings": color_settings,
                "is_myfavorites_available": lua.eval("function() return false end"),
                "myfavorites_color_preview": lua.eval('function() error("must remain hidden") end'),
            }
        )
    )
    no_color_entries = no_color_panel._entries(no_color_panel, widget_snapshot)
    no_color_labels = [
        no_color_entries[index].initial_content.label
        for index in range(1, len(no_color_entries) + 1)
    ]
    assert "MyFavorites color" not in no_color_labels

    queue_header = panel._entry(
        panel,
        "Active Queue",
        "idle",
        lua.table_from(
            {
                "selectable": True,
                "section_header": True,
                "section_id": "games_lantern_queue",
                "variant": "section",
            }
        ),
    )
    assert queue_header.initial_content.hotspot.disabled is False
    queue_widget = lua.table_from({"content": queue_header.initial_content})
    queue_header.bind(queue_widget)
    queue_widget.content.hotspot.pressed_callback()
    assert panel._section_collapsed["games_lantern_queue"] is True

    panel._plan = defense_plan
    panel_options = panel._planner_dump_stat_options(panel)
    assert [panel_options[index] for index in range(1, len(panel_options) + 1)] == ordered_names
    assert "auto" not in [panel_options[index] for index in range(1, len(panel_options) + 1)]
    stat_buttons = panel._planner_dump_stat_buttons(panel)
    assert len(stat_buttons) == 5
    assert [stat_buttons[index].name for index in range(1, 6)] == ordered_names
    assert stat_buttons[1].label == "Damage"
    assert stat_buttons[2].label == "Mobility"
    grid_entry = panel._entry(
        panel,
        "",
        "",
        lua.table_from(
            {"variant": "stat_grid", "selectable": True, "stat_buttons": stat_buttons}
        ),
    )
    widget_content = lua.table_from(
        {f"stat_hotspot_{index}": lua.table_from({}) for index in range(1, 6)}
    )
    widget = lua.table_from({"content": widget_content})
    grid_entry.refresh(widget)
    assert grid_entry.initial_content.selectable is True
    assert widget.content.selected_stat_index == 5
    stat_grid_passes = panel_module.stat_grid_passes(421, grid_entry)
    stat_hotspot_passes = [
        stat_grid_passes[index]
        for index in range(1, len(stat_grid_passes) + 1)
        if getattr(stat_grid_passes[index], "content_id", None)
        and str(stat_grid_passes[index].content_id).startswith("stat_hotspot_")
    ]
    assert len(stat_hotspot_passes) == 5
    assert all(
        getattr(hotspot_pass, "visibility_function", None) is None
        for hotspot_pass in stat_hotspot_passes
    )
    stat_logic_pass = next(
        stat_grid_passes[index]
        for index in range(1, len(stat_grid_passes) + 1)
        if stat_grid_passes[index].pass_type == "logic"
    )
    widget.content.stat_hotspot_1.on_pressed = True
    stat_logic_pass.value(None, None, None, widget.content)
    grid_entry.refresh(widget)
    assert lua.globals().TestPanelSettings.value == "crowbar_p1_m1_dps_stat"
    assert widget.content.selected_stat_index == 1
    assert panel._planner_dump_stat_text(panel) == "Damage"
    assert panel._planner_dump_stat_label(panel, "crowbar_p1_m1_defence_stat") == "Defenses"
    panel._plan = lua.table_from(
        {
            "dump_stat_candidates": lua.table_from(
                [
                    lua.table_from(
                        {
                            "name": "dual_shivs_p1_m1_finesse_stat",
                            "display_name_key": "loc_stats_display_finesse_stat",
                        }
                    )
                ]
            )
        }
    )
    assert panel._planner_dump_stat_label(panel, "dual_shivs_p1_m1_finesse_stat") == "Finesse"

    lua.execute(
        '''
        CustomPanelSettings = {
            values = {
                auto_crafter_custom_stats = true,
                auto_crafter_custom_stat_1 = 60,
                auto_crafter_custom_stat_2 = 80,
                auto_crafter_custom_stat_3 = 80,
                auto_crafter_custom_stat_4 = 80,
                auto_crafter_custom_stat_5 = 80,
            },
            get = function(self, key) return self.values[key] end,
            set = function(self, key, value) self.values[key] = value return true end,
        }
        '''
    )
    custom_panel = panel_module.new(
        lua.table_from({"settings": lua.globals().CustomPanelSettings})
    )
    custom_panel._plan = custom_plan
    custom_entry = custom_panel._entry(
        custom_panel,
        "",
        "",
        lua.table_from(
            {"variant": "custom_stat_grid", "selectable": True, "custom_stat_grid": True}
        ),
    )
    custom_content = lua.table_from(
        {
            **{
                f"custom_stat_decrease_hotspot_{index}": lua.table_from({})
                for index in range(1, 6)
            },
            **{
                f"custom_stat_increase_hotspot_{index}": lua.table_from({})
                for index in range(1, 6)
            },
        }
    )
    custom_widget = lua.table_from({"content": custom_content})
    custom_entry.bind(custom_widget)
    custom_entry.refresh(custom_widget)
    assert custom_widget.content.custom_stat_label_1 == "Damage"
    assert custom_widget.content.custom_stat_label_5 == "Defenses"
    assert custom_widget.content.custom_stat_total == "380/380"
    assert custom_widget.content.custom_stat_total_value == 380
    assert custom_widget.content.custom_stat_decrease_hotspot_1.disabled is True
    assert custom_widget.content.custom_stat_increase_hotspot_2.disabled is True
    assert custom_panel._adjust_custom_stat(custom_panel, 1, -1) is False
    assert custom_panel._adjust_custom_stat(custom_panel, 2, 1) is False
    assert custom_panel._adjust_custom_stat(custom_panel, 2, -1) is True
    custom_entry.refresh(custom_widget)
    assert custom_widget.content.custom_stat_total == "379/380"
    assert custom_panel._adjust_custom_stat(custom_panel, 1, 1) is True
    assert custom_panel._adjust_custom_stat(custom_panel, 1, 1) is False
    custom_entry.refresh(custom_widget)
    assert custom_widget.content.custom_stat_total == "380/380"
    assert custom_panel._manual_queue_detail(custom_panel, custom_plan).startswith(
        "Stats: Damage 60 / Mobility 80 / First Target 80 / Penetration 80 / Defenses 80"
    )
    custom_passes = panel_module.custom_stat_grid_passes(421)
    custom_hotspots = [
        custom_passes[index]
        for index in range(1, len(custom_passes) + 1)
        if getattr(custom_passes[index], "content_id", None)
        and str(custom_passes[index].content_id).startswith("custom_stat_")
    ]
    assert len(custom_hotspots) == 10

    lua.execute(
        '''
        TraitSettings = {
            values = {
                auto_crafter_perk_1_target = "keep",
                auto_crafter_perk_2_target = "stale_trait",
                auto_crafter_blessing_1_target = "keep",
                auto_crafter_blessing_2_target = "keep",
            },
            get = function(self, key) return self.values[key] end,
            set = function(self, key, value) self.values[key] = value return true end,
        }
        '''
    )
    trait_panel = panel_module.new(lua.table_from({"settings": lua.globals().TraitSettings}))
    trait_panel._plan = lua.table_from(
        {
            "trait_catalog": lua.table_from(
                {
                    "available": True,
                    "parent_pattern": "crowbar_p1",
                    "perks": lua.table_from(
                        [
                            lua.table_from(
                                {
                                    "id": "content/items/perks/melee/unyielding_t4",
                                    "display_name": "+25% Damage vs Unyielding Enemies",
                                    "display_name_key": "loc_stats_display_damage_stat",
                                    "tier": 4,
									"trait": "weapon_trait_melee_common_wield_increased_resistant_damage",
                                }
                            ),
                            lua.table_from(
                                {
                                    "id": "content/items/perks/melee/carapace_t4",
                                    "display_name": "+25% Damage vs Carapace Armoured Enemies",
                                    "display_name_key": "loc_stats_display_damage_stat",
                                    "tier": 4,
									"trait": "weapon_trait_melee_common_wield_increased_super_armor_damage",
                                }
                            ),
                            lua.table_from(
                                {
                                    "id": "content/items/perks/melee/flak_t4",
                                    "display_name": "+25% Damage vs Flak Armoured Enemies",
                                    "display_name_key": "loc_stats_display_damage_stat",
                                    "tier": 4,
									"trait": "weapon_trait_melee_common_wield_increased_armored_damage",
                                }
                            ),
                        ]
                    ),
                    "blessings": lua.table_from(
                        [
                            lua.table_from(
                                {
                                    "id": "blessing_power",
                                    "display_name_key": "loc_stats_display_finesse_stat",
                                    "icon": "content/ui/textures/icons/traits/test_blessing",
                                }
                            ),
                            lua.table_from(
                                {
                                    "id": "blessing_speed",
                                    "display_name_key": "loc_stats_display_mobility_stat",
                                    "icon": "content/ui/textures/icons/traits/test_blessing_2",
                                }
                            ),
                        ]
                    ),
                }
            )
        }
    )
    perk_options = trait_panel._trait_target_options(trait_panel, "auto_crafter_perk_1_target")
    assert [perk_options[index].value for index in range(1, len(perk_options) + 1)] == [
        "perk:content/items/perks/melee/unyielding_t4:4",
        "perk:content/items/perks/melee/carapace_t4:4",
        "perk:content/items/perks/melee/flak_t4:4",
    ]
    assert perk_options[3].label == "+25% Damage vs Flak Armoured Enemies"
    trait_panel._reconcile_trait_targets(trait_panel)
    assert lua.globals().TraitSettings["values"].auto_crafter_perk_1_target == "perk:content/items/perks/melee/unyielding_t4:4"
    assert lua.globals().TraitSettings["values"].auto_crafter_perk_2_target == "perk:content/items/perks/melee/carapace_t4:4"
    assert lua.globals().TraitSettings["values"].auto_crafter_blessing_1_target == "blessing_power"
    assert lua.globals().TraitSettings["values"].auto_crafter_blessing_2_target == "blessing_speed"
    trait_panel._step_trait_target(trait_panel, "auto_crafter_perk_1_target", 1)
    assert lua.globals().TraitSettings["values"].auto_crafter_perk_1_target == "perk:content/items/perks/melee/flak_t4:4"

    perk_grid_entry = trait_panel._entry(
        trait_panel,
        "",
        "",
        lua.table_from(
            {
                "selectable": True,
                "target_1_setting": "auto_crafter_perk_1_target",
                "target_2_setting": "auto_crafter_perk_2_target",
                "trait_button_height": 38,
                "trait_columns": 4,
                "trait_options": perk_options,
                "variant": "trait_grid",
            }
        ),
    )
    perk_grid_widget = lua.table_from(
        {
            "content": lua.table_from(
                {
                    f"trait_hotspot_{index}": lua.table_from({})
                    for index in range(1, len(perk_options) + 1)
                }
            )
        }
    )
    perk_grid_entry.bind(perk_grid_widget)
    perk_grid_entry.refresh(perk_grid_widget)
    assert perk_grid_widget.content.trait_target_1_index == 3
    assert perk_grid_widget.content.trait_target_2_index == 2
    assert perk_grid_widget.content.trait_label_3 == "+25% Damage vs Flak Armoured Enemies"
    perk_grid_widget.content.trait_right_callbacks[1]()
    perk_grid_entry.refresh(perk_grid_widget)
    assert lua.globals().TraitSettings["values"].auto_crafter_perk_2_target == "perk:content/items/perks/melee/unyielding_t4:4"
    assert perk_grid_widget.content.trait_target_1_index == 3
    assert perk_grid_widget.content.trait_target_2_index == 1

    blessing_options = trait_panel._trait_target_options(
        trait_panel, "auto_crafter_blessing_1_target"
    )
    assert blessing_options[1].icon == "content/ui/textures/icons/traits/test_blessing"

    lua.globals().TraitSettings["values"].auto_crafter_perk_1_target = "stale_melee_perk"
    lua.globals().TraitSettings["values"].auto_crafter_perk_2_target = "auto"
    trait_panel._plan = lua.table_from(
        {
            "trait_catalog": lua.table_from(
                {
                    "available": True,
                    "parent_pattern": "lasgun_p1",
                    "perks": lua.table_from(
                        [
                            lua.table_from(
                                {
                                    "id": "content/items/perks/ranged/flak_t4",
                                    "display_name": "+25% Damage vs Flak Armoured Enemies",
                                    "tier": 4,
									"trait": "weapon_trait_ranged_common_wield_increased_armored_damage",
                                }
                            ),
                            lua.table_from(
                                {
                                    "id": "content/items/perks/ranged/maniacs_t4",
                                    "display_name": "+25% Damage vs Maniacs",
                                    "tier": 4,
									"trait": "weapon_trait_ranged_common_wield_increased_berserker_damage",
                                }
                            ),
                        ]
                    ),
                    "blessings": lua.table_from([]),
                }
            )
        }
    )
    trait_panel._reconcile_trait_targets(trait_panel)
    assert lua.globals().TraitSettings["values"].auto_crafter_perk_1_target == "perk:content/items/perks/ranged/flak_t4:4"
    assert lua.globals().TraitSettings["values"].auto_crafter_perk_2_target == "perk:content/items/perks/ranged/maniacs_t4:4"

    lua.execute("RenderCalls = 0")
    trait_panel.render = lua.eval("function() RenderCalls = RenderCalls + 1 return true end")
    trait_panel.set_phase(trait_panel, "plan_preview")
    assert lua.globals().RenderCalls == 0
    assert trait_panel._layout_pending is True
    assert trait_panel._layout_defer_frames == 1

    panel_source = PANEL_PATH.read_text(encoding="utf-8") + PANEL_PATH.with_name("panel_blueprints.lua").read_text(encoding="utf-8")
    assert "length_scrolled" in panel_source
    assert "local CURRENCY_ROW_HEIGHT = 26" in panel_source
    assert 'size = { 18, 18 }' in panel_source
    assert '"Current resources", "wallet"' in panel_source
    assert '"Generous cost estimate", "generous"' in panel_source
    assert '"Unlucky cost estimate", "unlucky"' in panel_source
    assert '"Remaining (generous)", "remaining_generous"' in panel_source
    assert '"Remaining (unlucky)", "remaining_unlucky"' in panel_source
    assert "restore_scroll_offset" in panel_source
    assert "set_scrollbar_progress" in panel_source
    assert 'add_checkbox("auto_crafter_change_perks"' in panel_source
    assert 'self:_setting("auto_crafter_level_mastery_20", true) == true and self:_setting("auto_crafter_change_perks", true) == true' in panel_source
    assert "on_right_pressed" in panel_source
    assert 'add_checkbox("auto_crafter_show_perk_grid"' in panel_source
    assert 'add_checkbox("auto_crafter_show_blessing_grid"' in panel_source
    assert "SECTION_ADVANCED" not in panel_source
    assert "auto_crafter_panel_request_mode" not in panel_source
    assert 'localize("auto_crafter_panel_preview", "> CLICK HERE TO CRAFT <")' in panel_source
    assert 'localize("auto_crafter_panel_stop", "> CLICK HERE TO STOP / INTERRUPT <"), ""' in panel_source
    assert "local craft_enabled = not run_is_active() and not import_busy" in panel_source
    assert "selectable = stop_enabled" in panel_source
    assert "previous_active ~= workflow_active" in panel_source
    assert 'size = { width - 20, ROW_HEIGHT }' in panel_source
    assert "phase4 and phase4.running == true" in panel_source
    assert "auto_crafter_rename_result" not in panel_source
    assert "Resume matching dump stat weapon from inventory" in panel_source
    assert "Include favorited inventory weapons when resuming" in panel_source
    assert "Automatically favorite crafted weapon" in panel_source
    assert 'self:_setting("auto_crafter_favorite_result", true) == true and self:_myfavorites_available()' in panel_source
    assert 'localize("auto_crafter_myfavorites_color", "MyFavorites color")' in panel_source
    assert panel_source.index('add_checkbox("auto_crafter_favorite_result"') < panel_source.index('localize("auto_crafter_myfavorites_color", "MyFavorites color")') < panel_source.index('localize("auto_crafter_buy_until_target", "Base weapon acquisition")')
    assert "Automatically buy first weapon and proceed" in panel_source
    assert "Automatically buy until target stats weapon is found" in panel_source
    assert 'variant = "dump_target_stepper"' in panel_source
    assert 'variant = "acquisition_stepper"' in panel_source
    assert 'content_id = "comparison_hotspot"' in panel_source
    assert 'style_id = "comparison_arrow"' in panel_source
    assert "SECTION_RESUMING" in panel_source and "SECTION_OUTPUT" not in panel_source
    assert panel_source.index('add_checkbox("auto_crafter_favorite_result"') < panel_source.index('localize("auto_crafter_buy_until_target", "Base weapon acquisition")') < panel_source.index('localize("auto_crafter_panel_resuming"')
    assert "auto_crafter_panel_saved_only" not in panel_source and "auto_crafter_panel_not_connected" not in panel_source
    assert "Automatically consecrate weapon to Transcendent" in panel_source
    assert "Automatically upgrade weapon item level to 500" in panel_source
    assert panel_source.index('add_checkbox("auto_crafter_defer_bad_weapon_processing"') < panel_source.index('add_checkbox("auto_crafter_level_mastery_20"')
    backend_source = BACKEND_PATH.read_text(encoding="utf-8")
    assert "Items.trait_description" in backend_source
    assert "Items.trait_textures" in backend_source
    assert 'safe_member(perk_item, "description")' in backend_source
    assert 'safe_member(trait_item, "description")' in backend_source
    assert "tier == maximum_tier" in backend_source

    lua.execute("TraitLeftPresses = 0; TraitRightPresses = 0")
    both_press_flags = lua.table_from({"on_pressed": True, "on_right_pressed": True})
    left_callback = lua.eval("function() TraitLeftPresses = TraitLeftPresses + 1 end")
    right_callback = lua.eval("function() TraitRightPresses = TraitRightPresses + 1 end")
    assert panel_module.dispatch_trait_press(both_press_flags, left_callback, right_callback) is True
    assert lua.globals().TraitLeftPresses == 0
    assert lua.globals().TraitRightPresses == 1
    assert "BLESSING_ICON_MATERIAL" in panel_source
    assert "material_values.icon" in panel_source
    assert "material_values.frame" in panel_source

    controller_source = "\n".join(path.read_text(encoding="utf-8") for path in (RUNTIME_ROOT / "auto_crafter" / "core").glob("*.lua"))
    host_source = (RUNTIME_ROOT / "BetterInventory_auto_crafter.lua").read_text(encoding="utf-8")
    assert "DEFAULT_BLESSING_POLL_DELAY = 0.05" in controller_source
    assert "DEFAULT_MASTERY_POLL_DELAY = 0.05" in controller_source
    assert "auto_crafter_request_mode = true" in controller_source
    assert "MAX_PARALLEL_FODDER_UPGRADES = 1" in controller_source
    assert "phase4.allocate_mastery and unseen_blessing_tiers > 0" in controller_source
    assert "Allocating mastery blessing points (%d/%d)" in host_source
    assert "Invested: %s Ordo Dockets | %s Plasteel | %s Diamantine" in host_source
    assert "Final weapon crafting complete in " in host_source
    assert "presentation_dirty" in host_source
    assert "PRESENTATION_CLOCK_INTERVAL = 0.25" in host_source
    assert "if presentation_dirty or cached == nil or clock_due then" in host_source
    assert "INPUT_POLL_INTERVAL = 0.1" in panel_source
    assert "IDLE_POLL_INTERVAL = 0.5" in panel_source
    assert "DEFAULT_VIEW_IDLE_POLL_INTERVAL = 0.5" in controller_source

    print("Auto Crafter weapon stat catalogue and display-label tests passed.")


if __name__ == "__main__":
    main()

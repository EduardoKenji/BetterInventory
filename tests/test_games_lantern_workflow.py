from pathlib import Path

from coverage_support import InstrumentedLuaRuntime as LuaRuntime


PROJECT_ROOT = Path(__file__).resolve().parents[1]
RUNTIME_ROOT = PROJECT_ROOT / "scripts" / "mods" / "BetterInventory"
PARSER_PATH = RUNTIME_ROOT / "auto_crafter" / "games_lantern" / "parser.lua"
RESOLVER_PATH = RUNTIME_ROOT / "auto_crafter" / "games_lantern" / "resolver.lua"
FIXTURE_PATH = PROJECT_ROOT / "tests" / "fixtures" / "games_lantern_weapon_cards.html"


def main() -> None:
    lua = LuaRuntime(unpack_returned_tuples=True)

    def to_lua(value):
        if isinstance(value, dict):
            return lua.table_from({key: to_lua(item) for key, item in value.items()})
        if isinstance(value, list):
            return lua.table_from([to_lua(item) for item in value])
        return value

    parser = lua.execute(PARSER_PATH.read_text(encoding="utf-8"), name=str(PARSER_PATH))
    resolver = lua.execute(RESOLVER_PATH.read_text(encoding="utf-8"), name=str(RESOLVER_PATH))
    model = parser.parse(FIXTURE_PATH.read_text(encoding="utf-8"))

    melee_offer = to_lua(
        {
            "display_name": "Covenant Mk VI Blaze Force Greatsword",
            "master_id": "covenant_mk_vi_blaze_force_greatsword",
            "parent_pattern": "blaze_force_greatsword_pattern",
            "weapon_category": "melee",
            "base_stats": [
                    {"name": "warp_resist", "display_name_key": "Warp Resistance"},
                    {"name": "cleave_damage", "display_name_key": "Cleave Damage"},
                    {"name": "finesse", "display_name_key": "Finesse"},
                ],
        }
    )
    ranged_offer = to_lua(
        {
            "display_name": "Covenant Mk VI Trauma Force Staff",
            "master_id": "covenant_mk_vi_trauma_force_staff",
            "parent_pattern": "trauma_force_staff_pattern",
            "weapon_category": "ranged",
            "base_stats": [
                    {"name": "charge_speed", "display_name_key": "Charge Rate"},
                    {"name": "warp_resist", "display_name_key": "Warp Resistance"},
                    {"name": "blast_radius", "display_name_key": "Blast Radius"},
                ],
        }
    )

    def catalog_for_offer(offer):
        if offer["weapon_category"] == "melee":
            return to_lua(
                {
                    "available": True,
                    "perks": [
                            {"id": "perk_cara", "display_name": "Damage Carapace Armoured", "tier": 4},
                            {"id": "perk_unyielding", "display_name": "Damage Unyielding", "tier": 4},
                        ],
                    "blessings": [
                            {"id": "blessing_unstable_power", "display_name": "Unstable Power", "tiers": [{"tier": 4, "status": "seen"}]},
                            {"id": "blessing_riposte", "display_name": "Riposte", "tiers": [{"tier": 4, "status": "seen"}]},
                        ],
                }
            )
        return to_lua(
            {
                "available": True,
                "perks": [
                        {"id": "perk_cara", "display_name": "Damage Carapace Armoured", "tier": 4},
                        {"id": "perk_unyielding", "display_name": "Damage Unyielding", "tier": 4},
                    ],
                "blessings": [
                        {"id": "blessing_warp_nexus", "display_name": "Warp Nexus", "tiers": [{"tier": 4, "status": "seen"}]},
                        {"id": "blessing_surge", "display_name": "Surge", "tiers": [{"tier": 4, "status": "seen"}]},
                    ],
            }
        )

    catalog_callback = lua.eval(
        "function(callback) return function(offer) return callback(offer) end end"
    )(catalog_for_offer)
    context = to_lua(
        {
            "active_archetype": "psyker",
            "dump_target": 65,
            "melee_offers": [melee_offer],
            "ranged_offers": [ranged_offer],
            "catalog_for_offer": catalog_callback,
        }
    )
    resolved, reason = resolver.resolve(model, context)
    assert resolved is not None, reason
    assert resolved["resolver_contract_version"] == "games_lantern_resolver_v1"
    assert resolved["jobs"][1]["slot"] == "melee"
    assert resolved["jobs"][2]["slot"] == "ranged"
    assert resolved["jobs"][1]["dump_stat"] == "warp_resist"
    assert resolved["jobs"][1]["dump_target"] == 65
    assert resolved["jobs"][2]["dump_stat"] == "charge_speed"
    assert resolved["jobs"][1]["perks"][1]["id"] == "perk_cara"
    assert resolved["jobs"][1]["perks"][1]["rarity"] == 4
    assert resolved["jobs"][1]["blessings"][1]["rarity"] == 4
    assert resolved["jobs"][2]["blessings"][2]["id"] == "blessing_surge"

    # Five-stat cards preserve every exact projected value. Multiple equal low
    # stats are valid and no longer collapse into an ambiguous dump-stat error.
    plasma_offer = to_lua({
        "display_name": "Plasma Gun",
        "master_id": "plasmagun_p1_m1",
        "parent_pattern": "plasmagun_p1",
        "weapon_category": "ranged",
        "base_stats": [
            {"name": "charge_speed_stat", "display_name_key": "Charge Rate"},
            {"name": "ammo_stat", "display_name_key": "Ammo"},
            {"name": "power_stat", "display_name_key": "Stopping Power"},
            {"name": "heat_stat", "display_name_key": "Thermal Resistance"},
            {"name": "damage_stat", "display_name_key": "Damage"},
        ],
    })
    plasma_external = to_lua({
        "display_name": "Plasma Gun",
        "stats": [
            {"label": "Charge Rate", "value": 70}, {"label": "Ammo", "value": 80},
            {"label": "Stopping Power", "value": 80}, {"label": "Thermal Resistance", "value": 70},
            {"label": "Damage", "value": 80},
        ],
    })
    plasma_model = to_lua({"source_archetype": "veteran", "weapons": [model["weapons"][1], plasma_external]})
    plasma_context = to_lua({
        "active_archetype": "veteran", "melee_offers": [melee_offer], "ranged_offers": [plasma_offer]
    })
    plasma_identity, reason = resolver.resolve_identities(plasma_model, plasma_context)
    assert plasma_identity is not None, reason
    plasma_job = plasma_identity["jobs"][2]
    assert plasma_job["custom_stats_enabled"] is True
    assert plasma_job["custom_stat_total"] == 380
    assert [plasma_job["custom_stat_targets"][index]["value"] for index in range(1, 6)] == [70, 80, 80, 70, 80]
    assert plasma_job["dump_target"] == 70

    invalid_plasma = to_lua({
        "display_name": "Plasma Gun",
        "stats": [
            {"label": "Charge Rate", "value": 69}, {"label": "Ammo", "value": 80},
            {"label": "Stopping Power", "value": 80}, {"label": "Thermal Resistance", "value": 70},
            {"label": "Damage", "value": 80},
        ],
    })
    invalid_identity, invalid_reason = resolver.resolve_identities(
        to_lua({"source_archetype": "veteran", "weapons": [model["weapons"][1], invalid_plasma]}),
        plasma_context,
    )
    assert invalid_identity is None and invalid_reason == "custom_stats_invalid_total"

    # Public Games Lantern class slugs map to Darktide's internal archetype
    # IDs before enforcing the class safety gate.
    assert resolver.canonical_archetype("skitarii") == "cryptic"
    assert resolver.canonical_archetype("Skitarius") == "cryptic"
    assert resolver.canonical_archetype("arbites") == "adamant"
    assert resolver.canonical_archetype("hive_scum") == "broker"
    skitarius_model = to_lua({"source_archetype": "skitarii", "weapons": model["weapons"]})
    skitarius_context = to_lua({
        "active_archetype": "cryptic",
        "dump_target": 65,
        "melee_offers": [melee_offer],
        "ranged_offers": [ranged_offer],
    })
    assert resolver.resolve_identities(skitarius_model, skitarius_context)[0] is not None

    # Brunt's live offers are family-level and intentionally omit Games
    # Lantern's named mark. Both Skitarius weapons must still resolve without
    # weakening ambiguity handling.
    transonic_offer = to_lua({
        "display_name": "loc_weapon_family_transonic_sword_transonic_knife_p1_m1",
        "master_id": "content/items/weapons/player/melee/transonic_sword_transonic_knife_p1_m1",
        "parent_pattern": "transonic_sword_transonic_knife_p1_m1",
        "base_stats": [
            {"name": "transonic_sword_transonic_knife_p1_m1_cleave_damage_and_targets_stat", "display_name_key": "loc_stats_display_cleave_damage_and_targets_stat"},
            {"name": "damage", "display_name_key": "Damage"},
        ],
    })
    phosphor_offer = to_lua({
        "display_name": "loc_weapon_family_phosphor_pistol_p1_m1",
        "master_id": "content/items/weapons/player/ranged/phosphor_pistol_p1_m1",
        "parent_pattern": "phosphor_pistol_p1_m1",
        "base_stats": [
            {"name": "mobility", "display_name_key": "Mobility"},
            {"name": "damage", "display_name_key": "Damage"},
        ],
    })
    skitarius_live_model = to_lua({
        "source_archetype": "skitarii",
        "weapons": [
            {
                "display_name": "Branx Mk XI Paired Transonic Blades",
                "external_family_slug": "paired-transonic-blades",
                "external_mark_slug": "branx-mk-xi-paired-transonic-blades",
                "stats": [{"label": "Cleave Efficiency", "value": 60}, {"label": "Damage", "value": 80}],
            },
            {
                "display_name": "Branx Mk XI Phosphor Blast Pistol",
                "external_family_slug": "phosphor-blast-pistol",
                "external_mark_slug": "branx-mk-xi-phosphor-blast-pistol",
                "stats": [{"label": "Mobility", "value": 60}, {"label": "Damage", "value": 80}],
            },
        ],
    })
    skitarius_live_context = to_lua({
        "active_archetype": "cryptic",
        "dump_target": 60,
        "localize_offer_label": lua.eval("function(key) local labels = { loc_weapon_family_transonic_sword_transonic_knife_p1_m1 = 'Paired Transonic Blades', loc_weapon_family_phosphor_pistol_p1_m1 = 'Phosphor Blast Pistol' }; return labels[key] end"),
        "melee_offers": [transonic_offer],
        "ranged_offers": [phosphor_offer],
    })
    skitarius_identity, reason = resolver.resolve_identities(skitarius_live_model, skitarius_live_context)
    assert skitarius_identity is not None, reason
    assert skitarius_identity["jobs"][1]["master_id"].endswith("transonic_sword_transonic_knife_p1_m1")
    assert skitarius_identity["jobs"][2]["master_id"].endswith("phosphor_pistol_p1_m1")
    assert skitarius_identity["jobs"][1]["dump_stat"].endswith("cleave_damage_and_targets_stat")

    # Brunt's backend exposes one raw offer per mark while its native grid only
    # exposes one family representative. Bind both imported jobs to the visible
    # purchase offer without losing the exact Games Lantern mark.
    mark_binding = lua.eval(
        "function(offer, mark) local target = {}; for key, value in pairs(offer) do target[key] = value end; for key, value in pairs(mark) do target[key] = value end; target.family_mark_selection = true; return target end"
    )
    cleaver_mark = {
        "display_name": "Krourk Mk IV Cleaver",
        "master_id": "content/items/weapons/player/melee/ogryn_combatblade_p1_m3",
        "parent_pattern": "ogryn_combatblade_p1",
        "weapon_category": "melee",
        "base_stats": [
            {"name": "cleaver_m3_mobility", "display_name_key": "Mobility"},
            {"name": "cleaver_m3_damage", "display_name_key": "Damage"},
        ],
    }
    gauntlet_mark = {
        "display_name": "Blastoom Mk III Grenadier Gauntlet",
        "master_id": "content/items/weapons/player/ranged/ogryn_gauntlet_p1_m2",
        "parent_pattern": "ogryn_gauntlet_p1",
        "weapon_category": "ranged",
        "base_stats": [
            {"name": "gauntlet_m2_ammo", "display_name_key": "Ammo"},
            {"name": "gauntlet_m2_damage", "display_name_key": "Damage"},
        ],
    }
    visible_cleaver = dict(cleaver_mark, display_name="Cleaver", sub_display_name="Krourk Mk VI", master_id="content/items/weapons/player/melee/ogryn_combatblade_p1_m1", offer_id="visible-cleaver", marks=[cleaver_mark])
    hidden_cleaver = dict(cleaver_mark, offer_id="hidden-cleaver")
    visible_gauntlet = dict(gauntlet_mark, display_name="Grenadier Gauntlet", master_id="content/items/weapons/player/ranged/ogryn_gauntlet_p1_m1", offer_id="visible-gauntlet", marks=[gauntlet_mark])
    hidden_gauntlet = dict(gauntlet_mark, offer_id="hidden-gauntlet")
    ogryn_model = to_lua({
        "source_archetype": "ogryn",
        "weapons": [
            {
                "display_name": "Krourk Mk IV Cleaver",
                "external_family_slug": "cleaver",
                "external_mark_slug": "krourk-mk-iv-cleaver",
                "stats": [{"label": "Mobility", "value": 60}, {"label": "Damage", "value": 80}],
            },
            {
                "display_name": "Blastoom Mk III Grenadier Gauntlet",
                "external_family_slug": "grenadier-gauntlet",
                "external_mark_slug": "blastoom-mk-iii-grenadier-gauntlet",
                "stats": [{"label": "Ammo", "value": 60}, {"label": "Damage", "value": 80}],
            },
        ],
    })
    ogryn_context = to_lua({
        "active_archetype": "ogryn",
        "melee_offers": [visible_cleaver, hidden_cleaver],
        "ranged_offers": [visible_gauntlet, hidden_gauntlet],
        "offer_with_mark": mark_binding,
        "localize_offer_label": lua.eval("function(key) return '<unlocalized ' .. string.char(34) .. key .. string.char(34) .. ': string not found>' end"),
        "visible_offer_ids": {"visible-cleaver": True, "visible-gauntlet": True},
    })
    ogryn_identity, reason = resolver.resolve_identities(ogryn_model, ogryn_context)
    assert ogryn_identity is not None, reason
    assert ogryn_identity["jobs"][1]["offer"]["offer_id"] == "visible-cleaver"
    assert ogryn_identity["jobs"][1]["master_id"].endswith("ogryn_combatblade_p1_m3")
    assert ogryn_identity["jobs"][1]["offer"]["family_mark_selection"] is True
    assert ogryn_identity["jobs"][2]["offer"]["offer_id"] == "visible-gauntlet"
    assert ogryn_identity["jobs"][2]["master_id"].endswith("ogryn_gauntlet_p1_m2")
    assert ogryn_identity["jobs"][2]["offer"]["family_mark_selection"] is True
    assert ogryn_identity["jobs"][1]["mark_fallback"] is None

    # Unknown website marks fall back to the one native family offer instead
    # of rejecting the complete build or staging an unselectable raw offer.
    ogryn_model["weapons"][1]["display_name"] = "Mystery Mk Cleaver"
    ogryn_model["weapons"][1]["external_mark_slug"] = "mystery-mk-cleaver"
    fallback_identity, reason = resolver.resolve_identities(ogryn_model, ogryn_context)
    assert fallback_identity is not None, reason
    fallback_job = fallback_identity["jobs"][1]
    assert fallback_job["offer"]["offer_id"] == "visible-cleaver"
    assert fallback_job["offer"]["master_id"].endswith("ogryn_combatblade_p1_m1")
    assert fallback_job["offer"]["family_mark_selection"] is True
    assert fallback_job["display_name"] == "Cleaver • Krourk Mk VI"
    assert fallback_job["mark_fallback"]["requested"] == "Mystery Mk Cleaver"
    assert fallback_job["mark_fallback"]["selected"] == "Cleaver • Krourk Mk VI"
    assert fallback_job["mark_fallback"]["reason"] == "ambiguous_melee"

    # A future unknown mark can expose stats and traits that its native fallback
    # does not have. Keep malformed values fail-closed, but stage valid native
    # choices for schema drift and mark every adjustment for mandatory review.
    fallback_stats = [
        {"name": "mobility", "display_name_key": "Mobility"},
        {"name": "damage", "display_name_key": "Damage"},
        {"name": "first_target", "display_name_key": "First Target"},
        {"name": "penetration", "display_name_key": "Penetration"},
        {"name": "cleave", "display_name_key": "Cleave Damage"},
    ]
    ogryn_context["melee_offers"][1]["base_stats"] = to_lua(fallback_stats)
    ogryn_model["weapons"][1]["stats"] = to_lua([
        {"label": "Future Stat A", "value": 60},
        {"label": "Future Stat B", "value": 80},
        {"label": "Future Stat C", "value": 80},
        {"label": "Future Stat D", "value": 80},
        {"label": "Future Stat E", "value": 80},
    ])
    adjusted_identity, reason = resolver.resolve_identities(ogryn_model, ogryn_context)
    assert adjusted_identity is not None, reason
    adjusted_job = adjusted_identity["jobs"][1]
    assert adjusted_job["custom_stats_enabled"] is False
    assert adjusted_job["dump_stat"] == "mobility"
    assert adjusted_job["mark_fallback"]["adjustments"]["stats"] == "custom_stat_unavailable"

    ogryn_model["weapons"][1]["stats"][5]["value"] = 79
    invalid_fallback, invalid_reason = resolver.resolve_identities(ogryn_model, ogryn_context)
    assert invalid_fallback is None
    assert invalid_reason == "custom_stats_invalid_total"
    ogryn_model["weapons"][1]["stats"][5]["value"] = 80

    ogryn_model["weapons"][1]["perks"] = to_lua([{"label": "Future Perk A"}, {"label": "Future Perk B"}])
    ogryn_model["weapons"][1]["blessings"] = to_lua([{"label": "Future Blessing A"}, {"label": "Future Blessing B"}])
    ogryn_model["weapons"][2]["perks"] = to_lua([{"label": "Ranged Perk A"}, {"label": "Ranged Perk B"}])
    ogryn_model["weapons"][2]["blessings"] = to_lua([{"label": "Ranged Blessing A"}, {"label": "Ranged Blessing B"}])
    adjusted_identity, reason = resolver.resolve_identities(ogryn_model, ogryn_context)
    assert adjusted_identity is not None, reason
    adjusted_catalogs = to_lua({
        adjusted_identity["jobs"][1]["master_id"]: {
            "available": True,
            "perks": [{"id": "fallback_perk_a", "display_name": "Fallback Perk A", "tier": 4}, {"id": "fallback_perk_b", "display_name": "Fallback Perk B", "tier": 4}],
            "blessings": [{"id": "fallback_blessing_a", "display_name": "Fallback Blessing A", "tiers": [{"tier": 4}]}, {"id": "fallback_blessing_b", "display_name": "Fallback Blessing B", "tiers": [{"tier": 4}]}],
        },
        adjusted_identity["jobs"][2]["master_id"]: {
            "available": True,
            "perks": [{"id": "ranged_perk_a", "display_name": "Ranged Perk A", "tier": 4}, {"id": "ranged_perk_b", "display_name": "Ranged Perk B", "tier": 4}],
            "blessings": [{"id": "ranged_blessing_a", "display_name": "Ranged Blessing A", "tiers": [{"tier": 4}]}, {"id": "ranged_blessing_b", "display_name": "Ranged Blessing B", "tiers": [{"tier": 4}]}],
        },
    })
    adjusted_build, reason = resolver.attach_catalogs(adjusted_identity, adjusted_catalogs, ogryn_context)
    assert adjusted_build is not None, reason
    adjusted_job = adjusted_build["jobs"][1]
    assert adjusted_job["perks"][1]["id"] == "fallback_perk_a"
    assert adjusted_job["blessings"][1]["id"] == "fallback_blessing_a"
    assert adjusted_job["mark_fallback"]["adjustments"]["perks"] == "perk_unavailable_slot_1"
    assert adjusted_job["mark_fallback"]["adjustments"]["blessings"] == "blessing_unavailable_slot_1"

    # Live crafting catalogues expose perk master IDs plus localization keys,
    # while Games Lantern exposes rendered text. Blessings additionally expose
    # a numeric website icon ID that is embedded in Darktide's texture path.
    # Resolve both Skitarius jobs atomically using those runtime contracts.
    skitarius_identity["jobs"][1]["external"]["perks"] = to_lua([
        {"label": "10-25% Damage (Carapace Armoured Enemies)"},
        {"label": "10-25% Damage (Unyielding Enemies)"},
    ])
    skitarius_identity["jobs"][1]["external"]["blessings"] = to_lua([
        {"label": "Riposte", "external_icon_id": "064"},
        {"label": "Shred", "external_icon_id": "085"},
    ])
    skitarius_identity["jobs"][2]["external"]["perks"] = to_lua([
        {"label": "10-25% Damage (Flak Armoured Enemies)"},
        {"label": "10-25% Damage (Unyielding Enemies)"},
    ])
    skitarius_identity["jobs"][2]["external"]["blessings"] = to_lua([
        {"label": "Man-Stopper", "external_icon_id": "123"},
        {"label": "Surgical", "external_icon_id": "007"},
    ])
    trait_labels = {
        "loc_blessing_riposte": "Riposte",
        "loc_blessing_shred": "Shred",
        "loc_blessing_man_stopper": "Man-Stopper",
        "loc_blessing_surgical": "Surgical",
    }
    localize_traits = lua.eval(
        "function(callback) return function(key) return callback(key) end end"
    )(lambda key: trait_labels.get(key))
    live_catalogs = to_lua({
        transonic_offer["master_id"]: {
            "available": True,
            "perks": [
                {"id": "perk_carapace", "trait": "weapon_trait_melee_common_wield_increased_super_armor_damage", "tier": 4},
                {"id": "perk_unyielding", "trait": "weapon_trait_melee_common_wield_increased_resistant_damage", "tier": 4},
            ],
            "blessings": [
                {"id": "blessing_riposte", "display_name_key": "loc_blessing_riposte", "icon": "content/ui/textures/icons/traits/weapon_trait_064", "tiers": [{"tier": 4}]},
                {"id": "blessing_shred", "display_name_key": "loc_blessing_shred", "icon": "content/ui/textures/icons/traits/weapon_trait_085", "tiers": [{"tier": 4}]},
            ],
        },
        phosphor_offer["master_id"]: {
            "available": True,
            "perks": [
                {"id": "perk_flak", "trait": "weapon_trait_ranged_common_wield_increased_armored_damage", "tier": 4},
                {"id": "perk_unyielding", "trait": "weapon_trait_ranged_common_wield_increased_resistant_damage", "tier": 4},
            ],
            "blessings": [
                {"id": "blessing_man_stopper", "display_name_key": "loc_blessing_man_stopper", "icon": "content/ui/textures/icons/traits/weapon_trait_123", "tiers": [{"tier": 4}]},
                {"id": "blessing_surgical", "display_name_key": "loc_blessing_surgical", "icon": "content/ui/textures/icons/traits/weapon_trait_007", "tiers": [{"tier": 4}]},
            ],
        },
    })
    resolved_skitarius, reason = resolver.attach_catalogs(
        skitarius_identity,
        live_catalogs,
        to_lua({"localize_offer_label": localize_traits}),
    )
    assert resolved_skitarius is not None, reason
    assert resolved_skitarius["jobs"][1]["perks"][1]["id"] == "perk_carapace"
    assert resolved_skitarius["jobs"][2]["perks"][1]["id"] == "perk_flak"
    assert resolved_skitarius["jobs"][1]["blessings"][2]["id"] == "blessing_shred"
    assert resolved_skitarius["jobs"][2]["blessings"][1]["id"] == "blessing_man_stopper"

    # Games Lantern's current Hive Scum build renders the ranged crit perk as
    # "Increase Ranged Critical Strike Chance by 2-5%", while Darktide's live
    # catalogue identity uses "...wield_increased_crit_chance". Resolve that
    # wording drift by unique canonical family + ranged slot, never by guessing
    # across multiple mutation identities.
    crit_identity, reason = resolver.resolve_identities(skitarius_live_model, skitarius_live_context)
    assert crit_identity is not None, reason
    crit_identity["jobs"][2]["external"]["perks"] = to_lua([
        {"label": "10-25% Damage (Flak Armoured Enemies)"},
        {"label": "Increase Ranged Critical Strike Chance by 2-5%"},
    ])
    crit_identity["jobs"][2]["external"]["blessings"] = to_lua([
        {"label": "Man-Stopper", "external_icon_id": "123"},
        {"label": "Surgical", "external_icon_id": "007"},
    ])
    crit_catalogs = to_lua({
        transonic_offer["master_id"]: live_catalogs[transonic_offer["master_id"]],
        phosphor_offer["master_id"]: {
            "available": True,
            "perks": [
                {"id": "perk_flak", "trait": "weapon_trait_ranged_common_wield_increased_armored_damage", "tier": 4},
                {"id": "perk_crit", "trait": "weapon_trait_ranged_common_wield_increased_crit_chance", "tier": 4},
            ],
            "blessings": live_catalogs[phosphor_offer["master_id"]]["blessings"],
        },
    })
    resolved_crit, reason = resolver.attach_catalogs(
        crit_identity,
        crit_catalogs,
        to_lua({"localize_offer_label": localize_traits}),
    )
    assert resolved_crit is not None, reason
    assert resolved_crit["jobs"][2]["perks"][2]["id"] == "perk_crit"

    ambiguous_crit_catalogs = to_lua({
        transonic_offer["master_id"]: live_catalogs[transonic_offer["master_id"]],
        phosphor_offer["master_id"]: {
            "available": True,
            "perks": [
                {"id": "perk_flak", "trait": "weapon_trait_ranged_common_wield_increased_armored_damage", "tier": 4},
                {"id": "perk_crit_a", "trait": "weapon_trait_ranged_common_wield_increased_crit_chance", "tier": 4},
                {"id": "perk_crit_b", "trait": "weapon_trait_ranged_variant_wield_increased_crit_chance", "tier": 4},
            ],
            "blessings": live_catalogs[phosphor_offer["master_id"]]["blessings"],
        },
    })
    ambiguous_crit, ambiguous_crit_reason, _ = resolver.attach_catalogs(
        crit_identity,
        ambiguous_crit_catalogs,
        to_lua({"localize_offer_label": localize_traits}),
    )
    assert ambiguous_crit is None
    assert ambiguous_crit_reason == "perk_ambiguous_2"

    skitarius_live_model["weapons"][2]["perks"] = to_lua([
        {"label": "10-25% Damage (Flak Armoured Enemies)"},
        {"label": "10-25% Damage (Unyielding Enemies)"},
    ])
    skitarius_live_model["weapons"][2]["blessings"] = to_lua([
        {"label": "Man-Stopper", "external_icon_id": "123"},
        {"label": "Surgical", "external_icon_id": "007"},
    ])

    # Games Lantern renders both canonical stamina perks as "1-2 Stamina".
    # Live metadata can also repeat a canonical ID. Resolve by weapon slot,
    # collapse exact mutation duplicates, and retain fail-closed behavior for
    # genuinely different same-slot targets.
    stamina_identity, reason = resolver.resolve_identities(skitarius_live_model, skitarius_live_context)
    assert stamina_identity is not None, reason
    stamina_identity["jobs"][1]["external"]["perks"] = to_lua([
        {"label": "1-2 Stamina"},
        {"label": "10-25% Damage (Unyielding Enemies)"},
    ])
    stamina_identity["jobs"][1]["external"]["blessings"] = to_lua([
        {"label": "Riposte", "external_icon_id": "064"},
        {"label": "Shred", "external_icon_id": "085"},
    ])
    stamina_catalogs = to_lua({
        transonic_offer["master_id"]: {
            "available": True,
            "perks": [
                {"id": "perk_melee_stamina", "trait": "weapon_trait_increase_stamina", "display_name": "+2 Stamina", "tier": 4},
                {"id": "perk_melee_stamina", "trait": "weapon_trait_increase_stamina", "display_name": "+2 Stamina", "tier": 4},
                {"id": "perk_ranged_stamina", "trait": "weapon_trait_ranged_increase_stamina", "display_name": "+2 Stamina", "tier": 4},
                {"id": "perk_sprint", "trait": "weapon_trait_reduce_sprint_cost", "display_name": "+15% Sprint Efficiency (-15% Stamina Cost)", "tier": 4},
                {"id": "perk_unyielding", "trait": "weapon_trait_melee_common_wield_increased_resistant_damage", "tier": 4},
            ],
            "blessings": [
                live_catalogs[transonic_offer["master_id"]]["blessings"][1],
                live_catalogs[transonic_offer["master_id"]]["blessings"][1],
                live_catalogs[transonic_offer["master_id"]]["blessings"][2],
            ],
        },
        phosphor_offer["master_id"]: live_catalogs[phosphor_offer["master_id"]],
    })
    stamina_result, reason = resolver.attach_catalogs(
        stamina_identity,
        stamina_catalogs,
        to_lua({"localize_offer_label": localize_traits}),
    )
    assert stamina_result is not None, reason
    assert stamina_result["jobs"][1]["perks"][1]["id"] == "perk_melee_stamina"
    assert stamina_result["jobs"][1]["blessings"][1]["id"] == "blessing_riposte"

    ambiguous_identity, reason = resolver.resolve_identities(skitarius_live_model, skitarius_live_context)
    assert ambiguous_identity is not None, reason
    ambiguous_identity["jobs"][1]["external"]["perks"] = to_lua([
        {"label": "1-2 Stamina"},
        {"label": "10-25% Damage (Unyielding Enemies)"},
    ])
    ambiguous_identity["jobs"][1]["external"]["blessings"] = to_lua([
        {"label": "Riposte", "external_icon_id": "064"},
        {"label": "Shred", "external_icon_id": "085"},
    ])
    ambiguous_catalogs = to_lua({
        transonic_offer["master_id"]: {
            "available": True,
            "perks": [
                {"id": "perk_stamina_a", "display_name": "+2 Stamina", "tier": 4},
                {"id": "perk_stamina_b", "display_name": "+2 Stamina", "tier": 4},
                {"id": "perk_unyielding", "trait": "weapon_trait_melee_common_wield_increased_resistant_damage", "tier": 4},
            ],
            "blessings": live_catalogs[transonic_offer["master_id"]]["blessings"],
        },
        phosphor_offer["master_id"]: live_catalogs[phosphor_offer["master_id"]],
    })
    ambiguous_result, ambiguous_reason, ambiguous_detail = resolver.attach_catalogs(
        ambiguous_identity,
        ambiguous_catalogs,
        to_lua({"localize_offer_label": localize_traits}),
    )
    assert ambiguous_result is None
    assert ambiguous_reason == "perk_ambiguous_1"
    assert "perk_stamina_a" in ambiguous_detail
    assert "perk_stamina_b" in ambiguous_detail

    # Identity jobs retain the parsed external card by reference; restore the
    # shared fixture before the existing unavailable-target assertions.
    skitarius_identity["jobs"][1]["external"]["perks"] = to_lua([
        {"label": "10-25% Damage (Carapace Armoured Enemies)"},
        {"label": "10-25% Damage (Unyielding Enemies)"},
    ])
    skitarius_identity["jobs"][1]["external"]["blessings"] = to_lua([
        {"label": "Riposte", "external_icon_id": "064"},
        {"label": "Shred", "external_icon_id": "085"},
    ])

    missing_perk_catalogs = to_lua({
        transonic_offer["master_id"]: {
            "available": True,
            "perks": [{"id": "other", "description_key": "loc_other", "tier": 4}],
            "blessings": live_catalogs[transonic_offer["master_id"]]["blessings"],
        },
        phosphor_offer["master_id"]: live_catalogs[phosphor_offer["master_id"]],
    })
    missing_result, missing_reason, missing_detail = resolver.attach_catalogs(skitarius_identity, missing_perk_catalogs, to_lua({"localize_offer_label": localize_traits}))
    assert missing_result is None
    assert missing_reason == "perk_unavailable_slot_1_1"
    assert "target=10-25% Damage (Carapace Armoured Enemies)" in missing_detail
    assert "catalog=1" in missing_detail

    missing_blessing_catalogs = to_lua({
        transonic_offer["master_id"]: {
            "available": True,
            "perks": live_catalogs[transonic_offer["master_id"]]["perks"],
            "blessings": [{"id": "other", "display_name_key": "loc_other", "icon": "weapon_trait_999", "tiers": [{"tier": 4}]}],
        },
        phosphor_offer["master_id"]: live_catalogs[phosphor_offer["master_id"]],
    })
    missing_result, missing_reason, missing_detail = resolver.attach_catalogs(skitarius_identity, missing_blessing_catalogs, to_lua({"localize_offer_label": localize_traits}))
    assert missing_result is None
    assert missing_reason == "blessing_unavailable_slot_1_1"
    assert "target=Riposte" in missing_detail
    assert "catalog=1" in missing_detail

    bad_dump_model = to_lua({
        "source_archetype": "skitarii",
        "weapons": [
            {
                "display_name": "Branx Mk XI Paired Transonic Blades",
                "external_family_slug": "paired-transonic-blades",
                "external_mark_slug": "branx-mk-xi-paired-transonic-blades",
                "stats": [{"label": "Unknown Efficiency", "value": 60}, {"label": "Damage", "value": 80}],
            },
            skitarius_live_model["weapons"][2],
        ],
    })
    assert resolver.resolve_identities(bad_dump_model, skitarius_live_context)[1] == "dump_stat_unavailable"

    # Class mismatch, ambiguous marks, and tied dump stats must reject the
    # entire build rather than install one partially resolved job.
    wrong_class = to_lua(
        {
            "source_archetype": "veteran",
            "weapons": model["weapons"],
        }
    )
    result, reason = resolver.resolve(wrong_class, context)
    assert result is None
    assert reason == "archetype_mismatch"

    missing_class = to_lua({"weapons": model["weapons"]})
    result, reason = resolver.resolve(missing_class, context)
    assert result is None
    assert reason == "archetype_unavailable"

    duplicate_offer = to_lua(
        {
            "active_archetype": "psyker",
            "melee_offers": [melee_offer, melee_offer],
            "ranged_offers": [ranged_offer],
            "catalog_for_offer": catalog_callback,
        }
    )
    result, reason = resolver.resolve(model, duplicate_offer)
    assert result is None
    assert reason in {"ambiguous_melee", "multiple_melee_weapons"}

    tied_model = to_lua(
        {
            "source_archetype": "psyker",
            "weapons": [
                    {
                            "display_name": "Covenant Mk VI Blaze Force Greatsword",
                            "external_family_slug": "blaze-force-greatsword",
                            "external_mark_slug": "covenant-mk-vi",
                            "stats": [
                                    {"label": "Warp Resistance", "value": 0},
                                    {"label": "Cleave Damage", "value": 0},
                                ],
                            "perks": model["weapons"][1]["perks"],
                            "blessings": model["weapons"][1]["blessings"],
                        }
                ],
        }
    )
    result, reason = resolver.resolve(tied_model, context)
    assert result is None
    assert reason in {"dump_stat_tie", "melee_weapon_unavailable"}

    clone = lua.eval("function(value) local result = {}; for key, child in pairs(value) do result[key] = type(child) == 'table' and (function(v) local r = {}; for k, c in pairs(v) do r[k] = type(c) == 'table' and (function(v2) local r2 = {}; for k2, c2 in pairs(v2) do r2[k2] = c2 end; return r2 end)(c) or c end; return r end)(child) or child end; return result end")
    multi_model = to_lua({
        "source_archetype": "psyker",
        "weapons": [clone(model["weapons"][1]), clone(model["weapons"][1]), clone(model["weapons"][2])],
    })
    multi_model["weapons"][1]["card_index"] = 1
    multi_model["weapons"][2]["card_index"] = 2
    multi_model["weapons"][3]["card_index"] = 3
    result, reason, choices = resolver.resolve_identities(multi_model, context)
    assert result is None
    assert reason == "weapon_choice_required"
    assert len(choices["melee"]) == 2
    context["weapon_choices"] = to_lua({"melee": 2})
    selected = resolver.resolve_identities(multi_model, context)[0]
    assert selected["jobs"][1]["external"]["card_index"] == 2


if __name__ == "__main__":
    main()

from pathlib import Path

from coverage_support import InstrumentedLuaRuntime as LuaRuntime


PROJECT_ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = (
    PROJECT_ROOT
    / "scripts"
    / "mods"
    / "BetterInventory"
    / "BetterInventory_search_query.lua"
)


def main() -> None:
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute(
        r'''
        Utf8 = {
            lower = function(value) return string.lower(value) end,
            string_length = function(value) return #value end,
        }
        ''',
    )
    query = lua.execute(MODULE_PATH.read_text(encoding="utf-8"), name=str(MODULE_PATH))

    # Unicode helpers are optional and fail-soft. Non-string values normalize
    # without leaking an engine helper exception into a view.
    assert query.normalize(123)[0] == "123"
    lua.execute(
        "Utf8.lower = function() error('lower') end; "
        "Utf8.string_length = function() error('length') end"
    )
    assert query.normalize("ABC")[0] == "abc"
    assert query.compile("é", lua.table_from({"max_query_characters": 1})).valid is True
    lua.execute(
        "Utf8.lower = function(value) return string.lower(value) end; "
        "Utf8.string_length = function(value) return #value end"
    )
    lua.globals().Utf8 = None
    assert query.compile("é", lua.table_from({"max_query_characters": 1})).valid is True
    lua.execute(
        "Utf8 = {lower = function(value) return string.lower(value) end, "
        "string_length = function(value) return #value end}"
    )

    def compile_query(text, *, aliases=None, **limits):
        options = lua.table_from(limits)
        if aliases is not None:
            options.rarity_aliases = lua.table_from(aliases)
        return query.compile(text, options)

    def record(**fields):
        converted = {}
        for key, value in fields.items():
            converted[key] = lua.table_from(value) if isinstance(value, list) else value
        return lua.table_from(converted)

    plasma = record(
        text=["plasma gun mk ii", "power cycler", "transcendent"],
        name=["plasma gun mk ii"],
        blessing=["power cycler", "gets hot"],
        perk=["damage vs carapace enemies"],
        type=["ranged", "weapon"],
        mark=["mk ii", "ii"],
        rarity=["transcendent"],
        native_rarity=["transcendent", "5"],
        rating=500,
        base=380,
        favorite=True,
        equipped=False,
        new=False,
        loadout=True,
        perfect=False,
    )

    assert query.matches(compile_query(""), plasma) is True
    assert query.matches(compile_query("   &&  "), plasma) is True
    assert query.matches(compile_query("PLASMA"), plasma) is True
    assert query.matches(compile_query('name:"plasma gun"'), plasma) is True
    assert query.matches(compile_query("plasma & blessing:cycler"), plasma) is True
    assert query.matches(compile_query("plasma&bless:gets hot&perk:carapace"), plasma) is True
    assert query.matches(compile_query('name:"plasma & gun"'), plasma) is False
    assert query.matches(compile_query(r'name:"plasma \"gun\""'), plasma) is False
    assert query.matches(compile_query("foo:plasma"), plasma) is False

    # Every search token is literal; former Stuff Searcher Lua-pattern inputs
    # cannot throw or acquire pattern semantics.
    literals = record(text=["100% +damage (test) [x] ^$ .-*?"], name=["literal"])
    for token in ("100%", "+damage", "(test)", "[x]", "^$", ".-*?"):
        compiled = compile_query(token)
        assert compiled.valid is True
        assert query.matches(compiled, literals) is True

    # Effective rarity is separate from the underlying native rarity. A
    # Sainted item still has native Transcendent/5 metadata.
    sainted = record(
        text=["perfect sword", "sainted"],
        name=["perfect sword"],
        rarity=["sainted"],
        native_rarity=["transcendent", "5"],
    )
    transcendent = record(
        text=["ordinary sword", "transcendent"],
        name=["ordinary sword"],
        rarity=["transcendent"],
        native_rarity=["transcendent", "5"],
    )
    assert query.matches(compile_query("sainted"), sainted) is True
    assert query.matches(compile_query("sainted"), transcendent) is False
    assert query.matches(compile_query("transcendent"), transcendent) is True
    assert query.matches(compile_query("transcendent"), sainted) is False
    assert query.matches(compile_query("rarity:sainted"), sainted) is True
    assert query.matches(
        compile_query("rarity:sainted"), record(rarity="sainted")
    ) is True
    assert query.matches(compile_query("rarity:transcendent"), sainted) is False
    assert query.matches(compile_query("native-rarity:transcendent"), sainted) is True
    assert query.matches(compile_query("native-rarity:5"), sainted) is True

    custom_named = record(
        text=["sainted relic", "transcendent"],
        name=["sainted relic"],
        rarity=["transcendent"],
        native_rarity=["transcendent", "5"],
    )
    assert query.matches(compile_query("sainted"), custom_named) is False
    assert query.matches(compile_query("name:sainted"), custom_named) is True
    assert query.matches(compile_query("saint"), custom_named) is True

    localized = compile_query(
        "santificado",
        aliases={"santificado": "sainted", "transcendente": "transcendent"},
    )
    assert query.matches(localized, sainted) is True
    assert query.matches(compile_query("anointed"), record(rarity=["anointed"])) is True
    assert query.matches(compile_query("redeemed"), record(rarity=["redeemed"])) is True

    # Numeric searches compare fields, not substrings.
    assert query.matches(compile_query("rating:500"), plasma) is True
    assert query.matches(compile_query("rating:50"), plasma) is False
    assert query.matches(compile_query("rating:500"), record(text=[])) is False
    assert query.matches(compile_query("rating:>=490"), plasma) is True
    assert query.matches(compile_query("rating:<500"), plasma) is False
    assert query.matches(compile_query("rating:<=500"), plasma) is True
    assert query.matches(compile_query("rating:>499"), plasma) is True
    assert query.matches(compile_query("rating:>500"), plasma) is False
    assert query.matches(compile_query("quality:transcendent"), plasma) is True
    assert query.matches(compile_query("rating:480..500"), plasma) is True
    assert query.matches(compile_query("rating:510..490"), plasma) is True
    assert query.matches(compile_query("base:380"), plasma) is True
    assert query.matches(compile_query("500"), plasma) is True
    assert query.matches(compile_query("50"), plasma) is False

    assert query.matches(compile_query("favorite:true"), plasma) is True
    assert query.matches(compile_query("favourite:on"), plasma) is True
    assert query.matches(compile_query("equipped:false"), plasma) is True
    assert query.matches(compile_query("new:yes"), plasma) is False
    assert query.matches(compile_query("loadout:true"), plasma) is True
    assert query.matches(compile_query("perfect:true"), plasma) is False
    assert query.matches(compile_query("favorite:1"), plasma) is True
    assert query.matches(compile_query("equipped:off"), plasma) is True
    assert query.matches(compile_query("new:0"), plasma) is True

    # Curio line relevance is encoded as a cached rank: primary+secondary,
    # primary-only, then secondary-only. Equipped state and descending item
    # level are tie-breakers inside each tier, never stronger than relevance.
    health_query = compile_query("heal")

    def curio(*, equipped=False, primary=(), secondary=(), name="curio", rating=410):
        combined = [name, *primary, *secondary]
        return record(
            text=combined,
            perk=[*primary, *secondary],
            curio_primary=list(primary),
            curio_secondary=list(secondary),
            equipped=equipped,
            name=[name],
            rating=rating,
            type=["curio"],
        )

    equipped_both = curio(equipped=True, primary=("+17% health",), secondary=("+5% health",))
    equipped_primary = curio(equipped=True, primary=("+17% health",))
    equipped_secondary = curio(equipped=True, secondary=("+5% health",))
    unequipped_both = curio(primary=("+17% health",), secondary=("+5% health",), rating=430)
    unequipped_primary = curio(primary=("+17% health",))
    unequipped_secondary = curio(secondary=("+5% health",))
    name_only = curio(name="health relic")
    no_match = curio(name="toughness relic")
    ranked_curios = (
        equipped_both,
        equipped_primary,
        equipped_secondary,
        unequipped_both,
        unequipped_primary,
        unequipped_secondary,
        name_only,
        no_match,
    )
    curio_ranks = [query.rank(health_query, value, query.matches(health_query, value)) for value in ranked_curios]
    assert curio_ranks[0] > curio_ranks[3] > curio_ranks[1] > curio_ranks[4]
    assert curio_ranks[4] > curio_ranks[2] > curio_ranks[5] > curio_ranks[6] > curio_ranks[7]
    assert query.rank(health_query, equipped_both, True, False) < curio_ranks[0]
    assert query.rank(compile_query("name:health"), name_only, True) == 1
    health_rating_query = compile_query("heal & rating:>=400")
    assert query.rank(
        health_rating_query,
        equipped_primary,
        query.matches(health_rating_query, equipped_primary),
    ) > 0
    assert query.rank(None, equipped_both, True) == 1
    assert query.rank(health_query, equipped_both, False) > 0

    # Multi-term Curio ranking is lexicographic: matching line occurrences,
    # distinct clauses, primary-line coverage, then left-to-right query terms.
    sophisticated_query = compile_query("toughness & ability & revive")
    sophisticated_curios = (
        curio(primary=("toughness",), secondary=("toughness", "ability", "revive")),
        curio(primary=("toughness",), secondary=("ability", "revive")),
        curio(primary=("stamina",), secondary=("toughness", "ability", "revive")),
        curio(primary=("toughness",), secondary=("ability",)),
        curio(primary=("toughness",), secondary=("revive",)),
        curio(primary=("stamina",), secondary=("toughness", "ability")),
        curio(primary=("stamina",), secondary=("toughness", "revive")),
        curio(primary=("stamina",), secondary=("ability", "revive")),
        curio(primary=("stamina",), secondary=("toughness",)),
        curio(primary=("stamina",), secondary=("ability",)),
        curio(primary=("stamina",), secondary=("revive",)),
        curio(primary=("stamina",), secondary=("health",)),
    )
    sophisticated_ranks = [
        query.rank(
            sophisticated_query,
            value,
            query.matches(sophisticated_query, value),
        )
        for value in sophisticated_curios
    ]
    assert all(
        sophisticated_ranks[index] > sophisticated_ranks[index + 1]
        for index in range(len(sophisticated_ranks) - 1)
    ), sophisticated_ranks
    assert sophisticated_ranks[-1] == 0

    equipped_full_410 = curio(
        equipped=True,
        primary=("toughness",),
        secondary=("ability", "revive"),
        rating=410,
    )
    unequipped_full_430 = curio(
        primary=("toughness",),
        secondary=("ability", "revive"),
        rating=430,
    )
    unequipped_full_420 = curio(
        primary=("toughness",),
        secondary=("ability", "revive"),
        rating=420,
    )
    assert query.rank(sophisticated_query, equipped_full_410, True) > query.rank(
        sophisticated_query, unequipped_full_430, True
    )
    assert query.rank(sophisticated_query, unequipped_full_430, True) > query.rank(
        sophisticated_query, unequipped_full_420, True
    )

    # Weapons use distinct-clause count and the same left-to-right coverage,
    # followed by equipped state and item level, without Curio line semantics.
    weapon_query = compile_query("sword & uncanny & flak")

    def weapon(text, *, equipped=False, rating=500):
        return record(
            text=text.split(),
            name=[text],
            equipped=equipped,
            rating=rating,
        )

    weapon_all = weapon("sword uncanny flak")
    weapon_first_two = weapon("sword uncanny")
    weapon_first_third = weapon("sword flak")
    weapon_first = weapon("sword")
    weapon_none = weapon("axe")
    weapon_ranks = [
        query.rank(weapon_query, value, query.matches(weapon_query, value))
        for value in (weapon_all, weapon_first_two, weapon_first_third, weapon_first, weapon_none)
    ]
    assert weapon_ranks[0] > weapon_ranks[1] > weapon_ranks[2] > weapon_ranks[3] > weapon_ranks[4]
    assert weapon_ranks[4] == 0
    assert query.rank(weapon_query, weapon("sword uncanny", equipped=True, rating=410), False) > query.rank(
        weapon_query, weapon("sword uncanny", rating=430), False
    )

    # Runtime's combined evaluator must remain exactly equivalent to the
    # public match-then-rank contract while avoiding a second clause pass.
    evaluation_cases = (
        (compile_query(""), plasma),
        (compile_query("plasma & blessing:cycler"), plasma),
        (compile_query("plasma & blessing:missing"), plasma),
        (health_query, equipped_both),
        (health_query, no_match),
        (sophisticated_query, sophisticated_curios[0]),
        (sophisticated_query, sophisticated_curios[-1]),
        (weapon_query, weapon_all),
        (weapon_query, weapon_first_two),
        (weapon_query, weapon_none),
        (compile_query("rating:>=490"), plasma),
        (compile_query("favorite:true"), plasma),
        (compile_query('name:"unterminated'), plasma),
    )
    for compiled, value in evaluation_cases:
        legacy_match = query.matches(compiled, value)
        legacy_rank = query.rank(compiled, value, legacy_match)
        evaluated_match, evaluated_rank = query.evaluate(compiled, value)
        assert evaluated_match is legacy_match
        assert evaluated_rank == legacy_rank

    assert query.evaluate(health_query, equipped_both, False)[1] == query.rank(
        health_query, equipped_both, True, False
    )
    assert query.evaluate(weapon_query, None) == (False, 0)

    # Invalid or excessive input fails open, preserving the authoritative list.
    invalid_cases = (
        'name:"unterminated',
        'name:""',
        "rating:nope",
        "rating:>=",
        "rating:1..nope",
        "favorite:maybe",
    )
    for text in invalid_cases:
        compiled = compile_query(text)
        assert compiled.valid is False
        assert compiled.fail_open is True
        assert query.matches(compiled, plasma) is True

    assert compile_query("x" * 129).error == "query_too_long"
    assert compile_query("&".join(["x"] * 17)).error == "too_many_clauses"
    assert compile_query("a&b&", max_clauses=1).error == "too_many_clauses"
    assert compile_query("abc", max_query_characters=2).error == "query_too_long"
    assert query.matches(None, plasma) is True
    assert query.matches(compile_query("plasma"), None) is False

    # A bounded repeated compile/match soak leaves no record-owned state and
    # proves matching does not mutate the projection.
    before = plasma.text[1]
    for index in range(500):
        compiled = compile_query("plasma & rating:>=490" if index % 2 else "sainted")
        query.matches(compiled, plasma)
    assert plasma.text[1] == before

    print("BetterInventory search query tests passed.")


if __name__ == "__main__":
    main()

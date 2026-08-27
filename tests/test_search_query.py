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

    def compile_query(text, *, aliases=None, chips=None, **limits):
        options = lua.table_from(limits)
        if aliases is not None:
            options.rarity_aliases = lua.table_from(aliases)
        if chips is not None:
            options.chips = lua.table_from(
                [lua.table_from(chip) for chip in chips]
            )
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
    assert query.matches(compile_query("rating:>=490"), plasma) is True
    assert query.matches(compile_query("rating:<500"), plasma) is False
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
    assert query.matches(
        compile_query("plasma", chips=[{"field": "favorite", "value": True}]),
        plasma,
    ) is True
    assert query.matches(
        compile_query("plasma", chips=[{"field": "equipped", "value": True}]),
        plasma,
    ) is False

    # Invalid or excessive input fails open, preserving the authoritative list.
    invalid_cases = (
        'name:"unterminated',
        "rating:nope",
        "favorite:maybe",
    )
    for text in invalid_cases:
        compiled = compile_query(text)
        assert compiled.valid is False
        assert compiled.fail_open is True
        assert query.matches(compiled, plasma) is True

    assert compile_query("x" * 129).error == "query_too_long"
    assert compile_query("&".join(["x"] * 17)).error == "too_many_clauses"
    assert compile_query("abc", max_query_characters=2).error == "query_too_long"

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

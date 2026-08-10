from pathlib import Path

from lupa import LuaRuntime


PROJECT_ROOT = Path(__file__).resolve().parents[1]
RUNTIME_ROOT = PROJECT_ROOT / "scripts" / "mods" / "BetterInventory"
CLIPBOARD_PATH = RUNTIME_ROOT / "auto_crafter" / "games_lantern" / "clipboard.lua"
PARSER_PATH = RUNTIME_ROOT / "auto_crafter" / "games_lantern" / "parser.lua"
FIXTURE_PATH = PROJECT_ROOT / "tests" / "fixtures" / "games_lantern_weapon_cards.html"


def main() -> None:
    lua = LuaRuntime(unpack_returned_tuples=True)
    clipboard = lua.execute(CLIPBOARD_PATH.read_text(encoding="utf-8"), name=str(CLIPBOARD_PATH))
    parser = lua.execute(PARSER_PATH.read_text(encoding="utf-8"), name=str(PARSER_PATH))

    # Strict URL extraction accepts the copied slugged URL and only returns a
    # UUID-derived canonical URL.
    canonical = "https://darktide.gameslantern.com/builds/a0a667cd-4d49-4f68-8cf8-2f1ee57eab29"
    assert clipboard.extract_url(
        "Copied from Games Lantern: " + canonical + "/very-in-depth-guide?source=copy"
    ) == canonical
    assert clipboard.is_canonical_url(canonical) is True

    invalid_urls = [
        "http://darktide.gameslantern.com/builds/a0a667cd-4d49-4f68-8cf8-2f1ee57eab29",
        "https://darktide.gameslantern.com:443/builds/a0a667cd-4d49-4f68-8cf8-2f1ee57eab29",
        "https://darktide.gameslantern.com.evil.example/builds/a0a667cd-4d49-4f68-8cf8-2f1ee57eab29",
        "https://darktide.gameslantern.com/%62uilds/a0a667cd-4d49-4f68-8cf8-2f1ee57eab29",
        "https://darktide.gameslantern.com/builds/a0a667cd-4d49-4f68-8cf8-2f1ee57eab2x",
        "https://darktide.gameslantern.com/builds/a0a667cd-4d49-4f68-8cf8-2f1ee57eab29.evil",
    ]
    for value in invalid_urls:
        result, reason = clipboard.extract_url(value)
        assert result is None, (value, result, reason)
        assert reason is not None

    result, reason = clipboard.extract_url(canonical + " and " + canonical)
    assert result is None
    assert reason == "multiple_urls"
    result, reason = clipboard.extract_url("not a build URL")
    assert result is None
    assert reason == "missing_url"
    result, reason = clipboard.extract_url("x" * 4097)
    assert result is None
    assert reason == "clipboard_too_large"

    html = FIXTURE_PATH.read_text(encoding="utf-8")
    model = parser.parse(html)
    assert model is not None
    assert model["parser_contract_version"] == "games_lantern_html_v1"
    assert model["source_archetype"] == "psyker"
    assert len(model["weapons"]) == 2

    melee = model["weapons"][1]
    ranged = model["weapons"][2]
    assert melee["external_family_slug"] == "blaze-force-greatsword"
    assert melee["external_mark_slug"] == "covenant-mk-vi"
    assert melee["stats"][1]["value"] == 0
    assert melee["perks"][1]["label"] == "10-25% Damage (Carapace Armoured Enemies)"
    assert melee["blessings"][1]["external_icon_id"] == "064"
    assert ranged["external_family_slug"] == "force-staff"
    assert ranged["blessings"][2]["label"] == "Surge"

    # Parser drift and partial cards fail closed instead of producing a target
    # that later code could accidentally apply.
    broken = html.replace("weapon_trait_085.webp", "weapon_trait_missing.webp", 1)
    result, reason = parser.parse(broken)
    assert result is None
    assert reason in {"incomplete_weapon_traits", "invalid_blessing"}

    oversized = "x" * (2 * 1024 * 1024 + 1)
    result, reason = parser.parse(oversized)
    assert result is None
    assert reason == "response_too_large"

    challenge = "<html><body>Please log in and complete the captcha.</body></html>"
    result, reason = parser.parse(challenge)
    assert result is None
    assert reason == "unsupported_html_format"


if __name__ == "__main__":
    main()

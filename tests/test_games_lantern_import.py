from pathlib import Path

from coverage_support import InstrumentedLuaRuntime as LuaRuntime


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
    assert model["source_uuid"] is None
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

    canonical_html = html.replace(
        "</head>", f'<link rel="canonical" href="{canonical}/guide"/></head>'
    )
    assert parser.parse(canonical_html)["source_uuid"] == "a0a667cd-4d49-4f68-8cf8-2f1ee57eab29"
    ambiguous_class = html.replace("<main>", '<main><a href="/classes/veteran">Veteran</a>')
    assert parser.parse(ambiguous_class)["source_archetype"] is None

    # Current Games Lantern pages use a div weapons anchor and include the
    # Cloudflare challenge loader even after serving the complete build HTML.
    current_page = html.replace("<section id=\"weapons\">", '<div class="mt-8 mb-4" id="weapons">').replace("</section>", "</div>", 1)
    current_page = current_page.replace('href="/classes/psyker"', 'href="https://darktide.gameslantern.com/builds/psyker"')
    current_page += '<script src="/cdn-cgi/challenge-platform/scripts/jsd/main.js"></script>'
    assert parser.parse(current_page)["source_archetype"] == "psyker"
    assert len(parser.parse(current_page)["weapons"]) == 2

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
    assert reason == "login_or_challenge_page"

    result, reason = parser.parse(html.replace('id="weapons"', 'id="recommendations"', 1))
    assert result is None
    assert reason == "weapons_section_unavailable"

    duplicated_stat = html.replace(
        "Cleave Damage</div>", "Warp Resistance</div>", 1
    )
    result, reason = parser.parse(duplicated_stat)
    assert result is None
    assert reason == "duplicate_stat"


if __name__ == "__main__":
    main()

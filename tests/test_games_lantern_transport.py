from pathlib import Path

from lupa import LuaRuntime


PROJECT_ROOT = Path(__file__).resolve().parents[1]
TRANSPORT_PATH = PROJECT_ROOT / "scripts" / "mods" / "BetterInventory" / "auto_crafter" / "games_lantern" / "transport.lua"
WINDOWS_ADAPTER_PATH = PROJECT_ROOT / "scripts" / "mods" / "BetterInventory" / "auto_crafter" / "games_lantern" / "transport_win.lua"
WINE_ADAPTER_PATH = PROJECT_ROOT / "scripts" / "mods" / "BetterInventory" / "auto_crafter" / "games_lantern" / "transport_wine.lua"


def main() -> None:
    lua = LuaRuntime(unpack_returned_tuples=True)
    transport_module = lua.execute(TRANSPORT_PATH.read_text(encoding="utf-8"), name=str(TRANSPORT_PATH))
    url = "https://darktide.gameslantern.com/builds/00000000-0000-0000-0000-000000000000"

    assert transport_module._test.canonical_url(url) is True
    assert transport_module._test.canonical_url(url + "/extra") is False
    assert transport_module._test.canonical_url("https://evil.example/builds/00000000-0000-0000-0000-000000000000") is False
    assert transport_module._test.trusted_effective_url(url, url) is True
    assert transport_module._test.trusted_effective_url(url, url + "/safe-build-slug-2") is True
    assert transport_module._test.trusted_effective_url(url, url + "/bad?query") is False
    assert transport_module._test.trusted_effective_url(url, url[:-1] + "1/changed-build") is False
    assert transport_module._test.trusted_effective_url(url, "https://example.com/builds/" + url.rsplit("/", 1)[-1]) is False

    def callback_wrapper(callback):
        return lua.eval("function(callback) return function(...) return callback(...) end end")(callback)

    clock = [0.0]
    responses = [{"done": False}]
    spawned = []
    cleaned = []
    reports = []
    report_payloads = []

    def spawn(raw_url, generation, max_bytes):
        spawned.append((str(raw_url), int(generation), int(max_bytes)))
        return {"generation": int(generation)}

    def poll(handle, generation, max_bytes):
        return responses.pop(0) if responses else {"done": False}

    adapter = lua.table_from(
        {
            "spawn": callback_wrapper(spawn),
            "poll": callback_wrapper(poll),
            "cleanup": callback_wrapper(lambda handle: cleaned.append(handle["generation"]) or True),
        }
    )
    transport = transport_module.new(
        lua.table_from(
            {
                "adapter": adapter,
                "clock": callback_wrapper(lambda: clock[0]),
                "report": callback_wrapper(
                    lambda kind, payload: (
                        reports.append(str(kind)),
                        report_payloads.append(
                            {
                                "generation": payload["generation"],
                                "status": payload["status"],
                                "bytes": payload["bytes"],
                            }
                        ),
                    )
                ),
                "timeout_seconds": 20,
                "max_bytes": 10,
            }
        )
    )

    assert transport.start(transport, url)[0] is True
    assert transport.update(transport) == "running"
    clock[0] = 21
    assert transport.update(transport) == "failed"
    assert transport.snapshot(transport)["last_error"] == "transport_timeout"
    assert cleaned == [1]

    # HTTP errors and oversized bodies fail closed without returning content.
    clock[0] = 0
    responses[:] = [{"done": True, "status": 503, "content_type": "text/html", "effective_url": url, "exit_code": 0, "body": "backend", "bytes": 7}]
    assert transport.start(transport, url)[0] is True
    assert transport.update(transport) == "failed"
    assert transport.snapshot(transport)["last_error"] == "transport_http_status"
    assert report_payloads[-1] == {"generation": 2, "status": 503, "bytes": 7}

    responses[:] = [{"done": True, "status": 200, "content_type": "text/html", "effective_url": url, "exit_code": 0, "body": "01234567890", "bytes": 11}]
    assert transport.start(transport, url)[0] is True
    assert transport.update(transport) == "failed"
    assert transport.snapshot(transport)["last_error"] == "transport_response_too_large"

    responses[:] = [{"done": True, "status": 200, "content_type": "application/json", "effective_url": url, "exit_code": 0, "body": "{}", "bytes": 2}]
    assert transport.start(transport, url)[0] is True
    assert transport.update(transport) == "failed"
    assert transport.snapshot(transport)["last_error"] == "transport_content_type"

    responses[:] = [{"done": True, "status": 200, "content_type": "text/html", "effective_url": "https://example.com/redirected", "exit_code": 0, "body": "<ok>", "bytes": 4}]
    assert transport.start(transport, url)[0] is True
    assert transport.update(transport) == "failed"
    assert transport.snapshot(transport)["last_error"] == "transport_redirect_target"

    responses[:] = [{"done": True, "status": 200, "content_type": "text/html", "effective_url": url + "/safe-build-slug", "exit_code": 0, "body": "<ok>", "bytes": 4}]
    assert transport.start(transport, url)[0] is True
    assert transport.update(transport) == "complete"
    result = transport.take_result(transport)
    assert result["status"] == 200
    assert result["body"] == "<ok>"
    assert result["effective_url"] == url + "/safe-build-slug"
    assert transport.snapshot(transport)["state"] == "idle"

    # A new paste cancels the old generation, and explicit cancel cleans it.
    assert transport.start(transport, url)[0] is True
    old_generation = transport.snapshot(transport)["generation"]
    assert transport.cancel(transport, "new_paste") is True
    assert transport.snapshot(transport)["state"] == "cancelled"
    assert transport.snapshot(transport)["generation"] > old_generation
    assert "transport_cancelled" in reports

    assert transport.start(transport, "https://darktide.gameslantern.com/builds/bad")[0] is False

    # Adapter start failures preserve their actionable reason, while the
    # Both launchers follow only a bounded number of HTTPS redirects, report
    # the final URL for coordinator validation, and keep Windows batch percent
    # escaping intact.
    failed = transport_module.new(lua.table_from({"adapter": lua.table_from({})}))
    failed._adapter.spawn = lua.eval("function() return nil, 'process_spawn_failed' end")
    assert failed.start(failed, url)[0] is False
    assert failed.snapshot(failed)["last_error"] == "process_spawn_failed"
    windows_source = WINDOWS_ADAPTER_PATH.read_text(encoding="utf-8")
    wine_source = WINE_ADAPTER_PATH.read_text(encoding="utf-8")
    windows_adapter = lua.execute(windows_source, name=str(WINDOWS_ADAPTER_PATH))
    wine_adapter = lua.execute(wine_source, name=str(WINE_ADAPTER_PATH))
    for source in (windows_source, wine_source):
        assert "--location" in source
        assert "--max-redirs " in source and "MAX_REDIRECTS = 3" in source
        assert "proto-redir" in source and "=https" in source
        assert "url_effective" in source and "effective_url = effective_url" in source
    for adapter_module, line_endings in ((windows_adapter, "\r\n"), (wine_adapter, "\n")):
        status, content_type, effective_url = adapter_module._test.parse_status_text(
            line_endings.join(("200", "text/html; charset=utf-8", url + "/safe-build-slug"))
        )
        assert status == 200
        assert content_type == "text/html"
        assert effective_url == url + "/safe-build-slug"
        assert adapter_module._test.parse_status_text("302\ntext/html")[0] is None
    assert r"%%%%{http_code}\\n%%%%{content_type}\\n%%%%{url_effective}" in windows_source
    assert "api.popen(powershell .." in windows_source


if __name__ == "__main__":
    main()

"""Monkey-patch aiohttp for python-engineio compatibility."""
import aiohttp

if not hasattr(aiohttp, "ClientWSTimeout"):
    from collections import namedtuple
    aiohttp.ClientWSTimeout = namedtuple(  # type: ignore[attr-defined]
        "ClientWSTimeout",
        ["ws_close", "ws_receive"],
        defaults=[None, None],
    )

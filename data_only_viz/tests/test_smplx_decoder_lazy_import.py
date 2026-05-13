"""smplx_decoder must be importable even when torch is missing."""

import sys
from unittest.mock import patch


def test_module_imports_without_torch(monkeypatch):
    # Make any 'torch' import fail at the module level
    real_import = __builtins__["__import__"] if isinstance(__builtins__, dict) else __builtins__.__import__

    def fake_import(name, *args, **kwargs):
        if name == "torch" or name.startswith("torch."):
            raise ImportError("torch unavailable in this test")
        return real_import(name, *args, **kwargs)

    monkeypatch.setattr("builtins.__import__", fake_import)
    # Drop a cached copy so we re-import fresh
    sys.modules.pop("data_only_viz.smplx_decoder", None)
    # This import must NOT raise:
    import data_only_viz.smplx_decoder  # noqa: F401

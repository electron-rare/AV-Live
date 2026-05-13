"""pytest configuration: ensure package root is on sys.path for test imports."""
import sys
from pathlib import Path

# Add the parent of data_only_viz/ to sys.path so that
# "from data_only_viz.xxx import ..." works at module-level in test files.
_parent = str(Path(__file__).resolve().parent.parent.parent)
if _parent not in sys.path:
    sys.path.insert(0, _parent)

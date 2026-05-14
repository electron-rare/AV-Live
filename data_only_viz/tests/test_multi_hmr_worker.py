"""MultiHMRWorker availability and thread-safety invariants."""

from pathlib import Path
import re


def test_is_available_returns_false_when_checkpoint_missing(tmp_path, monkeypatch):
    from data_only_viz import multi_hmr_worker

    # All three resources point at non-existent paths
    monkeypatch.setattr(multi_hmr_worker, "CKPT", tmp_path / "missing-ckpt.pt")
    monkeypatch.setattr(multi_hmr_worker, "SMPLX_PATH", tmp_path / "missing-smplx")
    monkeypatch.setattr(multi_hmr_worker, "MULTIHMR_REPO", tmp_path / "missing-repo")

    assert multi_hmr_worker.MultiHMRWorker.is_available() is False


def test_is_available_returns_true_when_all_paths_present(tmp_path, monkeypatch):
    from data_only_viz import multi_hmr_worker

    # Materialize all three paths
    ckpt = tmp_path / "fake.pt"
    ckpt.write_bytes(b"")
    smplx_dir = tmp_path / "smplx"
    smplx_dir.mkdir()
    repo_dir = tmp_path / "repo"
    repo_dir.mkdir()

    monkeypatch.setattr(multi_hmr_worker, "CKPT", ckpt)
    monkeypatch.setattr(multi_hmr_worker, "SMPLX_PATH", smplx_dir)
    monkeypatch.setattr(multi_hmr_worker, "MULTIHMR_REPO", repo_dir)

    assert multi_hmr_worker.MultiHMRWorker.is_available() is True


def test_state_mutations_are_all_under_lock():
    """Static grep: every assignment to state.persons_smplx is preceded by `with state.lock()`."""
    src = (Path(__file__).parent.parent / "multi_hmr_worker.py").read_text()
    lines = src.splitlines()
    assign_indices = [
        i + 1
        for i, line in enumerate(lines)
        if re.search(r"\bstate\.persons_smplx\s*=", line)
    ]
    assert assign_indices, "expected at least one persons_smplx assignment in multi_hmr_worker.py"

    for lineno in assign_indices:
        # Walk backwards up to 20 lines, looking for a `with self.state.lock():` context
        window = lines[max(0, lineno - 20):lineno]
        assert any("state.lock()" in w for w in window), (
            f"line {lineno} mutates persons_smplx without a nearby `state.lock()` context:\n"
            f"{lines[lineno - 1]}"
        )


def test_predict_once_returns_none_when_coreml_unavailable(monkeypatch):
    from data_only_viz.multi_hmr_worker import MultiHMRWorker
    from data_only_viz.state import State
    # Force CoreML loader to return None
    state = State()
    worker = MultiHMRWorker(state, num_persons=1)
    monkeypatch.setattr(worker, "_get_or_load_coreml_backend", lambda: None)
    import pytest, numpy as np
    rgb = np.zeros((480, 640, 3), dtype=np.uint8)
    with pytest.raises(NotImplementedError):
        worker.predict_once(rgb)

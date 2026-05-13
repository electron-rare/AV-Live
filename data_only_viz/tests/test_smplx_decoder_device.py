"""SMPLXDecoder must validate device and fall back to CPU when MPS unavailable."""

import sys
from types import ModuleType
from unittest.mock import MagicMock, patch


def _make_smplx_mock():
    """Return a fake smplx module whose SMPLXLayer is chainable."""
    mock_smplx = ModuleType("smplx")
    layer = MagicMock()
    layer.to.return_value = layer
    layer.eval.return_value = layer
    mock_smplx.SMPLXLayer = MagicMock(return_value=layer)
    return mock_smplx, layer


def test_decoder_falls_back_to_cpu_when_mps_unavailable(tmp_path):
    mock_smplx, layer = _make_smplx_mock()

    with patch.dict(sys.modules, {"smplx": mock_smplx}):
        from data_only_viz import smplx_decoder

        with patch.object(smplx_decoder, "_require_torch") as mock_require:
            fake_torch = mock_require.return_value
            fake_torch.backends.mps.is_available.return_value = False
            fake_torch.cuda.is_available.return_value = False

            dec = smplx_decoder.SMPLXDecoder(model_path=tmp_path, device="mps")

            # The decoder must NOT have called .to("mps") — it must have demoted to "cpu":
            layer.to.assert_called_with("cpu")
            assert dec.device == "cpu"


def test_decoder_keeps_cpu_device(tmp_path):
    mock_smplx, layer = _make_smplx_mock()

    with patch.dict(sys.modules, {"smplx": mock_smplx}):
        from data_only_viz import smplx_decoder

        with patch.object(smplx_decoder, "_require_torch") as mock_require:
            fake_torch = mock_require.return_value
            fake_torch.backends.mps.is_available.return_value = False
            fake_torch.cuda.is_available.return_value = False

            dec = smplx_decoder.SMPLXDecoder(model_path=tmp_path, device="cpu")
            assert dec.device == "cpu"
            layer.to.assert_called_with("cpu")

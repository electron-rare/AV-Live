"""Shims mmcv 1.x API surface pour SMPLer-X vendored mmpose.

mmcv-lite 2.x a migré la plupart des symboles vers mmengine ;
SMPLer-X est écrit pour mmcv-full 1.x. Cette module ré-exporte
les symboles 1.x sous leur ancien chemin avant qu'on importe la
vendored mmpose.

Appel : `from data_only_viz._smplerx_shims import install_all`
puis `install_all()` AVANT tout `import mmpose`.
"""
from __future__ import annotations

import sys
import time
import types
import warnings


def _no_op_decorator(*args, **kwargs):
    """Décorateur no-op : remplace deprecated_api_warning."""
    if len(args) == 1 and callable(args[0]):
        return args[0]
    def wrap(fn):
        return fn
    return wrap


class _SimpleTimer:
    """Timer minimal compat mmcv.Timer 1.x."""
    def __init__(self, start: bool = True):
        self._start = time.perf_counter() if start else None

    def start(self):
        self._start = time.perf_counter()

    def since_start(self):
        return time.perf_counter() - (self._start or time.perf_counter())

    def since_last_check(self):
        now = time.perf_counter()
        d = now - (self._start or now)
        self._start = now
        return d


def _is_seq_of(seq, expected_type, seq_type=None):
    """mmcv.is_seq_of -> mmengine.utils.is_seq_of (parfois absent)."""
    if seq_type is None:
        exp_seq_type = (list, tuple)
    else:
        exp_seq_type = seq_type
    if not isinstance(seq, exp_seq_type):
        return False
    return all(isinstance(item, expected_type) for item in seq)


def install_all() -> None:
    """Installer tous les shims sur mmcv pour compat 1.x API."""
    import mmcv

    # --- top-level symbols ---
    if not hasattr(mmcv, "Config"):
        from mmengine.config import Config
        mmcv.Config = Config

    if not hasattr(mmcv, "deprecated_api_warning"):
        mmcv.deprecated_api_warning = _no_op_decorator

    if not hasattr(mmcv, "Timer"):
        mmcv.Timer = _SimpleTimer

    if not hasattr(mmcv, "is_seq_of"):
        try:
            from mmengine.utils import is_seq_of
            mmcv.is_seq_of = is_seq_of
        except Exception:
            mmcv.is_seq_of = _is_seq_of

    # --- mmcv.cnn symbols ---
    import mmcv.cnn as _cnn

    # Init functions migrated to mmengine.model.weight_init
    try:
        from mmengine.model import (
            constant_init, normal_init, kaiming_init,
            trunc_normal_init, xavier_init, bias_init_with_prob,
        )
    except ImportError:
        # Fallback : implémentations minimales locales
        import torch.nn as nn

        def constant_init(module, val=0, bias=0):
            if hasattr(module, 'weight') and module.weight is not None:
                nn.init.constant_(module.weight, val)
            if hasattr(module, 'bias') and module.bias is not None:
                nn.init.constant_(module.bias, bias)

        def normal_init(module, mean=0, std=1, bias=0):
            if hasattr(module, 'weight') and module.weight is not None:
                nn.init.normal_(module.weight, mean, std)
            if hasattr(module, 'bias') and module.bias is not None:
                nn.init.constant_(module.bias, bias)

        def kaiming_init(module, a=0, mode='fan_out',
                         nonlinearity='relu', bias=0, distribution='normal'):
            if hasattr(module, 'weight') and module.weight is not None:
                if distribution == 'normal':
                    nn.init.kaiming_normal_(module.weight, a=a, mode=mode,
                                            nonlinearity=nonlinearity)
                else:
                    nn.init.kaiming_uniform_(module.weight, a=a, mode=mode,
                                             nonlinearity=nonlinearity)
            if hasattr(module, 'bias') and module.bias is not None:
                nn.init.constant_(module.bias, bias)

        def trunc_normal_init(module, mean=0, std=1, a=-2, b=2, bias=0):
            if hasattr(module, 'weight') and module.weight is not None:
                nn.init.trunc_normal_(module.weight, mean, std, a, b)
            if hasattr(module, 'bias') and module.bias is not None:
                nn.init.constant_(module.bias, bias)

        def xavier_init(module, gain=1, bias=0, distribution='normal'):
            if hasattr(module, 'weight') and module.weight is not None:
                if distribution == 'normal':
                    nn.init.xavier_normal_(module.weight, gain)
                else:
                    nn.init.xavier_uniform_(module.weight, gain)
            if hasattr(module, 'bias') and module.bias is not None:
                nn.init.constant_(module.bias, bias)

        def bias_init_with_prob(prior_prob):
            import math
            return float(-math.log((1 - prior_prob) / prior_prob))

    for name, fn in {
        "constant_init": constant_init,
        "normal_init": normal_init,
        "kaiming_init": kaiming_init,
        "trunc_normal_init": trunc_normal_init,
        "xavier_init": xavier_init,
        "bias_init_with_prob": bias_init_with_prob,
    }.items():
        if not hasattr(_cnn, name):
            setattr(_cnn, name, fn)

    # Linear / Conv2d / MaxPool2d : juste re-export torch.nn
    import torch.nn as _nn
    for name, cls in {
        "Linear": _nn.Linear,
        "Conv2d": _nn.Conv2d,
        "MaxPool2d": _nn.MaxPool2d,
    }.items():
        if not hasattr(_cnn, name):
            setattr(_cnn, name, cls)

    # build_model_from_cfg : si mmcv.cnn ne l'expose pas, prendre de
    # mmengine.registry.build_model_from_cfg
    if not hasattr(_cnn, "build_model_from_cfg"):
        try:
            from mmengine.registry import build_model_from_cfg
            _cnn.build_model_from_cfg = build_model_from_cfg
        except ImportError:
            pass

    # MODELS export : SMPLer-X importe `from mmcv.cnn import MODELS as
    # MMCV_MODELS`. mmcv 2.x a son MODELS dans mmcv.cnn.
    if not hasattr(_cnn, "MODELS"):
        try:
            from mmengine.registry import MODELS
            _cnn.MODELS = MODELS
        except ImportError:
            pass


__all__ = ["install_all"]

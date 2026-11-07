---
name: av-live-validation-baseline
description: Commandes de validation AV-Live (Python/Swift/C++) + échec de test connu accepté comme baseline (pas une régression)
metadata:
  type: project
---

Baseline de validation pour le repo AV-Live (multi-sous-projets : data_only_viz Python, launcher Swift, oscope-of/oscope-sphere C++ openFrameworks).

**Commandes de validation qui marchent dans cet env (macOS, pas de coreutils → `timeout` absent, `python` absent, utiliser `/opt/homebrew/bin/python3` ou `uv`) :**
- Python compile : `cd data_only_viz && /opt/homebrew/bin/python3 -m py_compile *.py scripts/*.py tests/*.py`
- Python tests : `cd data_only_viz && uv run --no-sync python -m pytest tests/ -q --ignore=tests/test_multihmr_remote.py` → attendu ~135 passed, 12 skipped (skips = deps coreml/torch lourdes absentes, normal).
- Swift : `cd launcher && swift build` → ~8s, build complet. `_archive-AV-Live-Body/` est HORS target (Package.swift ne pointe que `Sources/AVLiveLauncher`).
- C++ autonome : `bash oscope-sphere/tests/run_tests.sh` → 16/16 (analysis 5/5, spectrogram 5/5, demo 6/6), NE nécessite PAS openFrameworks.

**Échec de test PRÉ-EXISTANT (baseline accepté, PAS une régression) :**
`tests/test_multihmr_remote.py` ne collecte pas → `ImportError: cannot import name 'REQ_PAYLOAD_LEN' from data_only_viz.multihmr_remote`. Le module définit `RSP_PAYLOAD_LEN` mais jamais `REQ_PAYLOAD_LEN`. Introduit par le commit feat/action-head (`9838da3`/`c5941b9`), indépendant de tout merge ultérieur.
**Why:** lors d'une validation de merge le 2026-06-23, ce test était déjà cassé avant le merge (vérifié via `git diff <pre-merge>^ HEAD` = fichiers identiques) → ne jamais l'imputer à un changement récent sans revérifier l'historique.
**How to apply:** exclure ce test des runs (`--ignore`), ou le signaler comme dette connue. Si quelqu'un demande de le réparer : `REQ_PAYLOAD_LEN` est ambigu car le payload requête est variable (raw vs JPEG) — clarifier le protocole avec l'auteur, ne pas inventer une constante.

**openFrameworks non installé dans cet env :** `OF_ROOT = ../../..` dans les `config.make` de oscope-of/oscope-sphere résout vers `/Users/electron/Documents` (pas de `libs/openFrameworks`). Le build oF complet n'est donc PAS testable ici — c'est un manque d'env, jamais une régression de code. Seuls les tests C++ autonomes de oscope-sphere sont exécutables.

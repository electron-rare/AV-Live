# sound_algo — Project Instructions

Live-coding SuperCollider system. Always communicate in French with the user.

## Conventions

- Variables d'environnement `~xxx` minuscules (sinon SC parse comme CLASSNAME)
- Fichiers `.load` doivent avoir UN SEUL bloc top-level `(...)`. Multi-blocs OK pour les fichiers ouverts manuellement dans l'IDE.
- Code commenté en français
- Pas d'emojis sauf demande explicite

## Architecture

Voir `README.md` pour l'arborescence et les helpers principaux.

## Validation

Après toute modification :

- `awk` balance des parens/brackets : doit être P:0 B:0
- Pour les fichiers `.load`-compatibles : un seul bloc top-level (TLB:1)

## Live Performance Workflow

1. CHARGER TOUT (00_load.scd) ou bloc [0] de `01_live.scd`
2. **Tableau de bord = `01_live.scd`** (Cmd+Entree par bloc, API ~kk/~mm/~ff/~cc/~p)
3. Lancer une track (tracks/*.scd) ou les Pdef (bloc [10] PLAY)
4. Tweak via `01_live.scd`, `live/tweaks.scd` ou `live/live_fx_panel.scd`
5. Jump entre sections via `control/jump.scd`
6. Sauvegarder l'état avec `~saveScene` (live/scenes.scd)

## Note sur `-> nil`

Chaque bloc `( ~xxx.(...); )` retourne nil (le `;` final supprime la valeur).
Une cascade de `-> nil` = evaluation reussie de plusieurs blocs, pas un bug.

## Tests E2E

```bash
cd tests && bash run_all.sh
```

# sound_algo — Project Instructions

Live-coding SuperCollider system. Always communicate in French with the user.

## Conventions

- Variables d'environnement `~xxx` minuscules (sinon SC parse comme CLASSNAME)
- Fichiers `.load` doivent avoir UN SEUL bloc top-level `(...)`. Multi-blocs OK pour les fichiers ouverts manuellement dans l'IDE.
- Code commenté en français
- Pas d'emojis sauf demande explicite

## Architecture

Voir `README.md` pour l'arborescence et les helpers principaux.

Note namespaces : `~cc` = alias de `~ch` (chains, LIVE only, live/chains.scd) ;
`~cc*` (ex. `~ccNote`, `~ccMaster`, `~ccFire`) = namespace concert (data-only,
data_only/scene_concert.scd). Ces deux namespaces ne coexistent jamais.

## Boot modes

Trois points d'entree independants — ne PAS les mixer dans une meme instance sclang
(SynthDefs, etat ~bpm et scenes entrent en collision) :

| Fichier | Mode | Description |
|---------|------|-------------|
| `boot.scd` | **LIVE** | Performance IDE/launcher. Charge `live/_load.scd` (SynthDefs complets, 345 tracks, web bridge, Pdef sequencers). |
| `data_only/boot.scd` | **Concert / data-only** | Autonome, sans dependance sur live/. Charge son propre engine.scd + synthdefs.scd + data_feeds.scd + scenes.scd. Demarre la scene `\play`. Definit les variables `~cc*`. |
| `boot.data-only.scd` | **Hybride (legacy)** | Charge d'abord `live/_load.scd`, puis superpose `control/data_feeds.scd` + `live/data_only_program.scd`. Permet /control/dataScene via le systeme live complet. |

> ATTENTION : charger plus d'un de ces points d'entree dans la meme instance sclang
> corrompt l'etat : les SynthDefs live et data-only partagent des noms (`\do_*`),
> `~bpm` et les scenes se marchent dessus.

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

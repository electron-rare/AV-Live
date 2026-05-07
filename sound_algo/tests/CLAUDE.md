# tests/ — Suite E2E SuperCollider

Tests bout-en-bout via `sclang`. Chaque test affiche un resume
parsable que `run_all.sh` collecte (l'exit code de sclang n'est
pas fiable -- libc++abi peut crasher au quit du serveur interne).

## Lancement

```bash
cd tests && bash run_all.sh
```

Un test seul :
```bash
/Applications/SuperCollider.app/Contents/MacOS/sclang tests/e2e_05_melodies.scd
```

## Convention de test

```supercollider
"=== e2e_NN_xxx ===".postln;

~base = "/Users/electron/Documents/Projets_Creatifs/sound_algo/";
~testCount = 0; ~testFailed = 0;

~assert = { |label, cond, info|
    ~testCount = ~testCount + 1;
    if (cond) { ("  [OK] " ++ label).postln }
    { ~testFailed = ~testFailed + 1;
      ("  [FAIL] " ++ label ++ " : " ++ (info ? "")).postln };
};

~report = {
    ("== " ++ ~testCount ++ " tests, " ++ ~testFailed ++ " failed ==").postln;
    if (~testFailed > 0) { 1.exit } { 0.exit };
};
```

Ligne resume **obligatoire** : `== N tests, M failed ==`
(parsee par `run_all.sh` via `grep -E`).

## Ce qui est teste

| Fichier | Cible |
| --- | --- |
| `e2e_01_syntax.scd` | parse `String.compile` de chaque bloc top-level |
| `e2e_02_load.scd` | `00_load.scd` charge sans erreur |
| `e2e_03_reload_guards.scd` | `~reload.value` n'explose pas |
| `e2e_04_synthdef_compile.scd` | tous les SynthDef se compilent |
| `e2e_05_melodies.scd` | banques melodies coherentes |
| `e2e_06_mixer.scd` | mixer 8 voies |
| `e2e_07_jump.scd` | `~jumpTo` valide |
| `e2e_08_live.scd` | API live (mm, fx, scenes, ...) |
| `e2e_09_tracks.scd` | tracks A-W parsent |

## Anti-patterns

- Ne pas se fier a l'exit code sclang (peut etre != 0 alors que tests passent)
- Ne pas oublier `~report.value` a la fin -> SKIP dans run_all.sh
- Ne pas booter le serveur audio dans un test syntax (lent, instable en CI)
- Ne pas hardcoder le path sclang (utiliser `$SCLANG` env var)
- Ne pas laisser de Routine running en fin de test (fuite)

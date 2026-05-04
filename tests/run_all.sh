#!/bin/bash
# =====================================================================
#  run_all.sh -- runner pour la suite de tests E2E sound_algo
#  Execute chaque tests/e2e_NN_xxx.scd et reporte PASS/FAIL.
#
#  Note : sclang termine parfois en exit code != 0 (libc++abi sur quit
#  du serveur interne) meme quand tous les tests passent. On parse la
#  ligne "== N tests, M failed ==" dans la sortie au lieu de l'exit code.
# =====================================================================

set -u
cd "$(dirname "$0")/.."   # racine du projet

SCLANG="${SCLANG:-/Applications/SuperCollider.app/Contents/MacOS/sclang}"
TESTS_DIR="tests"
LOGS_DIR="tests/.logs"
mkdir -p "$LOGS_DIR"

if [ ! -x "$SCLANG" ]; then
    echo "[ERROR] sclang introuvable a $SCLANG"
    exit 2
fi

results=()
total_pass=0
total_fail=0
total_skip=0

for scd in "$TESTS_DIR"/e2e_*.scd; do
    name=$(basename "$scd" .scd)
    label="${name#e2e_}"
    log="$LOGS_DIR/${name}.log"

    echo "----------------------------------------------------------------"
    echo "[RUN] $label"
    echo "----------------------------------------------------------------"

    # Limite de temps : 60s par test (perl alarm si timeout coreutils absent)
    # 2>&1 dans le sous-shell pour eviter le "Abort trap: 6" de sclang
    # (innofensif, vient du arret du serveur interne ; on parse la sortie SC).
    ( perl -e 'alarm 60; exec @ARGV' "$SCLANG" "$scd" ) > "$log" 2>&1
    rc=$?

    # Parse le resume "== N tests, M failed =="
    summary=$(grep -E '^== [0-9]+ tests, [0-9]+ failed ==' "$log" | tail -1)
    if [ -z "$summary" ]; then
        # Pas de resume -> SKIP/CRASH
        total_skip=$((total_skip + 1))
        results+=("[SKIP] $label")
        echo "  -> [SKIP] (pas de resume; rc=$rc)"
        # Affiche les 30 dernieres lignes pour debug
        echo "  --- last 30 lines of $log ---"
        tail -30 "$log" | sed 's/^/    /'
        continue
    fi

    n_tests=$(echo "$summary" | sed -E 's/^== ([0-9]+) tests, ([0-9]+) failed ==/\1/')
    n_failed=$(echo "$summary" | sed -E 's/^== ([0-9]+) tests, ([0-9]+) failed ==/\2/')

    if [ "$n_failed" = "0" ]; then
        total_pass=$((total_pass + 1))
        results+=("[OK]   $label  ($n_tests tests)")
        echo "  -> [OK] $n_tests tests"
    else
        total_fail=$((total_fail + 1))
        results+=("[FAIL] $label  ($n_failed/$n_tests)")
        echo "  -> [FAIL] $n_failed/$n_tests failed"
        # Affiche les FAIL specifiques
        grep -E '^\s*\[FAIL\]' "$log" | sed 's/^/    /'
    fi
done

echo
echo "================================================================"
echo " RESUME FINAL"
echo "================================================================"
for r in "${results[@]}"; do
    echo "  $r"
done
echo
echo " Tests OK   : $total_pass"
echo " Tests FAIL : $total_fail"
echo " Tests SKIP : $total_skip"
echo "================================================================"

if [ "$total_fail" -gt 0 ] || [ "$total_skip" -gt 0 ]; then
    exit 1
fi
exit 0

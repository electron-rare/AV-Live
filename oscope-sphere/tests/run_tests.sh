#!/usr/bin/env bash
# Compiles and runs every pure-C++ unit test. No openFrameworks needed.
set -euo pipefail
cd "$(dirname "$0")/.."
CXX="${CXX:-clang++}"
FLAGS=(-std=c++17 -O0 -g -Isrc)

echo "== analysis =="
"$CXX" "${FLAGS[@]}" tests/test_analysis.cpp src/FFT.cpp src/AudioAnalyzer.cpp \
  -o /tmp/osph-test-analysis
/tmp/osph-test-analysis

echo "== spectrogram =="
"$CXX" "${FLAGS[@]}" tests/test_spectrogram.cpp src/SpectrogramBuffer.cpp \
  -o /tmp/osph-test-spectro
/tmp/osph-test-spectro

echo "== demo =="
"$CXX" "${FLAGS[@]}" tests/test_demo.cpp src/DemoSignal.cpp \
  -o /tmp/osph-test-demo
/tmp/osph-test-demo

echo "ALL TESTS PASSED"

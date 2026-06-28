// Headless test for ~setTempo. Run: sclang sound_algo/tests/test_tempo.scd
(
var ok = true;
// minimal: ~setTempo only needs TempoClock.default (always exists)
(thisProcess.nowExecutingPath.dirname.dirname ++ "/engine.scd").load;
~setTempo.(140);
if(~bpm != 140) { ok = false; "FAIL: bpm".postln };
if(TempoClock.default.tempo.round(0.0001) != (140/60).round(0.0001)) {
    ok = false; "FAIL: clock".postln };
~setTempo.(9999);                       // clip high
if(~bpm != 300) { ok = false; "FAIL: clip hi".postln };
~setTempo.(1);                          // clip low
if(~bpm != 20) { ok = false; "FAIL: clip lo".postln };
if(ok) { "PASS test_tempo".postln } { "TESTS FAILED".postln };
0.exit;
)

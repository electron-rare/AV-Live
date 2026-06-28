// Headless unit test for palette/note.scd.
// Run: sclang sound_algo/tests/test_note.scd
(
var ok = true, base;
base = thisProcess.nowExecutingPath.dirname.dirname ++ "/";
(base ++ "palette/note.scd").load;

// root note of minor pentatonic at root 60
if(~noteFor.(0, \minorPent, 60, 0) != 60) { ok = false; "FAIL: root".postln };
// degree 5 wraps one octave on a 5-note scale -> 72
if(~noteFor.(5, \minorPent, 60, 0) != 72) { ok = false; "FAIL: wrap".postln };
// minor degree 2 = +3 semitones -> 63
if(~noteFor.(2, \minor, 60, 0) != 63) { ok = false; "FAIL: minor".postln };
// concert parity: minor root 45 degree 2 -> 48 (old ~ccNote value)
if(~noteFor.(2, \minor, 45, 0) != 48) { ok = false; "FAIL: cc".postln };
// negative degree descends with floored mod: -1 on minor -> 58 (Bb, one step below C)
if(~noteFor.(-1, \minor, 60, 0) != 58) { ok = false; "FAIL: neg".postln };
// freq matches midicps
if(~freqFor.(0, \minorPent, 60, 0) != 60.midicps) { ok = false; "FAIL: freq".postln };

if(ok) { "PASS test_note".postln } { "TESTS FAILED".postln };
0.exit;
)

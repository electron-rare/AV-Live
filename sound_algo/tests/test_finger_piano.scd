// Headless unit test for finger_piano note resolution.
// Run: sclang sound_algo/tests/test_finger_piano.scd
(
var base, ok = true, ev;
base = thisProcess.nowExecutingPath.dirname.dirname ++ "/";
// minimal deps: scales + a fake handFeat + load finger_piano
(base ++ "palette/scales.scd").load;
~handFeat = Dictionary.new;
~handFeat[\lx] = 0.5; ~handFeat[\rx] = 0.5;
~handFeat[\ly] = 0.5; ~handFeat[\ry] = 0.5;
~melodyInst = \pluck;
(base ++ "control/finger_piano.scd").load;

// note.scd must be loaded for ~noteFor
(base ++ "palette/note.scd").load;
// default scale minorPent; L thumb (hand 0, finger 0) -> degree 0 -> root 60
ev = ~fpResolve.(0, 0, 1.0, 0.0, 0.5, 0.5);
("note L thumb = " ++ ev[\note]).postln;
if(ev[\note] != ~noteFor.(0, \minorPent, 60, 0)) {
    ok = false; "FAIL: L thumb note wrong".postln;
};
// right hand defaults one octave up (~fpHandOct[1] = 12)
ev = ~fpResolve.(1, 0, 1.0, 0.0, 0.5, 0.5);
if(ev[\note] != (~noteFor.(0, \minorPent, 60, 0) + 12)) {
    ok = false; "FAIL: R thumb octave wrong".postln;
};

// instrument follows live via \live sentinel
~fpInst = \live;
if(~fpResolveInst.() != \pluck) { ok = false; "FAIL: live inst".postln; };
~fpInst = \fm_bell;
if(~fpResolveInst.() != \fm_bell) { ok = false; "FAIL: pinned inst".postln; };

// modulation tick updates ~fpCut from dist (one-pole: 0 + 0.2*(1-0) = 0.2)
~handFeat[\dist] = 1.0;
~fpModTick.();
("fpCut after tick = " ++ ~fpCut).postln;
if(~fpCut.round(0.001) != 0.2) { ok = false; "FAIL: fpCut not updated to 0.2".postln; };

if(ok) { "PASS test_finger_piano".postln } { "TESTS FAILED".postln };
0.exit;
)

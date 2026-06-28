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

// default scale is minor pentatonic; left thumb (hand 0, finger 0) -> degree 0
ev = ~fpResolve.(0, 0, 1.0, 0.0, 0.5, 0.5);
("note L thumb = " ++ ev[\note]).postln;
if(ev[\note] != ~fpScaleArr.wrapAt(0)) {
    ok = false; "FAIL: L thumb note wrong".postln;
};

// right hand defaults one octave up (~fpHandOct[1] = 12)
ev = ~fpResolve.(1, 0, 1.0, 0.0, 0.5, 0.5);
if(ev[\note] != (~fpScaleArr.wrapAt(0) + 12)) {
    ok = false; "FAIL: R thumb octave wrong".postln;
};

// instrument follows live via \live sentinel
~fpInst = \live;
if(~fpResolveInst.() != \pluck) { ok = false; "FAIL: live inst".postln; };
~fpInst = \fm_bell;
if(~fpResolveInst.() != \fm_bell) { ok = false; "FAIL: pinned inst".postln; };

// modulation tick updates ~fpCut from dist
~handFeat[\dist] = 1.0;
~fpModTick.();
if(~fpCut.isNil) { ok = false; "FAIL: fpCut nil".postln; };

if(ok) { "PASS test_finger_piano".postln } { "TESTS FAILED".postln };
0.exit;
)

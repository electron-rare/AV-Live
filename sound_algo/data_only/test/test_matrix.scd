// Headless test for matrix.scd
// Run: /Applications/SuperCollider.app/Contents/MacOS/sclang \
//        sound_algo/data_only/test/test_matrix.scd
// Expected output: TEST PASS  (no ERROR lines)
// Server is NOT booted. ~toscSend is stubbed. Two dummy Pdefs are defined.
(
var featureFile = PathName(thisProcess.nowExecutingPath).pathOnly
    ++ "../matrix.scd";
var pass      = true;
var variation = nil;
var glowPat   = nil;

// Minimal dummy environment
~lp = (
    clock: TempoClock.default
);
~toscSend  = { |path ...args| };  // stub: accept any args, do nothing
~toscTouch = { |addr| };          // stub

// Define dummy base Pdefs so ~matVariation has something to capture
Pdef(\lp_kick, Pbind(\instrument, \lp_kick,  \dur, 1));
Pdef(\lp_hats, Pbind(\instrument, \lp_hat,   \dur, 0.5));
Pdef(\lp_arp,  Pbind(\instrument, \lp_pluck, \dur, 0.25));   // needed by Task-1 instrument overlay test (vi=6)
Pdef(\lp_acid, Pbind(\instrument, \lp_acid,  \dur, 0.5));    // needed by Task-2 mod overlay test (vi=5)

// Load the feature file (synchronous; stubs and Pdefs already in place)
featureFile.load;

// Assert public API functions were defined
pass = pass and: { ~matSetCell.notNil };
pass = pass and: { ~matPlay.notNil    };
pass = pass and: { ~matStop.notNil    };

// ~matSetCell.(0, 5, 3) must write 3 into matrix[0][5]
try {
    ~matSetCell.(0, 5, 3)
} { |e|
    pass = false;
    ("EXCEPTION in ~matSetCell: " ++ e.class.name).postln
};
pass = pass and: { ~lp[\matrix][0][5] == 3 };

// ~matVariation for a defined voice + color 2 must return a Pattern
try {
    variation = ~matVariation.(\kick, 2)
} { |e|
    pass = false;
    ("EXCEPTION in ~matVariation: " ++ e.class.name).postln
};
pass = pass and: { variation.notNil and: { variation.isKindOf(Pattern) } };

// Out-of-range ~matSetCell must NOT raise (vi=99 is outside 0..15)
try {
    ~matSetCell.(99, 0, 1)
} { |e|
    pass = false;
    ("EXCEPTION on out-of-range ~matSetCell: " ++ e.class.name).postln
};

// ~matStop must not raise (matRoutine is nil, matPlaying is false)
try {
    ~matStop.()
} { |e|
    pass = false;
    ("EXCEPTION in ~matStop: " ++ e.class.name).postln
};

// -- Persistence: save / load round-trip (touches filesystem, valid headless) --
~matSetCell.(1, 7, 4);
~matSetCell.(2, 0, 2);

try {
    ~matSave.("test grid")
} { |e|
    pass = false;
    ("EXCEPTION in ~matSave: " ++ e.class.name).postln
};
pass = pass and: {
    File.exists(~matDir +/+ "test_grid.matrix").if({ true }, {
        ("FAIL: save file not found at " ++ (~matDir +/+ "test_grid.matrix")).postln;
        false
    })
};

try {
    ~matClear.()
} { |e|
    pass = false;
    ("EXCEPTION in ~matClear: " ++ e.class.name).postln
};
pass = pass and: { ~lp[\matrix][1][7] == 0 };

try {
    ~matLoad.("test grid")
} { |e|
    pass = false;
    ("EXCEPTION in ~matLoad: " ++ e.class.name).postln
};
pass = pass and: { ~lp[\matrix][1][7] == 4 };
pass = pass and: { ~lp[\matrix][2][0] == 2 };
pass = pass and: { ~matGridValid.(~lp[\matrix]) };
pass = pass and: {
    ~matNames.(~matDir).includes(\test_grid).if({ true }, {
        "FAIL: test_grid not in matNames".postln;
        false
    })
};

File.delete(~matDir +/+ "test_grid.matrix");

// ~matEmitTrig must be defined and emit /matrix/trig with amp clipped to 0..1
pass = pass and: { ~matEmitTrig.notNil };
~trigLog = nil;
~toscSend = { |path ...args| ~trigLog = ([path] ++ args) };  // capturing stub
try {
    ~matEmitTrig.(3, 1.5)
} { |e|
    pass = false;
    ("EXCEPTION in ~matEmitTrig: " ++ e.class.name).postln
};
pass = pass and: { ~trigLog.notNil };
pass = pass and: { ~trigLog[0] == "/matrix/trig" };
pass = pass and: { ~trigLog[1] == 3 };
pass = pass and: { ~trigLog[2] == 1.0 };   // 1.5 clipped to 1.0

// Integration test: consuming a ~matVariation pattern fires ~matEmitTrig via \matGlow
~trigLog = nil;
~toscSend = { |path ...args| ~trigLog = ([path] ++ args) };  // reset capturing stub
try {
    glowPat = ~matVariation.(\kick, 2, 5)
} { |e|
    pass = false;
    ("EXCEPTION building matVariation for matGlow test: " ++ e.class.name).postln
};
try {
    glowPat.asStream.next(())
} { |e|
    pass = false;
    ("EXCEPTION consuming matGlow: " ++ e.class.name).postln
};
pass = pass and: { ~trigLog.notNil };
pass = pass and: { ~trigLog[0] == "/matrix/trig" };
pass = pass and: { ~trigLog[1] == 5 };
pass = pass and: { ~trigLog[2] == 1.0 };  // color 2 spec[\amp]=1.0; base has no \amp

// --- Instrument selection (Task 1) ---
pass = pass and: { ~matInstruments.notNil and: { ~matInstruments.size == 16 } };
pass = pass and: { ~matInstruments.every({ |x| x.isNil }) };          // default nil
pass = pass and: { ~matInstChoices.notNil and: { ~matKits.notNil } };

// apply a valid instrument echoes /matrix/instrument with vi + symbol string
~trigLog = nil;
~toscSend = { |path ...args| ~trigLog = ([path] ++ args) };
try { ~matApplyInstrument.(7, \do_plane) } { |e| pass = false;
    ("EXCEPTION matApplyInstrument: " ++ e.class.name).postln };
pass = pass and: { ~matInstruments[7] == \do_plane };
pass = pass and: { ~trigLog.notNil and: { ~trigLog[0] == "/matrix/instrument" } };
pass = pass and: { ~trigLog[1] == 7 };
pass = pass and: { ~trigLog[2].asString == "do_plane" };

// an instrument not in the voice's choices is rejected (state unchanged)
~matInstruments[0] = nil;
try { ~matApplyInstrument.(0, \do_plane) } { |e| pass = false };   // kick can't be do_plane
pass = pass and: { ~matInstruments[0].isNil };

// empty/"default" clears to nil
~matInstruments[7] = \do_plane;
~matApplyInstrument.(7, \default);
pass = pass and: { ~matInstruments[7].isNil };

// applying a kit sets its voices and leaves others nil
~matVoices.size.do { |i| ~matInstruments[i] = nil };
~matApplyKit.(\deep);
pass = pass and: { ~matInstruments[~matVoices.indexOf(\kick)] == \do_kick };
pass = pass and: { ~matInstruments[~matVoices.indexOf(\hats)].isNil };

// with an instrument set, consuming a ~matVariation stream carries \instrument
~matInstruments[6] = \do_strike;
~trigLog2 = nil;
try { ~trigLog2 = ~matVariation.(\arp, 2, 6).asStream.next(()) } { |e| pass = false;
    ("EXCEPTION matVariation inst: " ++ e.class.name).postln };
pass = pass and: { ~trigLog2.notNil and: { ~trigLog2[\instrument] == \do_strike } };
~matVoices.size.do { |i| ~matInstruments[i] = nil };   // reset for later tests

// REGRESSION: a nil-instrument (default) voice must still produce a sounding event
~matInstruments[0] = nil;                          // kick = default
~regEv = ~matVariation.(\kick, 2, 0).asStream.next(());
pass = pass and: { ~regEv.notNil };                // NOT stream-ended
pass = pass and: { ~regEv[\instrument] == \lp_kick };   // base instrument preserved
~matInstruments[0] = \do_kick;                     // override
~regEv2 = ~matVariation.(\kick, 2, 0).asStream.next(());
pass = pass and: { ~regEv2[\instrument] == \do_kick };
~matInstruments[0] = nil;

// --- Instrument persistence round-trip (Task 2) ---
pass = pass and: { ~matInstrPush.notNil };
~matVoices.size.do { |i| ~matInstruments[i] = nil };
~matSetCell.(1, 7, 4);
~matApplyInstrument.(7, \do_plane);                 // lead -> do_plane
~matSave.("inst grid");
~matVoices.size.do { |i| ~matInstruments[i] = nil };
~matClear.();
pass = pass and: { ~matLoad.("inst grid") };
pass = pass and: { ~lp[\matrix][1][7] == 4 };       // grid restored
pass = pass and: { ~matInstruments[7] == \do_plane }; // instrument restored
File.delete(~matDir +/+ "inst_grid.matrix");

// legacy grid-only file still loads (instruments default nil)
File.use(~matDir +/+ "legacy.matrix", "w", { |f|
    f.write(Array.fill(16, { Array.fill(32, 0) }).asCompileString) });
~matInstruments[3] = \do_strike;
pass = pass and: { ~matLoad.("legacy") };
pass = pass and: { ~matInstruments.every({ |x| x.isNil }) };  // defaulted
File.delete(~matDir +/+ "legacy.matrix");

// --- Capture mod sources (Task 1) ---
pass = pass and: { ~matModSourceVal.notNil and: { ~matModSources.notNil } };
~matModCache = IdentityDictionary[ \rHandY -> 1.5, \rOpen -> -0.2, \handSpeed -> 0.6 ];
pass = pass and: { ~matModSourceVal.(\rHandY) == 1.0 };     // clamped to 1
pass = pass and: { ~matModSourceVal.(\rOpen) == 0.0 };      // clamped to 0
pass = pass and: { ~matModSourceVal.(\handSpeed) == 0.6 };
pass = pass and: { ~matModSourceVal.(\unknownKey) == 0.0 }; // safe default

// --- Mod targets still available (capture sources kept) ---
pass = pass and: { ~matModTargets.notNil };

// -- Loop region --
pass = pass and: { ~matNextBar.notNil and: { ~matSetLoop.notNil and: { ~matSeek.notNil } } };

~matSetLoop.(4, 8);
pass = pass and: { ~lp[\matLoopStart] == 4 };
pass = pass and: { ~lp[\matLoopEnd] == 8 };

// Swapped args must auto-order
~matSetLoop.(10, 6);
pass = pass and: { ~lp[\matLoopStart] == 6 };
pass = pass and: { ~lp[\matLoopEnd] == 10 };

// Wrap: loop 2..4
~matSetLoop.(2, 4);
~lp[\matBar] = 4;
pass = pass and: { ~matNextBar.value == 2 };  // at le -> wraps to loop start
~lp[\matBar] = 2;
pass = pass and: { ~matNextBar.value == 3 };  // inside region -> advances
~lp[\matBar] = 0;
pass = pass and: { ~matNextBar.value == 2 };  // below ls -> snap to loop start

// Seek
~matSeek.(7);
pass = pass and: { ~lp[\matBar] == 7 };
~matSeek.(99);
pass = pass and: { ~lp[\matBar] == 31 };  // clamped to ~matBars - 1

// Reset loop to full range
~matSetLoop.(0, 31);

// --- Color editor: per-voice color defs (Task 1) ---
pass = pass and: { ~matColorDefs.notNil and: { ~matColorDefs.size == 16 } };
// defaults reproduce the current table: color 2 = stretch 0.5, octave 0, amp 1.0
pass = pass and: { ~matColorDefs[5][2][\stretch] == 0.5 };
pass = pass and: { ~matColorDefs[5][2][\octave] == 0 };
pass = pass and: { ~matColorDefs[5][2][\amp] == 1.0 };
pass = pass and: { ~matColorDefs[5][5][\amp] == 1.05 };   // color 5 default amp
pass = pass and: { ~matColorDefs[0][1][\inst].isNil };    // inst default nil
// ~matVariation reads the def: editing the def changes the produced event
~matColorDefs[5][2][\stretch] = 0.25;
~tv = ~matVariation.(\acid, 2, 5).asStream.next(());
pass = pass and: { ~tv[\stretch] == 0.25 };
~matColorDefs[5][2][\stretch] = 0.5;                      // restore default
// per-color cutoff applies for a filter voice (acid supports cutoff)
~matColorDefs[5][2][\cutoff] = 1234;
~tv2 = ~matVariation.(\acid, 2, 5).asStream.next(());
pass = pass and: { ~tv2[\cutoff] == 1234 };
~matColorDefs[5][2][\cutoff] = nil;
// per-color inst overrides the per-voice default
~matColorDefs[6][2][\inst] = \do_strike;                 // arp supports do_strike
~tv3 = ~matVariation.(\arp, 2, 6).asStream.next(());
pass = pass and: { ~tv3[\instrument] == \do_strike };
~matColorDefs[6][2][\inst] = nil;

// --- Color editor: set + push (Task 2) ---
pass = pass and: { ~matSetColorDef.notNil and: { ~matColorDefPush.notNil } };
~trigLog = nil;
~toscSend = { |path ...args| ~trigLog = ([path] ++ args) };
~matSetColorDef.(5, 3, \octave, -2);                 // acid, color 3
pass = pass and: { ~matColorDefs[5][3][\octave] == -2 };
pass = pass and: { ~trigLog[0] == "/matrix/colordefs" and: { ~trigLog[1] == 5 } };
pass = pass and: { ~trigLog.size == 38 };   // path + vi + 36 values

// direct test of ~matColorDefPush: address, vi, 38 items total, nil pan=-2, nil cutoff=-1
~trigLog = nil;
~matColorDefPush.(5);
pass = pass and: { ~trigLog[0] == "/matrix/colordefs" };
pass = pass and: { ~trigLog[1] == 5 };
pass = pass and: { ~trigLog.size == 38 };
pass = pass and: { ~trigLog[(2 + ((1-1)*6) + 5)] == -2 };   // color 1 pan nil -> -2
pass = pass and: { ~trigLog[(2 + ((1-1)*6) + 4)] == -1 };   // color 1 cutoff nil -> -1

// invalid field is rejected (state unchanged)
~matSetColorDef.(5, 3, \bogus, 9);
pass = pass and: { (~matColorDefs[5][3][\bogus]).isNil };
// invalid inst for the voice is rejected
~matSetColorDef.(0, 1, \inst, \do_plane);            // kick can't be do_plane
pass = pass and: { ~matColorDefs[0][1][\inst].isNil };
~matSetColorDef.(5, 3, \octave, 0);                  // restore

// --- Color editor: audition (Task 3) ---
pass = pass and: { ~matAudition.notNil };
// off when not running must not raise
try { ~matAudition.(0, false) } { |e| pass = false;
    ("EXCEPTION matAudition off: " ++ e.class.name).postln };

// --- Color editor: persistence (Task 4) ---
~matColorDefs[4][3][\amp] = 0.42;                    // sub, color 3
~matSave.("cdef grid");
~matColorDefs = Array.fill(~matVoices.size, { ~matDefaultColorDefs.value });
pass = pass and: { ~matLoad.("cdef grid") };
pass = pass and: { ~matColorDefs[4][3][\amp] == 0.42 };
File.delete(~matDir +/+ "cdef_grid.matrix");
// legacy grid-only file loads with default color defs
File.use(~matDir +/+ "cleg.matrix", "w", { |f|
    f.write(Array.fill(16, { Array.fill(32, 0) }).asCompileString) });
~matColorDefs[4][3][\amp] = 0.9;
pass = pass and: { ~matLoad.("cleg") };
pass = pass and: { ~matColorDefs[4][3][\amp] == 1.0 };   // defaulted (color 3 amp default)
File.delete(~matDir +/+ "cleg.matrix");

// REGRESSION: clear a per-color instrument to default via the STRING "default" (web path)
~matColorDefs[6][2][\inst] = \do_strike;            // arp, color 2 (do_strike is a valid arp choice)
~matSetColorDef.(6, 2, \inst, "default");           // String, as OSC delivers it
pass = pass and: { ~matColorDefs[6][2][\inst].isNil };   // cleared
// valid inst as a String also works
~matSetColorDef.(6, 2, \inst, "do_strike");
pass = pass and: { ~matColorDefs[6][2][\inst] == \do_strike };
~matColorDefs[6][2][\inst] = nil;                   // restore

pass = pass and: { ~matVariation.(\acid, 1, 5).asStream.next(()).notNil };

// --- Step sequencer state (Task 1) ---
pass = pass and: { ~matStepsEmpty.notNil and: { ~matSetStep.notNil and: { ~matStepsPush.notNil } } };
// default: every color's steps is a 16-slot all-nil array -> empty
pass = pass and: { ~matColorDefs[5][2][\steps].size == 16 };
pass = pass and: { ~matStepsEmpty.(~matColorDefs[5][2][\steps]) };
// set a step, then not empty; step holds degree+vel
~trigLog = nil;
~toscSend = { |path ...args| ~trigLog = ([path] ++ args) };
~matSetStep.(5, 2, 3, 7, 0.8);
pass = pass and: { ~matColorDefs[5][2][\steps][3][\degree] == 7 };
pass = pass and: { ~matColorDefs[5][2][\steps][3][\vel] == 0.8 };
pass = pass and: { ~matStepsEmpty.(~matColorDefs[5][2][\steps]).not };
pass = pass and: { ~trigLog[0] == "/matrix/steps" and: { ~trigLog[1] == 5 } };
pass = pass and: { ~trigLog.size == 35 };   // path + vi + color + 32 vals
// rest clears the step
~matSetStep.(5, 2, 3, \rest, 0);
pass = pass and: { ~matColorDefs[5][2][\steps][3].isNil };
pass = pass and: { ~matStepsEmpty.(~matColorDefs[5][2][\steps]) };
// two colors' steps arrays must be distinct objects (not aliased)
pass = pass and: { (~matColorDefs[5][2][\steps] === ~matColorDefs[5][3][\steps]).not };

// --- Sequence engine (Task 2) ---
pass = pass and: { ~matColorStepPattern.notNil };
// empty steps -> base path unchanged (parity): consuming yields the base-equivalent event
~matColorDefs[5][2][\steps] = Array.fill(16, nil);
~sv = ~matVariation.(\acid, 2, 5).asStream.next(());
pass = pass and: { ~sv[\stretch] == 0.5 };       // color 2 stretch, base path
// non-empty steps -> stepped pattern; first non-rest step degree shows up
~matColorDefs[5][2][\steps][0] = (degree: 4, vel: 0.9);
~sv2 = ~matVariation.(\acid, 2, 5).asStream.next(());
pass = pass and: { ~sv2[\degree] == 4 };          // step 0 degree
pass = pass and: { ~sv2[\dur] == (~matBeatsPerBar / 16) };
~matColorDefs[5][2][\steps] = Array.fill(16, nil);  // restore empty

// --- Step persistence (Task 3) ---
~matColorDefs[4][3][\steps][2] = (degree: 5, vel: 0.7);
~matSave.("step grid");
~matColorDefs = Array.fill(~matVoices.size, { ~matDefaultColorDefs.value });
pass = pass and: { ~matLoad.("step grid") };
pass = pass and: { ~matColorDefs[4][3][\steps][2][\degree] == 5 };
pass = pass and: { ~matColorDefs[4][3][\steps][2][\vel] == 0.7 };
File.delete(~matDir +/+ "step_grid.matrix");
// legacy grid-only file -> default empty steps
File.use(~matDir +/+ "sleg.matrix", "w", { |f| f.write(Array.fill(16, { Array.fill(32, 0) }).asCompileString) });
~matColorDefs[4][3][\steps][2] = (degree: 9, vel: 0.5);
pass = pass and: { ~matLoad.("sleg") };
pass = pass and: { ~matStepsEmpty.(~matColorDefs[4][3][\steps]) };
File.delete(~matDir +/+ "sleg.matrix");


// --- Clamp: ~matSetStep must clip degree to -48..48 ---
~matSetStep.(5, 2, 4, 200, 0.5);
pass = pass and: { ~matColorDefs[5][2][\steps][4][\degree] == 48 };
~matSetStep.(5, 2, 4, \rest, 0);   // restore

// --- Drum \freq.isNil: stepped kick must NOT emit \freq ---
~kickVi = ~matVoices.indexOf(\kick);
~matSetStep.(~kickVi, 2, 0, 3, 0.8);
~ev = ~matVariation.(\kick, 2, ~kickVi).asStream.next(());
pass = pass and: { ~ev[\freq].isNil };
~matColorDefs[~kickVi][2][\steps] = Array.fill(16, nil);   // restore

// --- Per-color mod + pose state (Task 1) ---
pass = pass and: { ~matColorDefs[5][2][\mod].isNil };               // default no effect
pass = pass and: { ~matColorDefs[5][2][\pose].isArray and: { ~matColorDefs[5][2][\pose].isEmpty } };
pass = pass and: { ~matSetColorMod.notNil and: { ~matSetColorPose.notNil } };
~trigLog = nil; ~toscSend = { |path ...args| ~trigLog = ([path] ++ args) };
~matSetColorMod.(5, 2, \rHandY, \cutoff, 0.7);                      // acid supports cutoff
pass = pass and: { ~matColorDefs[5][2][\mod][\target] == \cutoff };
pass = pass and: { ~trigLog[0] == "/matrix/colormod" and: { ~trigLog[1] == 5 } };
~matSetColorMod.(0, 1, \rHandY, \cutoff, 0.7);                      // kick has no cutoff -> reject
pass = pass and: { ~matColorDefs[0][1][\mod].isNil };
~matSetColorMod.(5, 2, \none, \none, 0);                            // clears
pass = pass and: { ~matColorDefs[5][2][\mod].isNil };
~matSetColorPose.(5, 2, \poseA, \trigger);
pass = pass and: { ~matColorDefs[5][2][\pose][0][\poseId] == \poseA };
~matColorDefs[5][2][\pose] = [];

// dedup: setting the same poseId twice keeps one entry
~matColorDefs[5][2][\pose] = [];
~matSetColorPose.(5, 2, \poseD, \trigger);
~matSetColorPose.(5, 2, \poseD, \gate);
pass = pass and: { ~matColorDefs[5][2][\pose].size == 1 };
pass = pass and: { ~matColorDefs[5][2][\pose][0][\action] == \gate };
~matColorDefs[5][2][\pose] = [];

// colorpose push echo
~trigLog = nil;
~matSetColorPose.(5, 2, \poseE, \trigger);
pass = pass and: { ~trigLog[0] == "/matrix/colorpose" and: { ~trigLog[1] == 5 } };
~matColorDefs[5][2][\pose] = [];

// out-of-bounds set must not raise / not corrupt
~matSetColorMod.(-1, 1, \rHandY, \cutoff, 0.5);
~matSetColorMod.(5, 7, \rHandY, \cutoff, 0.5);
pass = pass and: { true };

// Fix 1: fresh color pose arrays and distinct per color
pass = pass and: { (~matColorDefs[5][1][\pose] === ~matColorDefs[5][2][\pose]).not };

// --- Engine reads per-color mod + per-color pose fire (Task 2 color-refactor) ---
pass = pass and: { ~matModPairs.notNil };
// a color with a cutoff mod -> the produced event has a \cutoff key
~matModCache = IdentityDictionary[ \rHandY -> 1.0 ];
~matColorDefs[5][2][\mod] = (source: \rHandY, target: \cutoff, depth: 1.0);
~ev = ~matVariation.(\acid, 2, 5).asStream.next(());
pass = pass and: { ~ev[\cutoff].notNil and: { ~ev[\cutoff] > 3000 } };
~matColorDefs[5][2][\mod] = nil;
// per-voice ~matMod removed
pass = pass and: { ~matMod.isNil };
pass = pass and: { ~matPoseBindings.isNil };
// per-color pose fire: a binding under a color, firing re-sources (no raise)
~matColorDefs[5][3][\pose] = [ (poseId: \poseX, action: \trigger) ];
try { ~matPoseFire.(\poseX) } { |e| pass = false; ("EXC poseFire: " ++ e.class.name).postln };
try { ~matPoseFire.(\unknown) } { |e| pass = false };
~matColorDefs[5][3][\pose] = [];

pass.if(
    { "TEST PASS".postln },
    { "TEST FAIL".postln }
);
0.exit;
)

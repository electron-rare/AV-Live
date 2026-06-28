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
Pdef(\lp_kick, Pbind(\dur, 1));
Pdef(\lp_hats, Pbind(\dur, 0.5));

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

pass.if(
    { "TEST PASS".postln },
    { "TEST FAIL".postln }
);
0.exit;
)

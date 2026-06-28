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

pass.if(
    { "TEST PASS".postln },
    { "TEST FAIL".postln }
);
0.exit;
)

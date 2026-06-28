// Headless test for sections.scd
// Run: /Applications/SuperCollider.app/Contents/MacOS/sclang \
//        sound_algo/data_only/test/test_sections.scd
// Expected output: TEST PASS  (with no ERROR lines from sections.scd)
//
// Server is NOT booted. ~lpArm, ~toscSend, ~ccHarmony are stubbed.
(
var featureFile = PathName(thisProcess.nowExecutingPath).pathOnly
    ++ "../sections.scd";
var pass = true;

// Minimal dummy environment matching shapes expected by sections.scd
~lp = (
    armed:    Set[\kick],
    melSel:   0,
    rhySel:   0,
    clock:    TempoClock.default,
    melodies: [[0]],
    rhythms:  [(name: "x", k: "", s: "", h: "")]
);

// Stubs — no server, no real transport
~lpArm    = { |n, o| };
~ccHarmony = (root: 40, scale: \minor, octave: 1, phrase: 0);
~toscSend  = { |...a| };

// Load the feature file (synchronous; stubs already in place)
featureFile.load;

// Assert public API functions were wired
pass = pass and: { ~sceneSave.notNil   };
pass = pass and: { ~sceneLaunch.notNil };
pass = pass and: { ~sceneNext.notNil   };

// ~sceneSave.(0) must populate slot 0
try { ~sceneSave.(0) } { |e|
    pass = false;
    ("EXCEPTION in ~sceneSave: " ++ e.class.name).postln;
};
pass = pass and: { ~lp[\scenes][0].notNil };

// ~sceneLaunch.(0) must not raise
try { ~sceneLaunch.(0) } { |e|
    pass = false;
    ("EXCEPTION in ~sceneLaunch: " ++ e.class.name).postln;
};

// ~sceneNext must not raise (slot 0 filled; wraps back and launches 0 again)
try { ~sceneNext.() } { |e|
    pass = false;
    ("EXCEPTION in ~sceneNext: " ++ e.class.name).postln;
};

pass.if(
    { "TEST PASS".postln },
    { "TEST FAIL".postln }
);
0.exit;
)

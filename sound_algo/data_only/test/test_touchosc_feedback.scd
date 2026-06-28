// Headless test for touchosc_feedback.scd
// Run: /Applications/SuperCollider.app/Contents/MacOS/sclang \
//        sound_algo/data_only/test/test_touchosc_feedback.scd
// Expected output: TEST PASS  (with no ERROR lines from the feature file)
//
// The audio server is NOT booted, so the RMS probe block is skipped by its
// Server.default.serverRunning guard. The Routine is started and immediately
// stopped — the armed push fires once with ~tosc nil, which must not raise.
(
var featureFile = "/Users/electron/Documents/Projets/AV-Live/sound_algo/data_only/touchosc_feedback.scd";
var pass = true;

// Build a minimal dummy environment matching the shapes launchpad.scd creates
~lp = (
    clock:    TempoClock.default,
    armed:    Set[\kick],
    melodies: [[0, 2, 3, 5]],
    rhythms:  [(name: "4floor", k: "1000100010001000",
                s: "0000100000001000", h: "0010101010101010")]
);

// Load the feature file (synchronous; server not booted -> RMS block skipped)
featureFile.load;

// Assert the three public API functions were wired up
pass = pass and: { ~toscSend.notNil };
pass = pass and: { ~toscTouch.notNil };
pass = pass and: { ~toscArmedPush.notNil };

// Calling ~toscArmedPush.() with ~tosc nil must not raise
// (~toscSend nil-guards via !? so no OSC is actually sent)
try { ~toscArmedPush.() } { |e|
    pass = false;
    ("EXCEPTION in ~toscArmedPush: " ++ e.messageString).postln;
};

// Stop the background Routine so the process can exit cleanly
~toscFeedbackRoutine !? { ~toscFeedbackRoutine.stop };

pass.if(
    { "TEST PASS".postln },
    { "TEST FAIL".postln }
);
0.exit;
)

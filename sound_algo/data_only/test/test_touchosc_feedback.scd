// Headless test for touchosc_feedback.scd
// Run: /Applications/SuperCollider.app/Contents/MacOS/sclang \
//        sound_algo/data_only/test/test_touchosc_feedback.scd
// Expected output: TEST PASS  (with no ERROR lines from the feature file)
//
// The audio server is NOT booted, so the RMS probe block is skipped by its
// Server.default.serverRunning guard. The Routine is started and immediately
// stopped — the armed push fires once with ~tosc nil, which must not raise.
(
// Resolve the feature file relative to this test file so it runs on any
// clone path (e.g. GrosMac and macM1 have different repo roots).
var featureFile = PathName(thisProcess.nowExecutingPath).pathOnly
    ++ "../touchosc_feedback.scd";
var pass = true;

// Build a minimal dummy environment matching the shapes launchpad.scd creates
~lp = (
    clock:     TempoClock.default,
    armed:     Set[\kick],
    clipState: IdentityDictionary.new,
    quant:     4,
    melodies:  [[0, 2, 3, 5]],
    rhythms:   [(name: "4floor", k: "1000100010001000",
                 s: "0000100000001000", h: "0010101010101010")]
);

// Load the feature file (synchronous; server not booted -> RMS block skipped)
featureFile.load;

// Assert the three public API functions were wired up
pass = pass and: { ~toscSend.notNil };
pass = pass and: { ~toscTouch.notNil };
pass = pass and: { ~toscArmedPush.notNil };

// Calling ~toscArmedPush.() with no clients must not raise
// (~toscSend iterates an empty dictionary -> no-op, no OSC sent)
try { ~toscArmedPush.() } { |e|
    pass = false;
    ("EXCEPTION in ~toscArmedPush: " ++ e.messageString).postln;
};

// Assert multicast set grows with distinct IPs
~toscTouch.(NetAddr("127.0.0.1", 0));
~toscTouch.(NetAddr("10.0.0.9", 0));
pass = pass and: { ~toscClients.size == 2 };

// Stop the background Routine so the process can exit cleanly
~toscFeedbackRoutine !? { ~toscFeedbackRoutine.stop };

// Assert 4-state clipState is read without raising
~lp[\clipState][\kick] = 2;  // queued-launch
try { ~toscArmedPush.() } { |e|
    pass = false;
    ("EXCEPTION in ~toscArmedPush (clipState): " ++ e.messageString).postln;
};

pass.if(
    { "TEST PASS".postln },
    { "TEST FAIL".postln }
);
0.exit;
)

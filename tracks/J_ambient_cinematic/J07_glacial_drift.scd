// =====================================================================
//  J07_glacial_drift.scd  --  Album J, track 7/15
// =====================================================================

// --- TRACK J07 : "GLACIAL DRIFT" 5 minutes ---------------------------
//   0:00 drone glace -> 1:30 vocalPad -> 3:00 strings -> 4:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[J07 0:00] drone glace...".postln;
    ~bpm = 65;
    ~melodyInst = \drone; ~melodyAttack = 2.0; ~melodyRelease = 3.5;
    ~melodyCutoff = 1200; ~melodyAmp = 0.20;
    ~melodyNotes = [48,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,
                    48,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0];
    ~kickSteps=(0!16); ~hatSteps=(0!16); ~snareSteps=(0!16);
    ~clapSteps=(0!16); ~percSteps=(0!16); ~acidAmp=0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\cosmic) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\cinematic);
    Synth(\gong, [\freq, 45, \decay, 10, \amp, 0.5]);
    90.wait;

    "[J07 1:30] vocalPad gel...".postln;
    ~melodyInst = \vocalPad;
    ~melodyAttack = 1.0; ~melodyRelease = 2.5; ~melodyCutoff = 2200;
    ~melodyAmp = 0.20;
    ~melodyNotes = [60,0,0,0, 63,0,0,0, 67,0,0,0, 70,0,0,0,
                    72,0,0,0, 70,0,0,0, 67,0,0,0, 63,0,0,0];
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.05, 700, \sin, 2200) };
    ~reload.value;
    90.wait;

    "[J07 3:00] strings glaciaux...".postln;
    ~melodyInst = \strings;
    ~melodyAttack = 0.5; ~melodyRelease = 1.5; ~melodyCutoff = 3000;
    ~melodyAmp = 0.20;
    ~reload.value;
    18.do { |k|
        if (0.18.coin) {
            ~melodyNotes = ~mutate.(~melodyNotes, 0.2, ~scaleMinor);
            ~reload.value;
        };
        5.wait;
    };

    "[J07 4:30] outro...".postln;
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~melodyInst = \drone;
    ~melodyAttack = 2.0; ~melodyRelease = 3.5;
    ~reload.value;
    20.do { |k|
        var x = 1 - ((k + 1) / 20);
        ~melodyAmp = x * 0.20; ~melodyCutoff = 200 + (x * 800);
        ~reload.value; 1.5.wait;
    };
    Synth(\gong, [\freq, 35, \decay, 15, \amp, 0.6]);
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[J07 5:00] === fin GLACIAL DRIFT ===".postln;
}).play;
"=== TRACK J07 : GLACIAL DRIFT 5 min lancee ===".postln;
)

// =====================================================================
//  J03_strings_horizon.scd  --  Album J, track 3/15
// =====================================================================

// --- TRACK J03 : "STRINGS HORIZON" 6 minutes -------------------------
//   0:00 drone -> 1:00 strings -> 2:30 handpan -> 4:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[J03 0:00] drone horizon...".postln;
    ~bpm = 75;
    ~melodyInst = \drone; ~melodyAttack = 1.5; ~melodyRelease = 3.0;
    ~melodyCutoff = 1500; ~melodyAmp = 0.18;
    ~melodyNotes = [48,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,
                    48,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0];
    ~kickSteps=(0!16); ~hatSteps=(0!16); ~snareSteps=(0!16);
    ~clapSteps=(0!16); ~percSteps=(0!16); ~acidAmp=0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\space) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\cinematic);
    Synth(\gong, [\freq, 50, \decay, 10, \amp, 0.5]);
    60.wait;

    "[J03 1:00] strings emerge...".postln;
    ~melodyInst = \strings;
    ~melodyAttack = 0.4; ~melodyRelease = 1.2; ~melodyCutoff = 3500;
    ~melodyAmp = 0.22;
    ~melodyNotes = [60,0,0,0, 65,0,0,0, 67,0,0,0, 72,0,0,0,
                    74,0,0,0, 72,0,0,0, 67,0,0,0, 65,0,0,0];
    ~reload.value;
    90.wait;

    "[J03 2:30] handpan delicat...".postln;
    ~melodyInst = \handpan;
    ~melodyAttack = 0.001; ~melodyRelease = 1.8; ~melodyCutoff = 5000;
    ~melodyAmp = 0.22;
    ~melodyNotes = [60,0,67,0, 70,0,72,0, 75,0,72,70, 67,0,63,60,
                    63,0,67,0, 70,0,75,0, 79,0,75,72, 70,0,65,60];
    ~reload.value;
    24.do { |k|
        if (0.20.coin) {
            ~melodyNotes = ~mutate.(~melodyNotes, 0.2, ~scaleMinorPent);
            ~reload.value;
        };
        5.wait;
    };

    "[J03 4:30] outro...".postln;
    ~melodyInst = \drone;
    ~melodyAttack = 1.5; ~melodyRelease = 3.0;
    ~reload.value;
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~melodyAmp = x * 0.22; ~melodyCutoff = 200 + (x * 1000);
        ~reload.value; 1.wait;
    };
    Synth(\gong, [\freq, 40, \decay, 12, \amp, 0.5]);
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[J03 6:00] === fin STRINGS HORIZON ===".postln;
}).play;
"=== TRACK J03 : STRINGS HORIZON 6 min lancee ===".postln;
)

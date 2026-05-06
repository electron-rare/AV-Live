// =====================================================================
//  J01_first_light.scd  --  Album J "Ambient Cinematic", track 1/15
// =====================================================================

// --- TRACK J01 : "FIRST LIGHT" 4 minutes -----------------------------
//   0:00 drone -> 1:00 strings -> 2:30 flute -> 3:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[J01 0:00] drone aube...".postln;
    ~bpm = 70;
    ~melodyInst = \drone; ~melodyAttack = 1.5; ~melodyRelease = 3.0;
    ~melodyCutoff = 1500; ~melodyAmp = 0.20;
    ~melodyNotes = [48,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,
                    48,0,0,0,0,0,0,0, 55,0,0,0,0,0,0,0];
    ~kickSteps=(0!16); ~hatSteps=(0!16); ~snareSteps=(0!16);
    ~clapSteps=(0!16); ~percSteps=(0!16); ~acidAmp=0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\cosmic) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\cinematic);
    Synth(\gong, [\freq, 50, \decay, 8, \amp, 0.4]);
    60.wait;

    "[J01 1:00] strings aurore...".postln;
    ~melodyInst = \strings;
    ~melodyAttack = 0.4; ~melodyRelease = 1.2; ~melodyCutoff = 3500;
    ~melodyAmp = 0.20;
    ~melodyNotes = [60,0,0,0, 65,0,0,0, 67,0,0,0, 72,0,0,0,
                    74,0,0,0, 72,0,0,0, 67,0,0,0, 65,0,0,0];
    ~reload.value;
    90.wait;

    "[J01 2:30] flute melodique...".postln;
    ~melodyInst = \flute;
    ~melodyAttack = 0.08; ~melodyRelease = 0.5; ~melodyCutoff = 4000;
    ~melodyAmp = 0.20;
    ~melodyNotes = ~genMelody.(0.4, ~scaleMinorPent);
    ~reload.value;
    12.do { |k|
        if (0.20.coin) {
            ~melodyNotes = ~mutate.(~melodyNotes, 0.25, ~scaleMinorPent);
            ~reload.value;
        };
        5.wait;
    };

    "[J01 3:30] outro lent...".postln;
    ~melodyInst = \drone;
    ~melodyAttack = 1.5; ~melodyRelease = 3.0;
    ~reload.value;
    20.do { |k|
        var x = 1 - ((k + 1) / 20);
        ~melodyAmp = x * 0.20; ~melodyCutoff = 200 + (x * 1000);
        ~reload.value; 1.5.wait;
    };
    Synth(\gong, [\freq, 40, \decay, 12, \amp, 0.5]);
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[J01 4:00] === fin FIRST LIGHT ===".postln;
}).play;
"=== TRACK J01 : FIRST LIGHT 4 min lancee ===".postln;
)

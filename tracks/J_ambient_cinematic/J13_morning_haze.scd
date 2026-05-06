// =====================================================================
//  J13_morning_haze.scd  --  Album J, track 13/15
// =====================================================================

// --- TRACK J13 : "MORNING HAZE" 4 minutes ----------------------------
//   0:00 drone -> 1:00 flute -> 2:30 strings -> 3:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[J13 0:00] drone aurore...".postln;
    ~bpm = 80;
    ~melodyInst = \drone; ~melodyAttack = 1.5; ~melodyRelease = 3.0;
    ~melodyCutoff = 1800; ~melodyAmp = 0.18;
    ~melodyNotes = [60,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,
                    60,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0];
    ~kickSteps=(0!16); ~hatSteps=(0!16); ~snareSteps=(0!16);
    ~clapSteps=(0!16); ~percSteps=(0!16); ~acidAmp=0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\dream) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\cinematic);
    60.wait;

    "[J13 1:00] flute matin...".postln;
    ~melodyInst = \flute;
    ~melodyAttack = 0.08; ~melodyRelease = 0.5; ~melodyCutoff = 4000;
    ~melodyAmp = 0.20;
    ~melodyNotes = ~genMelody.(0.4, ~scaleMinorPent);
    ~reload.value;
    18.do { |k|
        if (0.20.coin) {
            ~melodyNotes = ~mutate.(~melodyNotes, 0.2, ~scaleMinorPent);
            ~reload.value;
        };
        5.wait;
    };

    "[J13 2:30] strings douces...".postln;
    ~melodyInst = \strings;
    ~melodyAttack = 0.4; ~melodyRelease = 1.2; ~melodyCutoff = 3500;
    ~melodyAmp = 0.20;
    ~melodyNotes = [60,0,0,0, 65,0,0,0, 67,0,0,0, 72,0,0,0,
                    74,0,0,0, 72,0,0,0, 67,0,0,0, 65,0,0,0];
    ~reload.value;
    60.wait;

    "[J13 3:30] outro...".postln;
    ~melodyInst = \drone;
    ~melodyAttack = 1.5; ~melodyRelease = 3.0;
    ~reload.value;
    20.do { |k|
        var x = 1 - ((k + 1) / 20);
        ~melodyAmp = x * 0.20; ~melodyCutoff = 200 + (x * 1200);
        ~reload.value; 1.5.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[J13 4:00] === fin MORNING HAZE ===".postln;
}).play;
"=== TRACK J13 : MORNING HAZE 4 min lancee ===".postln;
)

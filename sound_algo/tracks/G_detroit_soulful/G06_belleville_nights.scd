// =====================================================================
//  G06_belleville_nights.scd  --  Album G, track 6/15
// =====================================================================

// --- TRACK G06 : "BELLEVILLE NIGHTS" 6 minutes -----------------------
//   0:00 vocalPad -> 1:00 groove -> 2:30 rhodes -> 4:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[G06 0:00] vocalPad nocturne...".postln;
    ~bpm = 123;
    ~melodyInst = \vocalPad; ~melodyAttack = 0.5; ~melodyRelease = 1.8;
    ~melodyCutoff = 2500; ~melodyAmp = 0.20;
    ~melodyNotes = [60,0,0,0, 63,0,0,0, 67,0,0,0, 70,0,0,0,
                    72,0,0,0, 70,0,0,0, 67,0,0,0, 63,0,0,0];
    ~kickSteps=(0!16); ~hatSteps=(0!16); ~clapSteps=(0!16); ~acidAmp=0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\dream) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\third);
    60.wait;

    "[G06 1:00] groove douce...".postln;
    ~kickSteps = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.45;
    ~kickFreq = 48; ~kickPitchAmt = 2.5; ~kickDecay = 0.40; ~kickClick = 0.08;
    ~hatSteps = [0,1,1,0, 0,1,1,0, 0,1,1,0, 0,1,1,0]; ~hatAmp = 0.12;
    ~clapSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.28;
    ~reload.value;
    90.wait;

    "[G06 2:30] rhodes melodique...".postln;
    ~melodyInst = \rhodes;
    ~melodyAttack = 0.01; ~melodyRelease = 0.7; ~melodyCutoff = 3500;
    ~melodyAmp = 0.20;
    ~melodyNotes = ~genMelody.(0.55, ~scaleMinorPent);
    ~reload.value;
    24.do { |k|
        if (0.22.coin) {
            ~melodyNotes = ~mutate.(~melodyNotes, 0.25, ~scaleMinorPent);
            ~reload.value;
        };
        if (0.10.coin) { ~melodyNotes = ~octavate.(~melodyNotes, 0.2); ~reload.value };
        5.wait;
    };

    "[G06 4:30] outro -- vocalPad fade...".postln;
    ~melodyInst = \vocalPad;
    ~melodyAttack = 0.5; ~melodyRelease = 2.0;
    ~reload.value;
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~kickAmp = x * 0.45; ~hatAmp = x * 0.12; ~clapAmp = x * 0.28;
        ~melodyAmp = x * 0.20;
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[G06 5:00] === fin BELLEVILLE NIGHTS ===".postln;
}).play;
"=== TRACK G06 : BELLEVILLE NIGHTS 5 min lancee ===".postln;
)

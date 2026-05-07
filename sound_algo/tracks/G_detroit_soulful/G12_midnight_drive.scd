// =====================================================================
//  G12_midnight_drive.scd  --  Album G, track 12/15
// =====================================================================

// --- TRACK G12 : "MIDNIGHT DRIVE" 5 minutes --------------------------
//   0:00 pad -> 0:45 groove -> 2:00 stab -> 4:00 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[G12 0:00] pad nocturne...".postln;
    ~bpm = 125;
    ~melodyInst = \warmPad; ~melodyAttack = 0.5; ~melodyRelease = 1.8;
    ~melodyCutoff = 1800; ~melodyAmp = 0.18;
    ~melodyNotes = [60,0,0,0, 65,0,0,0, 67,0,0,0, 70,0,0,0,
                    72,0,0,0, 70,0,0,0, 67,0,0,0, 65,0,0,0];
    ~kickSteps=(0!16); ~hatSteps=(0!16); ~clapSteps=(0!16); ~acidAmp=0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\dub) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\third);
    45.wait;

    "[G12 0:45] groove minimal...".postln;
    ~kickSteps = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.48;
    ~kickFreq = 48; ~kickPitchAmt = 2.8; ~kickDecay = 0.35; ~kickClick = 0.10;
    ~hatSteps = [0,0,1,0, 0,1,1,0, 0,0,1,0, 0,1,1,0]; ~hatAmp = 0.13;
    ~clapSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.28;
    ~reload.value;
    75.wait;

    "[G12 2:00] stab + variations...".postln;
    ~melodyInst = \stab;
    ~melodyAttack = 0.001; ~melodyRelease = 0.07; ~melodyDrive = 2.5;
    ~melodyAmp = 0.18;
    ~melodyNotes = ~genMelody.(0.45, ~scaleMinor);
    ~reload.value;
    24.do { |k|
        if (0.20.coin) {
            ~melodyNotes = ~mutate.(~melodyNotes, 0.25, ~scaleMinor);
            ~reload.value;
        };
        5.wait;
    };

    "[G12 4:00] outro...".postln;
    ~melodyInst = \warmPad;
    ~melodyAttack = 0.5; ~melodyRelease = 2.0;
    ~reload.value;
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~kickAmp = x * 0.48; ~hatAmp = x * 0.13; ~clapAmp = x * 0.28;
        ~melodyAmp = x * 0.18;
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[G12 4:30] === fin MIDNIGHT DRIVE ===".postln;
}).play;
"=== TRACK G12 : MIDNIGHT DRIVE 5 min lancee ===".postln;
)

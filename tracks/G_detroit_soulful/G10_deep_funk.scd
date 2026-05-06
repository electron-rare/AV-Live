// =====================================================================
//  G10_deep_funk.scd  --  Album G, track 10/15
// =====================================================================

// --- TRACK G10 : "DEEP FUNK" 8 minutes -------------------------------
//   0:00 rhodes -> 1:00 groove -> 2:30 fmBass funk -> 4:30 lead -> 6:30 stab -> 7:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[G10 0:00] rhodes deep...".postln;
    ~bpm = 124;
    ~melodyInst = \rhodes; ~melodyAttack = 0.01; ~melodyRelease = 0.7;
    ~melodyCutoff = 3500; ~melodyAmp = 0.20;
    ~melodyNotes = ~genMelody.(0.55, ~scaleDorian);
    ~kickSteps=(0!16); ~hatSteps=(0!16); ~clapSteps=(0!16); ~acidAmp=0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\dream) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\third);
    60.wait;

    "[G10 1:00] groove funk...".postln;
    ~kickSteps = [1,0,0,0, 1,0,0,1, 0,0,1,0, 1,0,0,0]; ~kickAmp = 0.50;
    ~kickFreq = 50; ~kickPitchAmt = 2.8; ~kickDecay = 0.30; ~kickClick = 0.15;
    ~hatSteps = [1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1]; ~hatAmp = 0.10;
    ~clapSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.32;
    ~reload.value;
    90.wait;

    "[G10 2:30] fmBass funk groove...".postln;
    ~melodyInst = \fmBass;
    ~melodyAttack = 0.005; ~melodyRelease = 0.2; ~melodyCutoff = 2500;
    ~melodyAmp = 0.22;
    ~melodyNotes = [36,0,36,38, 36,0,38,36, 36,0,41,38, 36,0,36,38,
                    36,0,36,38, 36,0,38,41, 36,0,38,36, 36,0,36,0];
    ~reload.value;
    24.do { |k|
        if (0.25.coin) {
            ~melodyNotes = ~mutate.(~melodyNotes, 0.25, ~scaleDorian);
            ~reload.value;
        };
        5.wait;
    };

    "[G10 4:30] supersaw lead...".postln;
    ~melodyInst = \supersaw;
    ~melodyAttack = 0.01; ~melodyRelease = 0.4; ~melodyCutoff = 4500;
    ~melodyAmp = 0.18;
    ~vcfOn !? { ~vcfOn.(\moog, 2500, 0.4) };
    ~melodyNotes = ~genMelody.(0.6, ~scaleMinorPent);
    ~reload.value;
    120.wait;

    "[G10 6:30] stab funk...".postln;
    ~vcfOff !? { ~vcfOff.() };
    ~melodyInst = \stab;
    ~melodyAttack = 0.001; ~melodyRelease = 0.06; ~melodyDrive = 2.8;
    ~melodyAmp = 0.18;
    ~reload.value;
    60.wait;

    "[G10 7:30] outro...".postln;
    ~melodyInst = \rhodes;
    ~melodyAttack = 0.02; ~melodyRelease = 1.2;
    ~reload.value;
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~kickAmp = x * 0.50; ~hatAmp = x * 0.10; ~clapAmp = x * 0.32;
        ~melodyAmp = x * 0.20;
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[G10 8:00] === fin DEEP FUNK ===".postln;
}).play;
"=== TRACK G10 : DEEP FUNK 8 min lancee ===".postln;
)

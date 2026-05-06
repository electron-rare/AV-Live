// =====================================================================
//  H12_nitzhonot_303.scd  --  Album H, track 12/15
// =====================================================================

// --- TRACK H12 : "NITZHONOT 303" 5 minutes ---------------------------
//   0:00 pad -> 0:45 kick + acid -> 2:00 lead anthem -> 4:00 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[H12 0:00] pad uplifting...".postln;
    ~bpm = 142;
    ~melodyInst = \warmPad; ~melodyAttack = 0.5; ~melodyRelease = 1.8;
    ~melodyCutoff = 1800; ~melodyAmp = 0.16;
    ~melodyNotes = [60,0,0,0, 65,0,0,0, 67,0,0,0, 72,0,0,0,
                    74,0,0,0, 72,0,0,0, 67,0,0,0, 65,0,0,0];
    ~kickSteps=(0!16); ~hatSteps=(0!16); ~clapSteps=(0!16);
    ~acidNotes = [36,36,48,36, 41,36,43,41, 36,43,36,41, 48,36,36,43];
    ~acidAccents = [1,0,0,0,1,0,1,0, 0,1,0,0,1,0,0,1];
    ~acidSlides = [0,0,1,0,0,0,0,1, 0,0,0,1,0,0,0,0];
    ~acidCutoff = 800; ~acidRq = 0.15; ~acidDrive = 2.5; ~acidAmp = 0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\trance) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\tranceLayer);
    45.wait;

    "[H12 0:45] kick + acid bouncy...".postln;
    ~kickSteps = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.55;
    ~kickFreq = 60; ~kickPitchAmt = 3.5; ~kickDecay = 0.25; ~kickClick = 0.22;
    ~hatSteps = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~hatAmp = 0.18;
    ~clapSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.32;
    ~acidAmp = 0.32;
    ~reload.value;
    75.wait;

    "[H12 2:00] squareLead anthem...".postln;
    ~melodyInst = \squareLead;
    ~melodyAttack = 0.002; ~melodyRelease = 0.12; ~melodyCutoff = 6000;
    ~melodyAmp = 0.20;
    ~melodyNotes = [60,67,72,77, 75,72,67,77, 65,72,77,79, 77,75,72,65,
                    63,70,75,79, 77,75,70,67, 67,72,77,79, 75,72,67,60];
    ~reload.value;
    24.do { |k|
        if (0.22.coin) { ~acidCutoff = rrand(800, 1800); ~reload.value };
        if (0.18.coin) {
            ~melodyNotes = ~genMelody.(0.65,
                [~scaleMinor, ~scaleHarmonicMin].choose);
            ~reload.value;
        };
        5.wait;
    };

    "[H12 4:00] outro...".postln;
    ~melodyInst = \warmPad;
    ~melodyAttack = 0.6; ~melodyRelease = 2.0;
    ~reload.value;
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~kickAmp = x * 0.55; ~hatAmp = x * 0.18; ~clapAmp = x * 0.32;
        ~acidAmp = x * 0.32; ~melodyAmp = x * 0.20;
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[H12 4:30] === fin NITZHONOT 303 ===".postln;
}).play;
"=== TRACK H12 : NITZHONOT 303 5 min lancee ===".postln;
)

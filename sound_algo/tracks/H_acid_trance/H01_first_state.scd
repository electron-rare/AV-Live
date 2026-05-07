// =====================================================================
//  H01_first_state.scd  --  Album H "Acid Trance", track 1/15
// =====================================================================

// --- TRACK H01 : "FIRST STATE" 4 minutes -----------------------------
//   0:00 pad -> 0:45 kick + acid -> 1:30 lead -> 3:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[H01 0:00] pad intro trance...".postln;
    ~bpm = 138;
    ~melodyInst = \warmPad; ~melodyAttack = 0.6; ~melodyRelease = 2.0;
    ~melodyCutoff = 1800; ~melodyAmp = 0.16;
    ~melodyNotes = [60,0,0,0,0,0,0,0, 67,0,0,0,0,0,0,0,
                    63,0,0,0,0,0,0,0, 70,0,0,0,0,0,0,0];
    ~kickSteps=(0!16); ~hatSteps=(0!16); ~clapSteps=(0!16);
    ~acidNotes = [36,36,48,36, 39,36,43,39, 36,41,36,39, 43,36,36,41];
    ~acidAccents = [1,0,0,0,1,0,1,0, 0,1,0,0,1,0,0,1];
    ~acidSlides = [0,0,1,0,0,0,0,1, 0,0,0,1,0,0,0,0];
    ~acidCutoff = 600; ~acidRq = 0.18; ~acidDrive = 2.5; ~acidAmp = 0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\trance) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\tranceLayer);
    45.wait;

    "[H01 0:45] kick + acid entre...".postln;
    ~kickSteps = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.55;
    ~kickFreq = 60; ~kickPitchAmt = 3.5; ~kickDecay = 0.25; ~kickClick = 0.20;
    ~hatSteps = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~hatAmp = 0.16;
    ~clapSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.30;
    ~acidAmp = 0.30;
    ~reload.value;
    45.wait;

    "[H01 1:30] squareLead arpege...".postln;
    ~melodyInst = \squareLead;
    ~melodyAttack = 0.003; ~melodyRelease = 0.15; ~melodyCutoff = 5500;
    ~melodyAmp = 0.18;
    ~melodyNotes = [60,67,72,75, 70,67,63,67, 65,72,75,77, 72,70,67,63,
                    63,70,75,79, 75,72,70,67, 60,65,70,75, 67,63,60,67];
    ~reload.value;
    24.do { |k|
        if (0.20.coin) { ~acidCutoff = rrand(800, 1500); ~reload.value };
        if (0.15.coin) {
            ~melodyNotes = ~genMelody.(0.6,
                [~scaleMinor, ~scaleHarmonicMin].choose);
            ~reload.value;
        };
        5.wait;
    };

    "[H01 3:30] outro fade...".postln;
    ~melodyInst = \warmPad;
    ~melodyAttack = 0.6; ~melodyRelease = 2.5;
    ~reload.value;
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~kickAmp = x * 0.55; ~hatAmp = x * 0.16; ~clapAmp = x * 0.30;
        ~acidAmp = x * 0.30; ~melodyAmp = x * 0.18;
        ~acidCutoff = 200 + (x * 1300);
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[H01 4:00] === fin FIRST STATE ===".postln;
}).play;
"=== TRACK H01 : FIRST STATE 4 min lancee ===".postln;
)

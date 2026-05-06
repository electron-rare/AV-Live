// =====================================================================
//  H02_goa_dream.scd  --  Album H, track 2/15
// =====================================================================

// --- TRACK H02 : "GOA DREAM" 5 minutes -------------------------------
//   0:00 drone -> 1:00 kick goa -> 2:30 acid + lead -> 4:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[H02 0:00] drone goa intro...".postln;
    ~bpm = 140;
    ~melodyInst = \drone; ~melodyAttack = 1.0; ~melodyRelease = 2.5;
    ~melodyCutoff = 1500; ~melodyAmp = 0.18;
    ~melodyNotes = [48,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,
                    48,0,0,0,0,0,0,0, 55,0,0,0,0,0,0,0];
    ~kickSteps=(0!16); ~hatSteps=(0!16); ~clapSteps=(0!16);
    ~acidNotes = [36,36,48,36, 41,36,43,41, 36,43,36,41, 48,36,36,43];
    ~acidAccents = [1,0,0,0,1,0,1,0, 0,1,0,0,1,0,0,1];
    ~acidSlides = [0,0,1,0,0,0,0,1, 0,0,0,1,0,0,0,0];
    ~acidCutoff = 700; ~acidRq = 0.15; ~acidDrive = 2.5; ~acidAmp = 0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\cosmic) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\bassline);
    60.wait;

    "[H02 1:00] kick goa direct...".postln;
    ~kickSteps = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.55;
    ~kickFreq = 60; ~kickPitchAmt = 4.0; ~kickDecay = 0.25; ~kickClick = 0.25;
    ~hatSteps = [0,1,1,1, 0,1,1,1, 0,1,1,1, 0,1,1,1]; ~hatAmp = 0.18;
    ~acidAmp = 0.32;
    ~reload.value;
    90.wait;

    "[H02 2:30] acid evolve + squareLead...".postln;
    ~melodyInst = \squareLead;
    ~melodyAttack = 0.003; ~melodyRelease = 0.12; ~melodyCutoff = 5500;
    ~melodyAmp = 0.18;
    ~melodyNotes = ~genMelody.(0.65, ~scaleHijaz);
    ~reload.value;
    24.do { |k|
        if (0.25.coin) { ~acidCutoff = rrand(700, 1800); ~reload.value };
        if (0.20.coin) {
            ~melodyNotes = ~mutate.(~melodyNotes, 0.3, ~scaleHijaz);
            ~reload.value;
        };
        5.wait;
    };

    "[H02 4:30] outro...".postln;
    ~melodyInst = \drone;
    ~melodyAttack = 1.0; ~melodyRelease = 2.5;
    ~reload.value;
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~kickAmp = x * 0.55; ~hatAmp = x * 0.18;
        ~acidAmp = x * 0.32; ~melodyAmp = x * 0.18;
        ~acidCutoff = 200 + (x * 1500);
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[H02 5:00] === fin GOA DREAM ===".postln;
}).play;
"=== TRACK H02 : GOA DREAM 5 min lancee ===".postln;
)

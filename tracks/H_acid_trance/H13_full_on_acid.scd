// =====================================================================
//  H13_full_on_acid.scd  --  Album H, track 13/15
// =====================================================================

// --- TRACK H13 : "FULL ON ACID" 4 minutes ----------------------------
//   0:00 kick + acid full -> 1:00 squareLead -> 3:00 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[H13 0:00] kick + acid direct full...".postln;
    ~bpm = 145;
    ~kickSteps = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.58;
    ~kickFreq = 62; ~kickPitchAmt = 4.0; ~kickDecay = 0.22; ~kickClick = 0.28;
    ~hatSteps = [0,1,1,1, 0,1,1,1, 0,1,1,1, 0,1,1,1]; ~hatAmp = 0.18;
    ~clapSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.32;
    ~snareSteps=(0!16); ~percSteps=(0!16);
    ~acidNotes = [36,36,48,36, 41,36,43,41, 36,43,36,41, 48,36,36,43];
    ~acidAccents = [1,0,0,0,1,0,1,0, 0,1,0,0,1,0,0,1];
    ~acidSlides = [0,0,1,0,0,0,0,1, 0,0,0,1,0,0,0,0];
    ~acidCutoff = 1200; ~acidRq = 0.10; ~acidDrive = 3.5; ~acidAmp = 0.35;
    ~melodyInst = \warmPad; ~melodyAmp = 0.10;
    ~melodyNotes = [60,0,0,0, 67,0,0,0, 70,0,0,0, 75,0,0,0,
                    72,0,0,0, 70,0,0,0, 67,0,0,0, 60,0,0,0];
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\trance) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\tranceLayer);
    60.wait;

    "[H13 1:00] squareLead arp...".postln;
    ~melodyInst = \squareLead;
    ~melodyAttack = 0.002; ~melodyRelease = 0.12; ~melodyCutoff = 6000;
    ~melodyAmp = 0.20;
    ~melodyNotes = ~genMelody.(0.7, ~scaleMinor);
    ~vcfOn !? { ~vcfOn.(\moog, 2800, 0.4) };
    ~reload.value;
    24.do { |k|
        if (0.25.coin) { ~acidCutoff = rrand(1000, 2000); ~reload.value };
        if (0.20.coin) {
            ~melodyNotes = ~mutate.(~melodyNotes, 0.3, ~scaleMinor);
            ~reload.value;
        };
        5.wait;
    };

    "[H13 3:00] outro...".postln;
    ~vcfOff !? { ~vcfOff.() };
    ~melodyInst = \warmPad;
    ~melodyAttack = 0.5; ~melodyRelease = 1.8;
    ~reload.value;
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~kickAmp = x * 0.58; ~hatAmp = x * 0.18; ~clapAmp = x * 0.32;
        ~acidAmp = x * 0.35; ~melodyAmp = x * 0.20;
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[H13 3:30] === fin FULL ON ACID ===".postln;
}).play;
"=== TRACK H13 : FULL ON ACID 4 min lancee ===".postln;
)

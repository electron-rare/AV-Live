// =====================================================================
//  H07_hard_trance.scd  --  Album H, track 7/15
// =====================================================================

// --- TRACK H07 : "HARD TRANCE" 5 minutes -----------------------------
//   0:00 kick hard direct -> 1:00 acid + lead -> 3:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[H07 0:00] kick hard immediate...".postln;
    ~bpm = 145;
    ~kickSteps = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.60;
    ~kickFreq = 65; ~kickPitchAmt = 4.5; ~kickDecay = 0.22; ~kickClick = 0.35;
    ~kickDrive = 2.0;
    ~hatSteps = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~hatAmp = 0.20;
    ~clapSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.35;
    ~snareSteps=(0!16); ~percSteps=(0!16);
    ~acidNotes = [36,36,48,36, 39,36,43,39, 36,41,36,39, 43,36,36,41];
    ~acidAccents = [1,0,0,0,1,0,1,0, 0,1,0,0,1,0,0,1];
    ~acidSlides = [0,0,1,0,0,0,0,1, 0,0,0,1,0,0,0,0];
    ~acidCutoff = 1200; ~acidRq = 0.10; ~acidDrive = 3.5; ~acidAmp = 0.32;
    ~melodyInst = \warmPad; ~melodyAmp = 0.10;
    ~melodyNotes = [60,0,0,0, 67,0,0,0, 70,0,0,0, 72,0,0,0,
                    75,0,0,0, 72,0,0,0, 67,0,0,0, 60,0,0,0];
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\industrial) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\tranceLayer);
    60.wait;

    "[H07 1:00] hardLead...".postln;
    ~melodyInst = \hardLead;
    ~melodyAttack = 0.002; ~melodyRelease = 0.20; ~melodyCutoff = 5500;
    ~melodyAmp = 0.20;
    ~melodyNotes = ~genMelody.(0.65, ~scaleMinor);
    ~vcfOn !? { ~vcfOn.(\moog, 2800, 0.4) };
    ~reload.value;
    30.do { |k|
        if (0.25.coin) { ~acidCutoff = rrand(1000, 2000); ~reload.value };
        if (0.20.coin) {
            ~melodyNotes = ~mutate.(~melodyNotes, 0.3, ~scaleMinor);
            ~reload.value;
        };
        5.wait;
    };

    "[H07 3:30] outro...".postln;
    ~vcfOff !? { ~vcfOff.() };
    ~melodyInst = \warmPad;
    ~melodyAttack = 0.6; ~melodyRelease = 2.0;
    ~reload.value;
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~kickAmp = x * 0.60; ~hatAmp = x * 0.20; ~clapAmp = x * 0.35;
        ~acidAmp = x * 0.32; ~melodyAmp = x * 0.20;
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[H07 4:00] === fin HARD TRANCE ===".postln;
}).play;
"=== TRACK H07 : HARD TRANCE 5 min lancee ===".postln;
)

// =====================================================================
//  H04_psy_acid.scd  --  Album H, track 4/15
// =====================================================================

// --- TRACK H04 : "PSY ACID" 7 minutes --------------------------------
//   0:00 pad -> 1:00 kick psy -> 2:30 squareLead -> 4:30 hooverbass -> 6:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[H04 0:00] pad psy intro...".postln;
    ~bpm = 144;
    ~melodyInst = \warmPad; ~melodyAttack = 0.6; ~melodyRelease = 2.0;
    ~melodyCutoff = 1800; ~melodyAmp = 0.16;
    ~melodyNotes = [60,0,0,0, 63,0,0,0, 67,0,0,0, 70,0,0,0,
                    72,0,0,0, 70,0,0,0, 67,0,0,0, 63,0,0,0];
    ~kickSteps=(0!16); ~hatSteps=(0!16); ~clapSteps=(0!16);
    ~acidNotes = [36,36,48,36, 39,36,43,39, 36,41,36,39, 43,36,36,41];
    ~acidAccents = [1,0,0,0,1,0,1,0, 0,1,0,0,1,0,0,1];
    ~acidSlides = [0,0,1,0,0,0,0,1, 0,0,0,1,0,0,0,0];
    ~acidCutoff = 700; ~acidRq = 0.15; ~acidDrive = 2.8; ~acidAmp = 0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\trance) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\tranceLayer);
    60.wait;

    "[H04 1:00] kick psy + offbeat hat...".postln;
    ~kickSteps = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.58;
    ~kickFreq = 62; ~kickPitchAmt = 4.0; ~kickDecay = 0.22; ~kickClick = 0.28;
    ~hatSteps = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~hatAmp = 0.18;
    ~acidAmp = 0.32;
    ~reload.value;
    90.wait;

    "[H04 2:30] squareLead psy...".postln;
    ~melodyInst = \squareLead;
    ~melodyAttack = 0.002; ~melodyRelease = 0.10; ~melodyCutoff = 6000;
    ~melodyAmp = 0.18;
    ~melodyNotes = ~genMelody.(0.65, ~scaleHijaz);
    ~reload.value;
    24.do { |k|
        if (0.25.coin) { ~acidCutoff = rrand(700, 1800); ~reload.value };
        if (0.20.coin) {
            ~melodyNotes = ~mutate.(~melodyNotes, 0.3, ~scaleHijaz);
            ~reload.value;
        };
        if (0.10.coin) { ~acidSlides = ~genAcidSlides.(0.4); ~reload.value };
        5.wait;
    };

    "[H04 4:30] hooverbass massif...".postln;
    ~melodyInst = \hooverbass;
    ~melodyAttack = 0.005; ~melodyRelease = 0.25; ~melodyCutoff = 1800;
    ~melodyAmp = 0.20;
    ~melodyNotes = [36,0,0,0, 39,0,0,0, 41,0,0,0, 36,0,0,0,
                    36,0,0,0, 41,0,0,0, 43,0,0,0, 39,0,0,0];
    ~vcfOn !? { ~vcfOn.(\moog, 1500, 0.45) };
    ~reload.value;
    120.wait;

    "[H04 6:30] outro...".postln;
    ~vcfOff !? { ~vcfOff.() };
    ~melodyInst = \warmPad;
    ~melodyAttack = 0.6; ~melodyRelease = 2.5;
    ~reload.value;
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~kickAmp = x * 0.58; ~hatAmp = x * 0.18;
        ~acidAmp = x * 0.32; ~melodyAmp = x * 0.20;
        ~acidCutoff = 200 + (x * 1500);
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[H04 7:00] === fin PSY ACID ===".postln;
}).play;
"=== TRACK H04 : PSY ACID 7 min lancee ===".postln;
)

// =====================================================================
//  H09_acid_cathedral.scd  --  Album H, track 9/15
// =====================================================================

// --- TRACK H09 : "ACID CATHEDRAL" 7 minutes --------------------------
//   0:00 choir -> 1:00 kick -> 2:30 acid + organ -> 4:30 supersaw -> 6:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[H09 0:00] choir cathedral...".postln;
    ~bpm = 140;
    ~melodyInst = \choir; ~melodyAttack = 0.5; ~melodyRelease = 1.8;
    ~melodyCutoff = 2800; ~melodyAmp = 0.20;
    ~melodyNotes = [60,0,0,0, 65,0,0,0, 67,0,0,0, 72,0,0,0,
                    70,0,0,0, 67,0,0,0, 65,0,0,0, 60,0,0,0];
    ~kickSteps=(0!16); ~hatSteps=(0!16); ~clapSteps=(0!16);
    ~acidNotes = [36,36,48,36, 39,36,43,39, 36,41,36,39, 43,36,36,41];
    ~acidAccents = [1,0,0,0,1,0,1,0, 0,1,0,0,1,0,0,1];
    ~acidSlides = [0,0,1,0,0,0,0,1, 0,0,0,1,0,0,0,0];
    ~acidCutoff = 700; ~acidRq = 0.15; ~acidDrive = 2.5; ~acidAmp = 0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\space) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\tranceLayer);
    60.wait;

    "[H09 1:00] kick liturgique + acid...".postln;
    ~kickSteps = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.55;
    ~kickFreq = 58; ~kickPitchAmt = 3.5; ~kickDecay = 0.30; ~kickClick = 0.20;
    ~hatSteps = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~hatAmp = 0.15;
    ~clapSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.30;
    ~acidAmp = 0.30;
    ~reload.value;
    90.wait;

    "[H09 2:30] organ acid cathedral...".postln;
    ~melodyInst = \organLead;
    ~melodyAttack = 0.005; ~melodyRelease = 0.18; ~melodyCutoff = 4500;
    ~melodyAmp = 0.18;
    ~melodyNotes = ~genMelody.(0.5, ~scaleHarmonicMin);
    ~reload.value;
    24.do { |k|
        if (0.22.coin) { ~acidCutoff = rrand(700, 1700); ~reload.value };
        if (0.18.coin) {
            ~melodyNotes = ~mutate.(~melodyNotes, 0.25, ~scaleHarmonicMin);
            ~reload.value;
        };
        5.wait;
    };

    "[H09 4:30] supersaw cathedral...".postln;
    ~melodyInst = \supersaw;
    ~melodyAttack = 0.005; ~melodyRelease = 0.4; ~melodyCutoff = 5000;
    ~melodyAmp = 0.20;
    ~vcfOn !? { ~vcfOn.(\moog, 2500, 0.4) };
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.2, 2500, \sin, 5000) };
    ~reload.value;
    120.wait;

    "[H09 6:30] outro choir...".postln;
    ~vcfOff !? { ~vcfOff.() };
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~melodyInst = \choir;
    ~melodyAttack = 0.5; ~melodyRelease = 2.0;
    ~reload.value;
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~kickAmp = x * 0.55; ~hatAmp = x * 0.15; ~clapAmp = x * 0.30;
        ~acidAmp = x * 0.30; ~melodyAmp = x * 0.20;
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[H09 7:00] === fin ACID CATHEDRAL ===".postln;
}).play;
"=== TRACK H09 : ACID CATHEDRAL 7 min lancee ===".postln;
)

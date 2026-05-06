// =====================================================================
//  A14_industrial_acid.scd  --  Album A "Acid Journey", track 14/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK A14 : "INDUSTRIAL ACID" 5 minutes ------------------------
//   0:00 metal pulse -> 1:00 fm growl -> 2:30 303 grind -> 3:30 climax -> 4:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[A14 0:00] metal pulse -- broken kick + ring mod hat...".postln;
    ~bpm = 148;
    ~kickFreq = 50; ~kickPitchAmt = 3.5; ~kickDecay = 0.30;
    ~kickDrive = 3.2; ~kickClick = 0.35; ~kickAmp = 0.62;
    ~kickSteps = [1,0,0,1, 0,1,0,0, 1,0,1,0, 0,1,0,1];
    ~hatSteps = [0,1,1,0, 1,0,1,1, 0,1,0,1, 1,1,0,1]; ~hatAmp = 0.16;
    ~percSteps = [0,0,1,0, 0,1,0,0, 1,0,0,1, 0,0,1,0]; ~percAmp = 0.28;
    ~acidAmp = 0; ~melodyAmp = 0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\industrial) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\off);
    60.wait;

    "[A14 1:00] fm growl -- hungarian metal lead...".postln;
    ~melodyInst = \fm_lead;
    ~melodyAttack = 0.005; ~melodyRelease = 0.20; ~melodyCutoff = 2200;
    ~melodyAmp = 0.16; ~melodyDrive = 3.0;
    ~melodyNotes = [60,0,63,0, 66,0,71,67, 0,68,0,63, 66,0,71,0,
                    62,0,66,63, 0,67,71,68, 0,63,0,66, 71,0,0,0];
    ~reload.value;
    Pdef(\melodySeq).play;
    ~vcfOn !? { ~vcfOn.(\formant, 1400, 0.50) };
    // 90s fm metal evolution
    18.do { |k|
        if (0.30.coin) {
            ~melodyNotes = ~genMelody.(0.60, ~scaleHungarian);
            ~reload.value;
        };
        if (0.18.coin) {
            ~melodyNotes = ~mutate.(~melodyNotes, 0.30, ~scaleHungarian);
            ~reload.value;
        };
        if (0.15.coin) { ~melodyCutoff = rrand(1700, 2700); ~reload.value };
        5.wait;
    };

    "[A14 2:30] 303 grind -- distorted acid bass...".postln;
    ~acidAmp = 0.32; ~acidCutoff = 1000; ~acidRq = 0.12; ~acidDrive = 3.5;
    ~acidNotes = [36,36,49,36, 42,36,48,42, 36,49,36,42, 48,36,43,36];
    ~acidSlides = [0,0,1,0, 0,1,0,0, 0,0,0,0, 1,0,0,1];
    ~reload.value;
    Pdef(\acidSeq).play;
    // 60s 303 grind
    12.do { |k|
        if (0.25.coin) {
            ~acidNotes = ~genMelody.(0.80, ~scalePhrygian);
            ~acidSlides = ~genAcidSlides.(0.40);
            ~reload.value;
        };
        5.wait;
    };

    "[A14 3:30] climax -- everything roars...".postln;
    ~kickDrive = 4.0; ~acidDrive = 4.0;
    ~melodyAmp = 0.20; ~melodyDrive = 4.0;
    ~percAmp = 0.40;
    ~stutter !? { ~stutter.(12, 1.5) };
    ~reload.value;
    60.wait;

    "[A14 4:30] outro -- collapse...".postln;
    ~vcfOff !? { ~vcfOff.() };
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~kickAmp = x * 0.62; ~hatAmp = x * 0.16; ~percAmp = x * 0.40;
        ~melodyAmp = x * 0.20; ~acidAmp = x * 0.32;
        ~reload.value;
        1.wait;
    };
    [\kickSeq, \hatSeq, \percSeq, \acidSeq, \melodySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[A14 5:00] === fin INDUSTRIAL ACID ===".postln;
}).play;
"=== TRACK A14 : INDUSTRIAL ACID 5 min lancee ===".postln;
)

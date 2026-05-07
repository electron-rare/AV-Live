// =====================================================================
//  A11_trance_acid.scd  --  Album A "Acid Journey", track 11/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK A11 : "TRANCE ACID (Goa)" 7 minutes ----------------------
//   0:00 trance pulse -> 1:30 303 climb -> 3:00 supersaw lead -> 5:00 break -> 5:30 drop
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[A11 0:00] trance pulse -- offbeat bass...".postln;
    ~bpm = 138;
    ~kickFreq = 56; ~kickPitchAmt = 2.8; ~kickDecay = 0.30;
    ~kickDrive = 1.8; ~kickClick = 0.22; ~kickAmp = 0.60;
    ~kickSteps = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0];
    ~hatSteps = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~hatAmp = 0.14;
    ~clapSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.50;
    ~acidAmp = 0; ~melodyAmp = 0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\trance) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\bassline);
    Pdef(\harmonySeq).play;
    90.wait;

    "[A11 1:30] 303 climb -- pent climb...".postln;
    ~acidAmp = 0.28; ~acidCutoff = 600; ~acidRq = 0.16; ~acidDrive = 2.2;
    ~acidNotes = [36,36,48,36, 41,36,48,43, 36,48,36,41, 48,36,43,36];
    ~acidSlides = [0,0,1,0, 0,0,0,1, 0,0,0,0, 0,0,0,1];
    ~reload.value;
    Pdef(\acidSeq).play;
    // 90s climb cutoff
    18.do { |k|
        ~acidCutoff = 550 + (k * 35);
        if (0.20.coin) {
            ~acidNotes = ~genMelody.(0.7, ~scaleMinorPent);
            ~acidSlides = ~genAcidSlides.(0.30);
        };
        ~reload.value;
        5.wait;
    };

    "[A11 3:00] supersaw lead -- uplifting trance lead...".postln;
    ~melodyInst = \supersaw;
    ~melodyAttack = 0.012; ~melodyRelease = 0.55; ~melodyCutoff = 2800;
    ~melodyAmp = 0.18;
    ~melodyNotes = [72,0,75,0, 79,0,77,75, 70,72,75,77, 79,0,82,0,
                    77,75,72,0, 70,72,75,0, 77,75,72,70, 72,0,0,0];
    ~enableHarmony.(\third);
    ~reload.value;
    Pdef(\melodySeq).play;
    // 120s lead trance
    24.do { |k|
        if (0.25.coin) {
            ~melodyNotes = ~genMelody.(0.60, ~scaleMinorPent);
            ~reload.value;
        };
        if (0.18.coin) {
            ~melodyNotes = ~mutate.(~melodyNotes, 0.25, ~scaleMinorPent);
            ~reload.value;
        };
        if (0.15.coin) { ~melodyCutoff = rrand(2200, 3500); ~reload.value };
        5.wait;
    };

    "[A11 5:00] break -- kick out, lead alone reverb wash...".postln;
    [\kickSeq, \hatSeq, \clapSeq, \acidSeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\space) };
    ~melodyAttack = 0.08; ~melodyRelease = 1.5;
    ~reload.value;
    30.wait;

    "[A11 5:30] drop -- everything back, peak...".postln;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~melodyAttack = 0.012; ~melodyRelease = 0.55;
    ~bpm = 140;
    ~acidCutoff = 1400; ~acidDrive = 3.0;
    ~kickDrive = 2.2; ~melodyAmp = 0.20;
    ~hatSteps = [1,0,1,1, 1,0,1,1, 1,0,1,1, 1,0,1,1]; ~hatAmp = 0.16;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\trance) };
    ~reload.value;
    60.wait;

    "[A11 6:30] outro -- close down...".postln;
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~kickAmp = x * 0.60; ~hatAmp = x * 0.16; ~clapAmp = x * 0.50;
        ~melodyAmp = x * 0.20; ~acidAmp = x * 0.28;
        ~reload.value;
        1.wait;
    };
    [\kickSeq, \hatSeq, \clapSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[A11 7:00] === fin TRANCE ACID ===".postln;
}).play;
"=== TRACK A11 : TRANCE ACID 7 min lancee ===".postln;
)

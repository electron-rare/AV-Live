// =====================================================================
//  B_deep_to_hard.scd
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
//  PREREQUIS : engine.scd evalue (les SynthDef + helpers doivent exister).
// =====================================================================

// --- TRACK B : "DEEP TO HARD" 8 minutes ------------------------------
//   demarre dub, monte progressivement vers hard techno
(
~track !? { ~track.stop };
~track = Routine({
    "[B 0:00] dub start -- kick T3 boomy + melody PAD...".postln;
    ~bpm = 110; ~acidCutoff = 400; ~acidRq = 0.2; ~acidDrive = 1.6; ~acidAmp = 0.22;
    ~kickSteps = [1,0,0,0, 0,0,0,0, 1,0,0,0, 0,0,0,0];
    ~kickAmp = 0.45; ~hatAmp = 0.08;
    ~kickFreq = 48; ~kickPitchAmt = 2.5; ~kickDecay = 0.6;
    ~kickDrive = 1.2; ~kickClick = 0.08;
    ~melodyInst = \pad;                              // PAD pour dub
    ~hatSteps = [0,0,0,0, 0,0,1,0, 0,0,0,0, 0,0,1,0];
    ~melodyNotes = [60,0,0,0,63,0,0,0, 67,0,0,0,70,0,0,0,
                    72,0,0,0,70,0,0,0, 67,0,0,0,63,0,0,0];
    ~melodyAttack = 0.4; ~melodyRelease = 1.5; ~melodyAmp = 0.14;
    ~melodyCutoff = 1500;
    TempoClock.default.tempo = ~bpm/60; ~reload.value;
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).play };
    ~enableHarmony.(\bassline);
    // 150s de dub avec nappes qui mutent doucement
    30.do { |k|
        // Mutation legere du pad toutes les ~10s
        if (0.20.coin) {
            ~melodyNotes = ~mutate.(~melodyNotes, 0.15,
                [~scaleMinor, ~scaleDorian, ~scalePhrygian].choose);
            ~reload.value;
        };
        // Cutoff melody varie (atmosphere)
        if (0.20.coin) { ~melodyCutoff = rrand(1200, 2200); ~reload.value };
        // Acid cutoff doux
        if (0.15.coin) { ~acidCutoff = rrand(300, 700); ~reload.value };
        // Octavate occasionnelle
        if (0.05.coin) { ~melodyNotes = ~octavate.(~melodyNotes, 0.2); ~reload.value };
        5.wait;
    };

    "[B 2:30] tempo monte 110->125 -- melody SAW3 (epaissit)...".postln;
    ~melodyInst = \saw3;                             // SAW3 pour epaisseur
    ~melodyAttack = 0.005; ~melodyRelease = 0.4; ~melodyDrive = 1.4;
    ~reload.value;
    30.do { |k|
        ~bpm = 110 + ((k + 1) * 0.5);
        TempoClock.default.tempo = ~bpm / 60;
        2.wait;
    };
    // 3:30

    "[B 3:30] kick 4/4 + acid ouvre -- kick T1 + melody PLUCK...".postln;
    ~kickSteps = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0];
    ~kickAmp = 0.5;
    ~kickFreq = 55; ~kickPitchAmt = 3.0; ~kickDecay = 0.32;
    ~kickDrive = 1.3; ~kickClick = 0.2;
    ~melodyInst = \pluck;                            // PLUCK pour la transition
    ~melodyAttack = 0.001; ~melodyRelease = 0.5; ~melodyCutoff = 5000;
    ~acidCutoff = 900; ~acidDrive = 2.2; ~acidAmp = 0.28;
    ~hatSteps = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0];
    ~hatAmp = 0.14;
    ~reload.value;
    // 90s avec acid qui mute progressivement
    18.do { |k|
        if (0.3.coin) {
            ~acidNotes = ~genAcidNotes.value;
            ~acidAccents = ~genAcidAccents.(0.4);
            ~acidSlides = ~genAcidSlides.(0.3);
            ~reload.value;
        };
        if (0.2.coin) { ~acidCutoff = rrand(700, 1400); ~reload.value };
        if (0.15.coin) {
            // ghost notes occasionnelles dans le kick
            ~kickSteps = ~genKickPattern.(0.25);
            ~reload.value;
        };
        5.wait;
    };
    // remettre kick 4/4 propre avant la suite
    ~kickSteps = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~reload.value;

    "[B 5:00] tempo monte 125->140...".postln;
    30.do { |k|
        ~bpm = 125 + ((k + 1) * 0.5);
        TempoClock.default.tempo = ~bpm / 60;
        2.wait;
    };
    // 6:00

    "[B 6:00] hard push -- kick T4 distordu...".postln;
    ~kickSteps = [1,0,1,0, 1,0,1,0, 1,0,1,0, 1,0,1,0];
    ~kickFreq = 60; ~kickPitchAmt = 5.0; ~kickDecay = 0.28;
    ~kickDrive = 3.5; ~kickClick = 0.3;              // T4 distordu
    ~hatSteps = [0,1,1,1, 0,1,1,0, 0,1,1,1, 0,1,1,0];
    ~hatAmp = 0.15;
    ~acidCutoff = 1500; ~acidRq = 0.08; ~acidDrive = 3.5;
    ~melodyAmp = 0;
    ~reload.value;
    90.wait;
    "[B 7:30] new -- rhodes + ml5 + fxPreset dream...".postln;
    ~melodyInst = \rhodes;
    ~melodyAttack = 0.01; ~melodyRelease = 0.7; ~melodyCutoff = 3500;
    ~melodyAmp = 0.16;
    ~melodyNotes = (~ml5 ? [60,0,0,0,0,0,0,0,67,0,0,0,0,0,0,0]).copy;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.2, 1200, \tri, 2800) };
    ~fxPreset !? { ~fxPreset.(\dream) };
    TempoClock.default.tempo = ~bpm/60; ~reload.value;
    40.wait;

    "[B 8:10] new -- vcf ladder + hooverbass push...".postln;
    ~melodyInst = \hooverbass;
    ~melodyAttack = 0.005; ~melodyRelease = 0.3; ~melodyCutoff = 1800;
    ~melodyAmp = 0.18;
    ~vcfOn !? { ~vcfOn.(\ladder, 1500, 0.5) };
    ~breakdown !? { ~breakdown.(8) };
    ~fxPreset !? { ~fxPreset.(\industrial) };
    TempoClock.default.tempo = ~bpm/60; ~reload.value;
    25.wait;
    ~vcfOff !? { ~vcfOff.() };
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };


    "[B 8:35] outro -- melody PAD qui revient...".postln;
    ~melodyInst = \pad;                              // PAD pour finir
    ~melodyAttack = 0.5; ~melodyRelease = 2.0; ~melodyAmp = 0.10;
    ~reload.value;
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~acidCutoff = 200 + (x * 1300);
        ~acidAmp = x * 0.32; ~kickAmp = x * 0.5; ~hatAmp = x * 0.15;
        ~melodyAmp = x * 0.10;
        ~reload.value;
        1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    "[B 9:05] === fin DEEP TO HARD ===".postln;
}).play;
"=== TRACK B : DEEP TO HARD 8 min lancee ===".postln;
)


// =====================================================================
//  TWEAKS LIVE -- voir palette/tweaks_template.scd (charge dans 00_load)
//                 Ouvrir tweaks_template.scd et Cmd+Entree sur une ligne.
// =====================================================================

// =====================================================================
//  SECTIONS / JUMP TO -- voir jump.scd
//  Ouvrir jump.scd, evaluer SETUP JUMP, puis le bloc TRACK X correspondant,
//  puis Cmd+Entree sur la ligne ~jumpTo.('X', 'slug').
// =====================================================================

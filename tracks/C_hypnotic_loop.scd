// =====================================================================
//  C_hypnotic_loop.scd
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
//  PREREQUIS : engine.scd evalue (les SynthDef + helpers doivent exister).
// =====================================================================

// --- TRACK C : "HYPNOTIC LOOP" 10 minutes ----------------------------
//   minimal qui evolue lentement, melodie ostinato qui se developpe
(
~track !? { ~track.stop };
~track = Routine({
    "[C 0:00] hypnotic -- kick T6 + fmBell DUBSTEP wobble...".postln;
    ~bpm = 126; ~acidCutoff = 600; ~acidRq = 0.2; ~acidDrive = 1.8; ~acidAmp = 0.26;
    ~kickFreq = 70; ~kickPitchAmt = 3.5; ~kickDecay = 0.22;
    ~kickDrive = 2.0; ~kickClick = 0.35;
    ~melodyInst = \fmBell;                           // FM Bell dubstep
    ~melodyAttack = 0.005; ~melodyRelease = 0.4; ~melodyCutoff = 400;
    ~melodyDrive = 3.5;
    ~melodyWobbleRate = 4;
    ~melodyWobbleDepth = 1800;
    ~melodyWobbleShape = 0;
    ~melodySubAmt = 0.9;          // SUB MASSIF dubstep
    ~acidNotes = [36,0,36,0,36,0,41,0, 36,0,36,0,36,0,39,0];
    ~acidAccents = [1,0,0,0,1,0,0,0, 1,0,0,0,1,0,0,0];
    ~acidSlides = [0,0,0,0,0,0,1,0, 0,0,0,0,0,0,1,0];
    ~kickSteps = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0];
    ~kickAmp = 0.5;
    ~hatSteps = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0];
    ~hatAmp = 0.10;
    ~melodyNotes = [60,0,0,67,0,70,0,67, 60,0,0,67,0,70,0,72,
                    60,0,0,67,0,70,0,67, 63,0,0,70,0,72,0,75];
    ~melodyAmp = 0.13;
    TempoClock.default.tempo = ~bpm/60; ~reload.value;
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).play };
    ~enableHarmony.(\arp);
    // 120s avec ostinato qui mute lentement (mutations + scales variees)
    24.do { |k|
        // Mutation/regen avec scales japonaise/dorian/harmonique (timbre fmBell aime)
        if (0.2.coin) {
            ~melodyNotes = ~genMelody.(0.5,
                [~scaleMinorPent, ~scaleDorian, ~scaleJapanese, ~scaleHarmonicMin].choose);
            ~reload.value;
        };
        // Mutation legere du pattern courant
        if (0.15.coin) {
            ~melodyNotes = ~mutate.(~melodyNotes, 0.15);
            ~reload.value;
        };
        if (0.15.coin) { ~melodyCutoff = rrand(1500, 2500); ~reload.value };
        if (0.1.coin)  { ~acidAccents = ~genAcidAccents.(0.3); ~reload.value };
        // Octavate occasionnelle
        if (0.05.coin) { ~melodyNotes = ~octavate.(~melodyNotes, 0.2); ~reload.value };
        5.wait;
    };

    "[C 2:00] cutoff up doucement...".postln;
    60.do { |k|
        var x = (k + 1) / 60;
        ~acidCutoff = 600 + (x * 1500);
        ~melodyCutoff = 1800 + (x * 1500);
        ~reload.value;
        2.wait;
    };
    // 4:00

    "[C 4:00] hat 16ths -- kick T1 + melody SAW3 + variations...".postln;
    ~hatSteps = [1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1];
    ~hatAmp = 0.08;
    ~kickFreq = 55; ~kickPitchAmt = 3.0; ~kickDecay = 0.32;
    ~kickDrive = 1.3; ~kickClick = 0.2;
    ~melodyInst = \saw3;
    ~melodyAttack = 0.005; ~melodyRelease = 0.25; ~melodyCutoff = 2200;
    ~melodyDrive = 1.4;
    ~reload.value;
    // 120s avec melodie qui se transforme (mutate + transpose + scales)
    24.do { |k|
        // Generation nouvelle (40%) ou mutation (60%) du pattern
        if (0.25.coin) {
            if (0.4.coin) {
                ~melodyNotes = ~genMelody.(0.5,
                    [~scaleMinorPent, ~scaleDorian, ~scaleHigh].choose);
            } {
                ~melodyNotes = ~mutate.(~melodyNotes, 0.2);
            };
            ~reload.value;
        };
        if (0.15.coin) { ~melodyCutoff = rrand(1800, 3500); ~reload.value };
        // Tous les ~30s, transposition par intervalle musical
        if (0.07.coin) {
            ~melodyNotes = ~transpose.(~melodyNotes, [-7, -5, 5, 7].choose);
            ~reload.value;
            "  -> melodie transposee".postln;
        };
        // Octavate occasionnelle
        if (0.05.coin) { ~melodyNotes = ~octavate.(~melodyNotes, 0.2); ~reload.value };
        5.wait;
    };

    "[C 6:00] resonance push -- kick T2 + melody mute progressivement...".postln;
    ~kickFreq = 65; ~kickPitchAmt = 4.0; ~kickDecay = 0.18;
    ~kickDrive = 1.8; ~kickClick = 0.45;
    30.do { |k|
        var x = (k + 1) / 30;
        ~acidRq = 0.2 - (x * 0.13);
        ~acidCutoffEnv = 3500 + (x * 2000);
        // Mutation acide progressive sur la melodie aussi
        if (0.2.coin) {
            ~melodyNotes = ~mutate.(~melodyNotes, 0.2,
                [~scaleHarmonicMin, ~scalePhrygian].choose);
        };
        // Cutoff melody monte avec la resonance acid
        ~melodyCutoff = 2200 + (x * 1500);
        ~reload.value;
        2.wait;
    };
    // 7:00

    "[C 7:00] full ressu + chaos + rotation timbres + wobble dubstep...".postln;
    24.do { |k|
        ~randomTweak.(0.4);
        if (0.2.coin) { ~acidNotes = ~genAcidNotes.value; ~reload.value };
        if (0.15.coin) { ~hatSteps = ~genKickPattern.(0.5); ~reload.value };
        // Rotation timbre + wobble aleatoire pour fmBell
        if (0.25.coin) {
            ~melodyInst = [\lead, \fmBell, \saw3, \pluck].choose;
            if (~melodyInst == \fmBell) {
                ~melodyWobbleRate = [2, 4, 8, 16].choose;
                ~melodyWobbleShape = [0, 1].choose;
                ~melodyWobbleDepth = rrand(1000, 3000);
                ~melodyCutoff = rrand(300, 800);
                ("  -> fmBell wobble " ++ ~melodyWobbleRate ++ "Hz").postln;
            } { ~melodyCutoff = rrand(1500, 3500) };
            ~reload.value;
            ("  -> melody " ++ ~melodyInst).postln;
        };
        5.wait;
    };
    "[C 9:00] new -- vocalPad ambient + mxl1 long + freeze...".postln;
    ~melodyInst = \vocalPad;
    ~melodyAttack = 0.5; ~melodyRelease = 2.0; ~melodyCutoff = 2200;
    ~melodyAmp = 0.18;
    ~melodyNotes = (~mxl1 ? [60,0,67,0,70,0,67,65, 63,0,60,0,0,67,70,72]).copy;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.15, 800, \sin, 2200) };
    ~fxPreset !? { ~fxPreset.(\dream) };
    ~freeze !? { ~freeze.(4) };
    TempoClock.default.tempo = ~bpm/60; ~reload.value;
    60.wait;

    "[C 10:00] new -- drone + reverbTail final...".postln;
    ~melodyInst = \drone;
    ~melodyAttack = 1.5; ~melodyRelease = 3.0; ~melodyCutoff = 1500;
    ~melodyAmp = 0.16;
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~reverbTail !? { ~reverbTail.(6) };
    ~fxPreset !? { ~fxPreset.(\cosmic) };
    TempoClock.default.tempo = ~bpm/60; ~reload.value;
    40.wait;


    "[C 10:40] outro long -- melody PAD qui s'efface lentement...".postln;
    ~melodyInst = \pad;                              // PAD pour finir
    ~melodyAttack = 0.6; ~melodyRelease = 2.5;
    ~reload.value;
    60.do { |k|
        var x = 1 - ((k + 1) / 60);
        ~acidCutoff = 200 + (x * 1900);
        ~acidAmp = x * 0.26; ~kickAmp = x * 0.5; ~hatAmp = x * 0.10;
        ~melodyAmp = x * 0.13;
        ~reload.value;
        1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    "[C 11:40] === fin HYPNOTIC LOOP ===".postln;
}).play;
"=== TRACK C : HYPNOTIC LOOP 10 min lancee ===".postln;
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

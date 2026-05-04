// =====================================================================
//  V_glitch_idm.scd  -- 8 min, 130 BPM, glitch IDM (Aphex-style)
//  patterns aleatoires + pluck + handpan + mutations rapides
//  PREREQUIS : engine + asia + extra
// =====================================================================
(
[~track1, ~track2, ~track3, ~track4].do { |t| t !? { t.stop } };
~track !? { ~track.stop };
~track = Routine({
    "[V 0:00] === GLITCH IDM 130 BPM ===".postln;
    [\acidSeq, \kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \melodySeq, \harmonySeq]
        .do { |k| Pdef(k).stop };
    TempoClock.default.tempo = 130 / 60;

    "[V 0:00] intro pluck random + drone...".postln;
    ~melodyInst = \pluck;
    ~melodyAttack = 0.001; ~melodyRelease = 0.4; ~melodyCutoff = 5000;
    ~melodyAmp = 0.20;
    ~melodyNotes = ~genMelody.(0.7, ~scaleMinorPent);
    ~percInst = \rim;
    ~percSteps = ~genKickPattern.(0.4); ~percAmp = 0.25;
    ~kickSteps=(0!16); ~hatSteps=(0!16); ~snareSteps=(0!16);
    ~clapSteps=(0!16); ~acidAmp=0;
    ~reload.value;
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq]
        .do { |k| Pdef(k).play };
    ~enableHarmony.(\counter);
    20.wait;

    "[V 0:20] beat hache random...".postln;
    ~kickSteps = ~genKickPattern.(0.35); ~kickAmp = 0.5;
    ~kickFreq = 55; ~kickPitchAmt = 3.5; ~kickDecay = 0.25; ~kickClick = 0.3;
    ~snareSteps = [0,0,1,0, 1,0,0,0, 0,1,0,0, 0,0,0,1]; ~snareAmp = 0.35;
    ~snareFreq = 220; ~snareNoiseAmt = 0.65;
    ~hatSteps = [1,0,1,1, 0,1,1,0, 1,1,0,1, 1,0,1,0]; ~hatAmp = 0.10;
    ~reload.value;
    20.wait;

    "[V 0:40] section : mutations toutes les 4s...".postln;
    20.do { |k|
        // Tout muter aleatoirement
        if (0.5.coin) { ~kickSteps = ~genKickPattern.(rrand(0.2, 0.5)) };
        if (0.5.coin) { ~hatSteps = ~genKickPattern.(rrand(0.4, 0.8)) };
        if (0.4.coin) {
            ~melodyNotes = ~genMelody.(rrand(0.5, 0.8),
                [~scaleMinorPent, ~scaleDorian, ~scaleHigh].choose);
        };
        if (0.3.coin) {
            ~melodyInst = [\pluck, \handpan, \koto, \fmBell, \squareLead].choose;
            ("  -> melody " ++ ~melodyInst).postln;
        };
        if (0.3.coin) {
            ~melodyCutoff = rrand(800, 6000);
            ~melodyRelease = rrand(0.1, 1.5);
        };
        if (0.2.coin) { ~percInst = [\rim, \cowbell, \tom].choose };
        ~reload.value;
        4.wait;
    };
    // 2:00

    "[V 2:00] DROP -- chaos contraste avec acid drone...".postln;
    Synth(\impact, [\freq, 40, \decay, 1.5, \amp, 0.5]);
    ~melodyInst = \handpan;
    ~melodyAttack = 0.001; ~melodyRelease = 1.5; ~melodyCutoff = 5500;
    ~melodyAmp = 0.22;
    ~kickSteps = [1,0,0,0, 0,0,1,1, 0,0,1,0, 1,0,0,1];
    ~snareSteps = [0,0,0,1, 1,0,0,0, 0,1,0,0, 0,0,1,1];
    ~hatSteps = [1,0,1,0, 1,1,0,1, 0,1,1,0, 1,0,1,1];
    ~melodyNotes = ~genMelody.(0.7, ~scaleMinorPent);
    ~reload.value;
    // Continue mutation
    25.do { |k|
        ~melodyNotes = ~mutate.(~melodyNotes, 0.25, ~scaleMinorPent);
        if (0.3.coin) { ~hatSteps = ~genKickPattern.(0.5) };
        ~reload.value;
        3.wait;
    };
    // 3:15

    "[V 3:15] breakdown atmospheric pluck...".postln;
    ~kickSteps = (0!16); ~snareSteps = (0!16); ~hatAmp = 0.05;
    ~melodyInst = \pluck;
    ~melodyAttack = 0.001; ~melodyRelease = 0.6; ~melodyCutoff = 4500;
    ~melodyAmp = 0.22;
    ~reload.value;
    30.wait;

    "[V 3:45] retour glitch + mutations frenetiques...".postln;
    Synth(\impact, [\freq, 35, \decay, 2, \amp, 0.55]);
    ~kickSteps = [1,0,0,0, 0,0,1,0, 0,0,0,1, 0,0,0,0];
    ~snareSteps = [0,0,1,0, 1,0,0,1, 0,1,0,0, 1,0,1,0];
    ~hatSteps = [1,0,1,1, 0,1,1,0, 1,0,1,1, 0,1,0,1]; ~hatAmp = 0.13;
    ~reload.value;
    // Chaos final
    40.do { |k|
        if (0.6.coin) { ~kickSteps = ~genKickPattern.(rrand(0.3, 0.6)) };
        if (0.6.coin) { ~snareSteps = ~genKickPattern.(rrand(0.2, 0.4)) };
        if (0.6.coin) { ~hatSteps = ~genKickPattern.(rrand(0.5, 0.9)) };
        if (0.5.coin) {
            ~melodyNotes = ~genMelody.(rrand(0.4, 0.8), ~scaleMinorPent);
        };
        if (0.3.coin) {
            ~melodyInst = [\pluck, \handpan, \fmBell, \squareLead, \koto].choose;
        };
        if (0.4.coin) { ~melodyCutoff = rrand(800, 8000) };
        ~reload.value;
        3.wait;
    };
    // 5:45
    "[V 5:45] new -- pluck + ringMod glitch + freqShift random...".postln;
    ~melodyInst = \pluck;
    ~melodyAttack = 0.001; ~melodyRelease = 0.4; ~melodyCutoff = 5500;
    ~melodyAmp = 0.20;
    ~melodyNotes = (~ml5 ? ~genMelody.(0.6, ~scaleMinorPent ? [60, 62, 65, 67, 70, 72])).copy;
    ~ringMod !? { ~ringMod.(rrand(150, 600), 2) };
    ~freqShift !? { ~freqShift.(rrand(-150, 150), 1.5) };
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 2.0, 3000, \sqr, 4000) };
    ~fxPreset !? { ~fxPreset.(\industrial) };
    TempoClock.default.tempo = ~bpm/60; ~reload.value;
    25.wait;

    "[V 6:10] new -- handpan + glitch idm + tapeReverse...".postln;
    ~melodyInst = \handpan;
    ~melodyAttack = 0.001; ~melodyRelease = 0.8; ~melodyCutoff = 4500;
    ~melodyAmp = 0.22;
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~glitch !? { ~glitch.(2.5) };
    ~tapeReverse !? { ~tapeReverse.(2) };
    ~fxPreset !? { ~fxPreset.(\space) };
    TempoClock.default.tempo = ~bpm/60; ~reload.value;
    20.wait;


    "[V 6:30] outro fade chaos progressif...".postln;
    60.do { |k|
        var x = 1 - ((k + 1) / 60);
        if (0.4.coin) {
            ~melodyNotes = ~mutate.(~melodyNotes, 0.3);
            ~melodyCutoff = (200 + (x * 5000)).max(200);
        };
        ~kickAmp = x * 0.5; ~snareAmp = x * 0.35; ~hatAmp = x * 0.13;
        ~melodyAmp = x * 0.22;
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq]
        .do { |k| Pdef(k).stop };
    "[V 7:30] === fin GLITCH IDM ===".postln;
}).play;
"=== TRACK V : GLITCH IDM 8 min lancee ===".postln;
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

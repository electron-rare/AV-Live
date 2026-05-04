// =====================================================================
//  U_vocal_trance.scd  -- 10 min, 140 BPM, vocal trance dream
//  choir + warmPad + arp + lead, atmosphere romantique
//  PREREQUIS : engine + extra
// =====================================================================
(
[~track1, ~track2, ~track3, ~track4].do { |t| t !? { t.stop } };
~track !? { ~track.stop };
~track = Routine({
    "[U 0:00] === VOCAL TRANCE 140 BPM ===".postln;
    [\acidSeq, \kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \melodySeq, \harmonySeq]
        .do { |k| Pdef(k).stop };
    TempoClock.default.tempo = 140 / 60;

    "[U 0:00] choir intro etheree...".postln;
    ~melodyInst = \choir;
    ~melodyAttack = 0.5; ~melodyRelease = 2.0; ~melodyCutoff = 2500;
    ~melodyAmp = 0.20;
    ~melodyNotes = [60,0,0,0,67,0,0,0, 70,0,0,0,72,0,0,0,
                    72,0,0,0,70,0,0,0, 67,0,0,0,63,0,0,0];
    ~kickSteps=(0!16); ~hatSteps=(0!16); ~snareSteps=(0!16);
    ~clapSteps=(0!16); ~percSteps=(0!16); ~acidAmp=0;
    ~reload.value;
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq]
        .do { |k| Pdef(k).play };
    ~enableHarmony.(\third);
    40.wait;

    "[U 0:40] kick + clap trance...".postln;
    ~kickSteps  = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.5;
    ~kickFreq = 55; ~kickPitchAmt = 3.0; ~kickDecay = 0.32; ~kickClick = 0.18;
    ~clapSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.32;
    ~hatSteps = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~hatAmp = 0.15;
    ~reload.value;
    50.wait;

    "[U 1:30] arp warmPad par-dessus choir...".postln;
    ~melodyInst = \warmPad;
    ~melodyAttack = 0.4; ~melodyRelease = 1.5; ~melodyCutoff = 2500;
    ~melodyAmp = 0.18;
    ~melodyNotes = [60,67,70,67, 63,67,70,72, 65,67,72,75, 70,72,75,77,
                    63,67,70,75, 65,70,72,77, 67,72,75,79, 70,75,77,72];
    ~reload.value;
    80.wait;

    "[U 2:50] BUILD vers DROP epic...".postln;
    Synth(\riser, [\dur, 12, \startCutoff, 400, \endCutoff, 11000, \amp, 0.35]);
    12.do { |k|
        var x = (k + 1) / 12;
        ~hatAmp = 0.15 + (x * 0.08);
        ~melodyCutoff = 2500 + (x * 3500);
        ~reload.value; 1.wait;
    };
    Synth(\impact, [\freq, 40, \decay, 2.5, \amp, 0.6]);

    "[U 3:02] === DROP fmLead epic ===".postln;
    ~melodyInst = \fmLead;
    ~melodyAttack = 0.005; ~melodyRelease = 0.4; ~melodyCutoff = 6000;
    ~melodyAmp = 0.20;
    ~melodyNotes = [60,67,72,75, 70,67,63,67, 65,72,77,79, 75,72,67,72,
                    63,70,75,82, 79,75,72,75, 65,72,77,84, 79,75,70,72];
    ~reload.value;
    120.wait;

    "[U 5:02] breakdown choir solo (vocal moment)...".postln;
    ~kickSteps = (0!16); ~clapSteps = (0!16); ~hatAmp = 0.06;
    ~melodyInst = \choir;
    ~melodyAttack = 0.4; ~melodyRelease = 2.0; ~melodyCutoff = 2200;
    ~melodyAmp = 0.24;
    ~melodyNotes = [60,0,67,0,72,0,70,0, 67,0,63,0,60,0,0,0,
                    63,0,70,0,75,0,72,0, 70,0,65,0,63,0,0,0];
    ~reload.value;
    Synth(\gong, [\freq, 60, \decay, 8, \amp, 0.4]);
    50.wait;

    "[U 5:52] BUILD 2 + DROP FINAL...".postln;
    Synth(\riser, [\dur, 16, \startCutoff, 500, \endCutoff, 12500, \amp, 0.4]);
    ~kickSteps = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0];
    16.do { |k|
        var x = (k + 1) / 16;
        ~hatAmp = 0.06 + (x * 0.14);
        ~reload.value; 1.wait;
    };
    Synth(\impact, [\freq, 35, \decay, 3, \amp, 0.7]);
    Synth(\crash, [\decay, 4, \amp, 0.45]);

    "[U 6:08] === DROP FINAL hardLead + choir layers ===".postln;
    ~melodyInst = \hardLead;
    ~melodyAttack = 0.003; ~melodyRelease = 0.3; ~melodyCutoff = 6500;
    ~melodyAmp = 0.22;
    ~hatSteps = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~hatAmp = 0.18;
    ~clapSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.35;
    ~melodyNotes = [60,67,72,75, 70,67,63,67, 65,72,77,79, 75,72,67,72,
                    63,70,75,82, 79,75,72,75, 65,72,77,84, 79,75,70,67];
    ~reload.value;
    150.wait;
    "[U 8:38] new -- supersaw + vocalPad + mxl1 trance epic + buildup...".postln;
    ~melodyInst = \supersaw;
    ~melodyAttack = 0.005; ~melodyRelease = 0.4; ~melodyCutoff = 5500;
    ~melodyAmp = 0.20;
    ~melodyNotes = (~mxl1 ? [60,67,72,75, 70,67,63,67, 65,72,77,79, 75,72,67,72]).copy;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.4, 2000, \sin, 5500) };
    ~vcfOn !? { ~vcfOn.(\moog, 2800, 0.4) };
    ~buildup !? { ~buildup.(8) };
    ~fxPreset !? { ~fxPreset.(\trance) };
    TempoClock.default.tempo = ~bpm/60; ~reload.value;
    35.wait;

    "[U 9:13] new -- vocalPad + drop final + reverbTail...".postln;
    ~melodyInst = \vocalPad;
    ~melodyAttack = 0.4; ~melodyRelease = 2.2; ~melodyCutoff = 2500;
    ~melodyAmp = 0.22;
    ~vcfOff !? { ~vcfOff.() };
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~drop !? { ~drop.() };
    ~reverbTail !? { ~reverbTail.(6) };
    ~fxPreset !? { ~fxPreset.(\dream) };
    TempoClock.default.tempo = ~bpm/60; ~reload.value;
    25.wait;


    "[U 9:38] outro pad fade...".postln;
    ~melodyInst = \warmPad;
    ~melodyAttack = 0.6; ~melodyRelease = 2.5;
    ~reload.value;
    80.do { |k|
        var x = 1 - ((k + 1) / 80);
        ~kickAmp = x * 0.5; ~hatAmp = x * 0.18; ~clapAmp = x * 0.35;
        ~melodyAmp = x * 0.22;
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq]
        .do { |k| Pdef(k).stop };
    "[U 10:58] === fin VOCAL TRANCE ===".postln;
}).play;
"=== TRACK U : VOCAL TRANCE 10 min lancee ===".postln;
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

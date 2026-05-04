// =====================================================================
//  J_ambient_cinematic.scd  -- 12 min, 80 BPM, ambient cinematique
//  choir + strings + drone + handpan, evolution lente, pas de drop
//  PREREQUIS : engine + extra
// =====================================================================
(
[~track1, ~track2, ~track3, ~track4].do { |t| t !? { t.stop } };
~track !? { ~track.stop };
~track = Routine({
    "[J 0:00] === AMBIENT CINEMATIQUE 80 BPM ===".postln;
    [\acidSeq, \kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \melodySeq, \harmonySeq]
        .do { |k| Pdef(k).stop };
    TempoClock.default.tempo = 80 / 60;

    "[J 0:00] drone seul...".postln;
    ~melodyInst = \drone;
    ~melodyAttack = 1.5; ~melodyRelease = 3.0; ~melodyCutoff = 1500;
    ~melodyAmp = 0.20;
    ~melodyNotes = [48,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,
                    48,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0];
    ~kickSteps=(0!16); ~hatSteps=(0!16); ~snareSteps=(0!16);
    ~clapSteps=(0!16); ~percSteps=(0!16); ~acidAmp=0;
    ~reload.value;
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq]
        .do { |k| Pdef(k).play };
    ~enableHarmony.(\cinematic);
    Synth(\gong, [\freq, 50, \decay, 8, \amp, 0.5]);
    60.wait;

    "[J 1:00] strings entrent...".postln;
    ~melodyInst = \strings;
    ~melodyAttack = 0.4; ~melodyRelease = 1.2; ~melodyCutoff = 3500;
    ~melodyAmp = 0.20;
    ~melodyNotes = [60,0,0,0, 63,0,0,0, 67,0,0,0, 70,0,0,0,
                    72,0,0,0, 70,0,0,0, 67,0,0,0, 63,0,0,0];
    ~reload.value;
    90.wait;

    "[J 2:30] choir mystique...".postln;
    Synth(\gong, [\freq, 60, \decay, 10, \amp, 0.4]);
    ~melodyInst = \choir;
    ~melodyAttack = 0.5; ~melodyRelease = 1.8; ~melodyCutoff = 2800;
    ~melodyAmp = 0.22;
    ~melodyNotes = [60,0,0,0,0,67,0,0, 70,0,0,0,72,0,0,0,
                    75,0,0,0,72,0,0,0, 70,0,0,0,67,0,0,0];
    ~reload.value;
    120.wait;

    "[J 4:30] handpan emerge (rythme doux)...".postln;
    ~percInst = \tom;
    ~percSteps = [1,0,0,0, 0,0,0,1, 0,0,1,0, 0,0,0,0]; ~percAmp = 0.18;
    ~tomFreq = 70;
    ~melodyInst = \handpan;
    ~melodyAttack = 0.001; ~melodyRelease = 1.8; ~melodyCutoff = 5000;
    ~melodyAmp = 0.22;
    ~melodyNotes = [60,0,67,0,70,0,72,0, 75,0,72,70,67,0,63,60,
                    63,0,67,0,70,0,75,0, 79,0,75,72,70,0,65,60];
    ~reload.value;
    120.wait;

    "[J 6:30] flute melodique...".postln;
    ~melodyInst = \flute;
    ~melodyAttack = 0.08; ~melodyRelease = 0.5; ~melodyCutoff = 4000;
    ~melodyAmp = 0.20;
    ~melodyNotes = [72,0,75,0,77,0,75,72, 70,0,72,75,72,70,67,0,
                    77,0,79,0,82,0,79,77, 75,0,77,0,72,0,70,0];
    ~reload.value;
    150.wait;

    "[J 9:00] retour drone profond...".postln;
    Synth(\gong, [\freq, 40, \decay, 12, \amp, 0.6]);
    ~percSteps = (0!16);
    ~melodyInst = \drone;
    ~melodyAttack = 1.5; ~melodyRelease = 3.0; ~melodyCutoff = 1200;
    ~melodyAmp = 0.18;
    ~melodyNotes = [36,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,
                    36,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0];
    ~reload.value;
    90.wait;
    "[J 10:30] new -- vocalPad ambient + mepic1 cinematic + lfo lent...".postln;
    ~melodyInst = \vocalPad;
    ~melodyAttack = 1.0; ~melodyRelease = 2.5; ~melodyCutoff = 2200;
    ~melodyAmp = 0.20;
    ~melodyNotes = (~mepic1 ? [60,0,63,0,67,0,70,0, 72,0,70,67,63,0,60,0]).copy;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.1, 600, \sin, 2200) };
    ~fxPreset !? { ~fxPreset.(\dream) };
    ~freeze !? { ~freeze.(8) };
    TempoClock.default.tempo = ~bpm/60; ~reload.value;
    90.wait;

    "[J 12:00] new -- didgeridoo drone + tapeReverse...".postln;
    ~melodyInst = \didgeridoo;
    ~melodyAttack = 0.5; ~melodyRelease = 2.0; ~melodyCutoff = 1200;
    ~melodyAmp = 0.18;
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~tapeReverse !? { ~tapeReverse.(3) };
    ~fxPreset !? { ~fxPreset.(\cosmic) };
    TempoClock.default.tempo = ~bpm/60; ~reload.value;
    50.wait;


    "[J 12:50] outro lent...".postln;
    60.do { |k|
        var x = 1 - ((k + 1) / 60);
        ~melodyAmp = x * 0.18; ~melodyCutoff = 200 + (x * 1000);
        ~reload.value; 1.5.wait;
    };
    Synth(\gong, [\freq, 35, \decay, 15, \amp, 0.7]);
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq]
        .do { |k| Pdef(k).stop };
    "[J 14:20] === fin AMBIENT ===".postln;
}).play;
"=== TRACK J : AMBIENT CINEMATIQUE 12 min lancee ===".postln;
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

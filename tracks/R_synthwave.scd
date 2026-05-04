// =====================================================================
//  R_synthwave.scd  -- 8 min, 100 BPM, synthwave 80s retro
//  warmPad + saw3 lead + drum 80s + chord progression analog
//  PREREQUIS : engine + extra
// =====================================================================
(
[~track1, ~track2, ~track3, ~track4].do { |t| t !? { t.stop } };
~track !? { ~track.stop };
~track = Routine({
    "[R 0:00] === SYNTHWAVE 100 BPM ===".postln;
    [\acidSeq, \kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \melodySeq, \harmonySeq]
        .do { |k| Pdef(k).stop };
    TempoClock.default.tempo = 100 / 60;

    "[R 0:00] intro warmPad atmospherique...".postln;
    ~melodyInst = \warmPad;
    ~melodyAttack = 0.6; ~melodyRelease = 2.5; ~melodyCutoff = 1800;
    ~melodyAmp = 0.18;
    ~melodyNotes = [60,0,0,0,63,0,0,0, 67,0,0,0,70,0,0,0,
                    72,0,0,0,70,0,0,0, 67,0,0,0,63,0,0,0];
    ~kickSteps=(0!16); ~hatSteps=(0!16); ~snareSteps=(0!16);
    ~clapSteps=(0!16); ~percSteps=(0!16); ~acidAmp=0;
    ~reload.value;
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq]
        .do { |k| Pdef(k).play };
    ~enableHarmony.(\fifth);
    25.wait;

    "[R 0:25] beat 80s : kick + snare 1-2-3-4...".postln;
    ~kickSteps  = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.5;
    ~kickFreq = 55; ~kickPitchAmt = 3.0; ~kickDecay = 0.32; ~kickClick = 0.18;
    ~snareSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~snareAmp = 0.4;
    ~snareFreq = 220; ~snareNoiseAmt = 0.5;
    ~hatSteps = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~hatAmp = 0.13;
    ~reload.value;
    35.wait;

    "[R 1:00] saw3 lead retro entre...".postln;
    ~melodyInst = \saw3;
    ~melodyAttack = 0.005; ~melodyRelease = 0.3; ~melodyCutoff = 3000;
    ~melodyDrive = 1.6; ~melodyAmp = 0.16;
    ~melodyNotes = [60,0,67,0,70,0,72,0, 70,67,0,63,0,67,70,0,
                    72,0,75,0,77,0,75,72, 70,67,0,63,0,60,0,0];
    ~reload.value;
    80.wait;

    "[R 2:20] verse fmLead solo...".postln;
    ~melodyInst = \fmLead;
    ~melodyAttack = 0.005; ~melodyRelease = 0.4; ~melodyCutoff = 5500;
    ~melodyAmp = 0.18;
    ~melodyNotes = [72,0,75,0,77,75,72,0, 70,0,72,75,72,70,67,0,
                    77,0,79,0,82,79,77,75, 72,0,70,67,65,0,60,0];
    ~reload.value;
    80.wait;

    "[R 3:40] breakdown choir + saw lead duo...".postln;
    ~kickSteps = (0!16); ~snareSteps = (0!16); ~hatAmp = 0.06;
    ~melodyInst = \choir;
    ~melodyAttack = 0.4; ~melodyRelease = 1.5; ~melodyCutoff = 2500;
    ~melodyAmp = 0.20;
    ~reload.value;
    35.wait;

    "[R 4:15] DROP 2 chord stabs + lead duo...".postln;
    Synth(\impact, [\freq, 45, \decay, 2, \amp, 0.45]);
    ~kickSteps = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0];
    ~snareSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0];
    ~hatSteps = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~hatAmp = 0.13;
    ~clapSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.3;
    ~melodyInst = \saw3;
    ~melodyAttack = 0.005; ~melodyRelease = 0.3; ~melodyCutoff = 3500;
    ~melodyAmp = 0.18;
    ~melodyNotes = [60,0,67,72, 70,0,67,63, 65,0,72,75, 72,0,70,65,
                    60,0,67,72, 70,0,67,63, 65,0,72,77, 75,0,70,65];
    ~reload.value;
    120.wait;
    "[R 6:15] new -- supersaw synthwave + ml5 + lfo cutoff slow...".postln;
    ~melodyInst = \supersaw;
    ~melodyAttack = 0.005; ~melodyRelease = 0.4; ~melodyCutoff = 3500;
    ~melodyAmp = 0.18;
    ~melodyNotes = (~ml5 ? [60,0,67,72, 70,0,67,63, 65,0,72,75, 72,0,70,65]).copy;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.15, 1200, \sin, 3500) };
    ~vcfOn !? { ~vcfOn.(\moog, 2500, 0.4) };
    ~fxPreset !? { ~fxPreset.(\retro) };
    TempoClock.default.tempo = ~bpm/60; ~reload.value;
    45.wait;

    "[R 7:00] new -- vocalPad + warmPad layers + reverbTail synthwave...".postln;
    ~melodyInst = \vocalPad;
    ~melodyAttack = 0.4; ~melodyRelease = 2.0; ~melodyCutoff = 2200;
    ~melodyAmp = 0.20;
    ~vcfOff !? { ~vcfOff.() };
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~reverbTail !? { ~reverbTail.(5) };
    ~fxPreset !? { ~fxPreset.(\dream) };
    TempoClock.default.tempo = ~bpm/60; ~reload.value;
    30.wait;


    "[R 7:30] outro pad fade...".postln;
    ~melodyInst = \warmPad;
    ~melodyAttack = 0.6; ~melodyRelease = 2.5;
    ~melodyAmp = 0.18;
    ~reload.value;
    60.do { |k|
        var x = 1 - ((k + 1) / 60);
        ~kickAmp = x * 0.5; ~snareAmp = x * 0.4; ~hatAmp = x * 0.13;
        ~clapAmp = x * 0.3; ~melodyAmp = x * 0.18;
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq]
        .do { |k| Pdef(k).stop };
    "[R 8:30] === fin SYNTHWAVE ===".postln;
}).play;
"=== TRACK R : SYNTHWAVE 8 min lancee ===".postln;
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

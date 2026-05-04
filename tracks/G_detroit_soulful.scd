// =====================================================================
//  G_detroit_soulful.scd  -- 8 min, 124 BPM, Detroit house
//  organLead stabs + warmPad fond + kick 4/4 + clap backbeat
//  PREREQUIS : engine + extra
// =====================================================================
(
[~track1, ~track2, ~track3, ~track4].do { |t| t !? { t.stop } };
~track !? { ~track.stop };
~track = Routine({
    "[G 0:00] === DETROIT SOULFUL 124 BPM ===".postln;
    [\acidSeq, \kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \melodySeq, \harmonySeq]
        .do { |k| Pdef(k).stop };
    TempoClock.default.tempo = 124 / 60;

    "[G 0:00] intro warmPad accords...".postln;
    ~melodyInst = \warmPad; ~melodyAttack = 0.5; ~melodyRelease = 1.8;
    ~melodyCutoff = 1800; ~melodyAmp = 0.18;
    ~melodyNotes = [60,0,0,0, 63,0,0,0, 67,0,0,0, 70,0,0,0,
                    72,0,0,0, 70,0,0,0, 67,0,0,0, 63,0,0,0];
    ~kickSteps=(0!16); ~hatSteps=(0!16); ~snareSteps=(0!16);
    ~clapSteps=(0!16); ~percSteps=(0!16); ~acidAmp=0;
    ~reload.value;
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq]
        .do { |k| Pdef(k).play };
    ~enableHarmony.(\chord);
    30.wait;

    "[G 0:30] kick 4/4 + clap...".postln;
    ~kickSteps = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.5;
    ~kickFreq = 50; ~kickPitchAmt = 2.8; ~kickDecay = 0.35; ~kickClick = 0.12;
    ~hatSteps = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~hatAmp = 0.15;
    ~clapSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.35;
    ~reload.value;
    30.wait;

    "[G 1:00] organ stabs Detroit...".postln;
    ~melodyInst = \organLead;
    ~melodyAttack = 0.005; ~melodyRelease = 0.15; ~melodyCutoff = 4500;
    ~melodyAmp = 0.18;
    ~melodyNotes = [63,0,0,0, 67,0,70,0, 65,0,0,0, 70,0,72,0,
                    63,0,0,0, 67,0,70,0, 60,0,67,0, 63,0,0,0];
    ~reload.value;
    60.wait;

    "[G 2:00] verse hardLead phrase...".postln;
    ~melodyInst = \hardLead;
    ~melodyAttack = 0.003; ~melodyRelease = 0.25; ~melodyCutoff = 5000;
    ~melodyNotes = [60,67,72,75, 70,67,63,60, 65,70,75,77, 72,70,67,63,
                    63,70,75,79, 75,72,70,67, 60,65,70,75, 67,63,60,0];
    ~reload.value;
    60.wait;

    "[G 3:00] breakdown strings + choir...".postln;
    ~kickSteps=(0!16); ~hatAmp=0.06; ~clapSteps=(0!16);
    ~melodyInst = \strings;
    ~melodyAttack = 0.3; ~melodyRelease = 1.2; ~melodyCutoff = 3500;
    ~melodyAmp = 0.20;
    ~melodyNotes = [60,0,0,0, 67,0,0,0, 70,0,0,0, 72,0,0,0,
                    70,0,0,0, 67,0,0,0, 63,0,0,0, 60,0,0,0];
    ~reload.value;
    45.wait;

    "[G 3:45] DROP retour + organ...".postln;
    Synth(\impact, [\freq, 45, \decay, 2, \amp, 0.5]);
    ~kickSteps = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0];
    ~hatSteps = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~hatAmp = 0.16;
    ~clapSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0];
    ~melodyInst = \organLead;
    ~melodyAttack = 0.005; ~melodyRelease = 0.15; ~melodyCutoff = 5500;
    ~reload.value;
    120.wait;
    "[G 5:45] new -- rhodes detroit + ml5 + dub fx...".postln;
    ~melodyInst = \rhodes;
    ~melodyAttack = 0.005; ~melodyRelease = 0.6; ~melodyCutoff = 3500;
    ~melodyAmp = 0.18;
    ~melodyNotes = (~ml5 ? [60,0,67,0,70,0,67,65, 63,0,60,0,0,67,70,72]).copy;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.25, 1500, \sin, 3500) };
    ~vcfOn !? { ~vcfOn.(\moog, 2200, 0.4) };
    ~fxPreset !? { ~fxPreset.(\dub) };
    TempoClock.default.tempo = ~bpm/60; ~reload.value;
    40.wait;

    "[G 6:25] new -- vocalPad detroit soulful + glitch...".postln;
    ~melodyInst = \vocalPad;
    ~melodyAttack = 0.4; ~melodyRelease = 1.8; ~melodyCutoff = 2500;
    ~melodyAmp = 0.20;
    ~vcfOff !? { ~vcfOff.() };
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~glitch !? { ~glitch.(2) };
    ~fxPreset !? { ~fxPreset.(\dream) };
    TempoClock.default.tempo = ~bpm/60; ~reload.value;
    25.wait;


    "[G 6:50] outro warmPad fade...".postln;
    ~melodyInst = \warmPad;
    ~melodyAttack = 0.5; ~melodyRelease = 2.0; ~melodyCutoff = 1500;
    ~reload.value;
    60.do { |k|
        var x = 1 - ((k + 1) / 60);
        ~kickAmp = x * 0.5; ~hatAmp = x * 0.16; ~clapAmp = x * 0.35;
        ~melodyAmp = x * 0.18;
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq]
        .do { |k| Pdef(k).stop };
    "[G 7:50] === fin DETROIT SOULFUL ===".postln;
}).play;
"=== TRACK G : DETROIT SOULFUL 8 min lancee ===".postln;
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

// =====================================================================
//  P_industrial.scd  -- 8 min, 130 BPM, industrial dark
//  growl + reeseHard + kick distordu + drone + metal hits
//  PREREQUIS : engine + asia + extra
// =====================================================================
(
[~track1, ~track2, ~track3, ~track4].do { |t| t !? { t.stop } };
~track !? { ~track.stop };
~track = Routine({
    "[P 0:00] === INDUSTRIAL 130 BPM ===".postln;
    [\acidSeq, \kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \melodySeq, \harmonySeq]
        .do { |k| Pdef(k).stop };
    TempoClock.default.tempo = 130 / 60;

    "[P 0:00] drone tendu + metal hits...".postln;
    ~melodyInst = \drone;
    ~melodyAttack = 1.0; ~melodyRelease = 2.5; ~melodyCutoff = 1500;
    ~melodyAmp = 0.18;
    ~melodyNotes = [36,0,0,0,0,0,0,0, 36,0,0,0,39,0,0,0,
                    36,0,0,0,0,0,0,0, 41,0,0,0,39,0,0,0];
    ~percInst = \rim;
    ~percSteps = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~percAmp = 0.35;
    ~kickSteps=(0!16); ~hatSteps=(0!16); ~snareSteps=(0!16);
    ~clapSteps=(0!16); ~acidAmp=0;
    ~reload.value;
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq]
        .do { |k| Pdef(k).play };
    ~enableHarmony.(\bassline);
    25.wait;

    "[P 0:25] kick distordu T4 + clap heavy...".postln;
    ~kickSteps  = [1,0,0,0, 0,0,0,0, 1,0,0,0, 0,0,0,0]; ~kickAmp = 0.55;
    ~kickFreq = 60; ~kickPitchAmt = 5.0; ~kickDecay = 0.28;
    ~kickDrive = 3.5; ~kickClick = 0.3;
    ~clapSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,1]; ~clapAmp = 0.4;
    ~hatSteps = [0,1,0,1, 1,1,0,1, 0,1,0,1, 1,1,0,1]; ~hatAmp = 0.10;
    ~reload.value;
    35.wait;

    "[P 1:00] reeseHard menacant entre...".postln;
    ~melodyInst = \reeseHard;
    ~melodyAttack = 0.005; ~melodyRelease = 0.3; ~melodyCutoff = 700;
    ~melodyDrive = 4.0; ~melodyAmp = 0.25;
    ~melodyNotes = [36,0,0,0, 39,0,0,0, 36,0,0,0, 41,0,0,0,
                    36,0,0,0, 38,0,0,0, 41,0,0,0, 39,0,0,0];
    ~reload.value;
    60.wait;

    "[P 2:00] section growl + drum hard...".postln;
    Synth(\impact, [\freq, 35, \decay, 2, \amp, 0.55]);
    ~kickSteps  = [1,0,1,0, 0,0,0,0, 1,0,0,1, 0,0,0,0]; ~kickAmp = 0.55;
    ~snareSteps = [0,0,0,0, 1,0,0,1, 0,0,0,0, 1,0,1,0]; ~snareAmp = 0.5;
    ~snareFreq = 240; ~snareNoiseAmt = 0.75;
    ~melodyInst = \growl;
    ~melodyAttack = 0.005; ~melodyRelease = 0.3;
    ~melodyCutoff = 350; ~melodyDrive = 3.5;
    ~melodyWobbleRate = 4; ~melodyWobbleDepth = 2200; ~melodyWobbleShape = 0;
    ~melodySubAmt = 0.7; ~melodyAmp = 0.20;
    ~reload.value;
    90.wait;

    "[P 3:30] tension : drum cuts, drone seul...".postln;
    ~kickSteps = [1,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0]; ~kickAmp = 0.5;
    ~snareSteps = (0!16); ~clapSteps = (0!16); ~hatAmp = 0.05;
    ~melodyInst = \drone;
    ~melodyAttack = 1.0; ~melodyRelease = 2.5; ~melodyCutoff = 1200;
    ~melodyAmp = 0.20;
    ~percSteps = [1,0,0,0, 0,0,1,0, 0,0,0,0, 0,1,0,0]; ~percAmp = 0.35;
    ~reload.value;
    Synth(\gong, [\freq, 80, \decay, 6, \amp, 0.5]);
    45.wait;

    "[P 4:15] DROP final hard growl + kick double...".postln;
    Synth(\impact, [\freq, 30, \decay, 3, \amp, 0.65]);
    ~kickSteps = [1,0,1,0, 1,0,1,0, 1,0,1,0, 1,0,1,0]; ~kickAmp = 0.5;
    ~snareSteps = [0,0,0,0, 1,0,0,1, 0,0,0,0, 1,0,1,0]; ~snareAmp = 0.5;
    ~hatSteps = [1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1]; ~hatAmp = 0.10;
    ~clapSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.4;
    ~melodyInst = \growl;
    ~melodyCutoff = 280; ~melodyDrive = 3.8;
    ~melodyWobbleRate = 8; ~melodyWobbleShape = 1; ~melodyAmp = 0.22;
    ~reload.value;
    150.wait;
    "[P 6:45] new -- reeseHard + bitCrush industrial + tapeStop drop...".postln;
    ~melodyInst = \reeseHard;
    ~melodyAttack = 0.005; ~melodyRelease = 0.3; ~melodyCutoff = 600;
    ~melodyDrive = 4.5; ~melodyAmp = 0.26;
    ~melodyNotes = (~ml5 ? [36,0,0,0,39,0,0,0, 41,0,0,0,43,0,0,0]).copy;
    ~bitCrushNow !? { ~bitCrushNow.(6, 6000, 4) };
    ~vcfOn !? { ~vcfOn.(\ladder, 800, 0.6) };
    ~fxPreset !? { ~fxPreset.(\industrial) };
    TempoClock.default.tempo = ~bpm/60; ~reload.value;
    35.wait;

    "[P 7:20] new -- didgeridoo dark + tapeStop industrial...".postln;
    ~melodyInst = \didgeridoo;
    ~melodyAttack = 0.4; ~melodyRelease = 1.5; ~melodyCutoff = 1200;
    ~melodyAmp = 0.20;
    ~vcfOff !? { ~vcfOff.() };
    ~tapeStop !? { ~tapeStop.(2) };
    ~fxPreset !? { ~fxPreset.(\industrial) };
    TempoClock.default.tempo = ~bpm/60; ~reload.value;
    20.wait;


    "[P 7:40] outro mecanique...".postln;
    Synth(\sweep, [\dur, 8, \startCutoff, 6000, \endCutoff, 200, \amp, 0.3]);
    60.do { |k|
        var x = 1 - ((k + 1) / 60);
        ~kickAmp = x * 0.5; ~snareAmp = x * 0.5; ~hatAmp = x * 0.10;
        ~clapAmp = x * 0.4; ~melodyAmp = x * 0.22; ~percAmp = x * 0.35;
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq]
        .do { |k| Pdef(k).stop };
    "[P 8:40] === fin INDUSTRIAL ===".postln;
}).play;
"=== TRACK P : INDUSTRIAL 8 min lancee ===".postln;
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

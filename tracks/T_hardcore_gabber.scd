// =====================================================================
//  T_hardcore_gabber.scd  -- 6 min, 180 BPM, hardcore gabber
//  kick double T4 distordu + acid hardfloor + sub massif
//  PREREQUIS : engine + asia + extra
// =====================================================================
(
[~track1, ~track2, ~track3, ~track4].do { |t| t !? { t.stop } };
~track !? { ~track.stop };
~track = Routine({
    "[T 0:00] === HARDCORE GABBER 180 BPM ===".postln;
    [\acidSeq, \kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \melodySeq, \harmonySeq]
        .do { |k| Pdef(k).stop };
    TempoClock.default.tempo = 180 / 60;

    "[T 0:00] intro pad menacant...".postln;
    ~melodyInst = \drone;
    ~melodyAttack = 0.6; ~melodyRelease = 2.0; ~melodyCutoff = 1500;
    ~melodyAmp = 0.18;
    ~melodyNotes = [36,0,0,0,0,0,0,0, 39,0,0,0,0,0,0,0,
                    36,0,0,0,0,0,0,0, 41,0,0,0,0,0,0,0];
    ~kickSteps=(0!16); ~hatSteps=(0!16); ~snareSteps=(0!16);
    ~clapSteps=(0!16); ~percSteps=(0!16);
    ~acidNotes = [36,39,48,36,41,39,43,36, 39,41,36,48,39,36,41,39];
    ~acidAccents = [1,0,1,0,0,1,0,1, 0,0,1,0,1,0,0,1];
    ~acidSlides = [1,0,0,1,0,0,1,0, 0,1,0,1,0,1,0,0];
    ~acidCutoff = 1200; ~acidRq = 0.10; ~acidDrive = 3.5; ~acidAmp = 0;
    ~reload.value;
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq]
        .do { |k| Pdef(k).play };
    ~enableHarmony.(\dubBass);
    15.wait;

    "[T 0:15] kick double gabber + acid...".postln;
    ~kickSteps  = [1,0,1,0, 1,0,1,0, 1,0,1,0, 1,0,1,0]; ~kickAmp = 0.55;
    ~kickFreq = 60; ~kickPitchAmt = 5.0; ~kickDecay = 0.18;
    ~kickDrive = 3.5; ~kickClick = 0.35;
    ~hatSteps = [0,1,1,1, 0,1,1,0, 0,1,1,1, 0,1,1,0]; ~hatAmp = 0.13;
    ~acidAmp = 0.30; ~acidCutoff = 1500;
    ~reload.value;
    45.wait;

    "[T 1:00] BUILD vers DROP hardcore...".postln;
    Synth(\riser, [\dur, 8, \startCutoff, 500, \endCutoff, 13000, \amp, 0.4]);
    8.wait;
    Synth(\impact, [\freq, 35, \decay, 2, \amp, 0.6]);
    Synth(\crash, [\decay, 2, \amp, 0.4]);

    "[T 1:08] === DROP gabber + acid push ===".postln;
    ~acidCutoff = 2500; ~acidRq = 0.06; ~acidDrive = 4.0; ~acidAmp = 0.32;
    ~melodyInst = \growl;
    ~melodyAttack = 0.005; ~melodyRelease = 0.2;
    ~melodyCutoff = 300; ~melodyDrive = 3.5;
    ~melodyWobbleRate = 8; ~melodyWobbleDepth = 2800;
    ~melodyWobbleShape = 1; ~melodySubAmt = 0.7;
    ~melodyAmp = 0.18;
    ~melodyNotes = [36,0,0,0, 36,0,39,0, 36,0,0,0, 41,0,0,0,
                    36,0,38,0, 36,0,39,0, 41,0,43,0, 39,0,36,0];
    ~clapSteps = [0,0,0,0, 1,0,0,1, 0,0,0,0, 1,0,1,0]; ~clapAmp = 0.4;
    ~reload.value;
    90.wait;

    "[T 2:38] breakdown atmospheric...".postln;
    ~kickSteps = (0!16); ~clapSteps = (0!16); ~acidAmp = 0;
    ~hatAmp = 0.06;
    ~melodyInst = \drone;
    ~melodyAttack = 0.5; ~melodyRelease = 2.0; ~melodyCutoff = 1200;
    ~melodyAmp = 0.20;
    ~reload.value;
    Synth(\gong, [\freq, 65, \decay, 5, \amp, 0.5]);
    25.wait;

    "[T 3:03] DROP FINAL chaos kick double...".postln;
    Synth(\impact, [\freq, 30, \decay, 3, \amp, 0.7]);
    Synth(\crash, [\decay, 3, \amp, 0.5]);
    ~kickSteps  = [1,0,1,0, 1,0,1,0, 1,0,1,0, 1,0,1,0];
    ~hatSteps = [1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1]; ~hatAmp = 0.14;
    ~clapSteps = [0,0,0,0, 1,0,0,1, 0,0,0,0, 1,0,1,1];
    ~acidAmp = 0.35; ~acidCutoff = 2800; ~acidRq = 0.05; ~acidDrive = 4.5;
    ~melodyInst = \growl;
    ~melodyCutoff = 250; ~melodyDrive = 4.0;
    ~melodyWobbleShape = 1; ~melodySubAmt = 0.8; ~melodyAmp = 0.20;
    ~reload.value;
    100.wait;
    "[T 4:43] new -- kickGabber + supersaw + reverb infini drop...".postln;
    ~melodyInst = \hooverbass;
    ~melodyAttack = 0.005; ~melodyRelease = 0.2; ~melodyCutoff = 1500;
    ~melodyAmp = 0.22;
    ~melodyNotes = (~ml5 ? [36,0,39,0, 36,0,41,0, 36,0,38,0, 39,0,36,0]).copy;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.6, 1200, \sqr, 1800) };
    ~vcfOn !? { ~vcfOn.(\ladder, 1200, 0.6) };
    ~setFx !? { ~setFx.(\rev, \mix, 0.7) };
    ~fxPreset !? { ~fxPreset.(\industrial) };
    TempoClock.default.tempo = ~bpm/60; ~reload.value;
    30.wait;

    "[T 5:13] new -- reeseHard + bitCrush + tapeStop hardcore...".postln;
    ~melodyInst = \reeseHard;
    ~melodyAttack = 0.005; ~melodyRelease = 0.2; ~melodyCutoff = 800;
    ~melodyDrive = 4.0; ~melodyAmp = 0.22;
    ~vcfOff !? { ~vcfOff.() };
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~bitCrushNow !? { ~bitCrushNow.(4, 4000, 3) };
    ~tapeStop !? { ~tapeStop.(2) };
    ~fxPreset !? { ~fxPreset.(\industrial) };
    TempoClock.default.tempo = ~bpm/60; ~reload.value;
    20.wait;


    "[T 5:33] outro accelerando descend...".postln;
    Synth(\sweep, [\dur, 10, \startCutoff, 12000, \endCutoff, 200, \amp, 0.4]);
    50.do { |k|
        var x = 1 - ((k + 1) / 50);
        ~kickAmp = x * 0.55; ~hatAmp = x * 0.14; ~clapAmp = x * 0.4;
        ~melodyAmp = x * 0.20; ~acidAmp = x * 0.35;
        ~acidCutoff = 200 + (x * 2500);
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq]
        .do { |k| Pdef(k).stop };
    "[T 6:23] === fin GABBER ===".postln;
}).play;
"=== TRACK T : HARDCORE GABBER 6 min lancee ===".postln;
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

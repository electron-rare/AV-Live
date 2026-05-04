// =====================================================================
//  Q_neurofunk_dnb.scd  -- 7 min, 174 BPM, neurofunk DnB hard
//  reeseHard + amen syncope + acid stabs + drops bass-heavy
//  PREREQUIS : engine + asia + extra
// =====================================================================
(
[~track1, ~track2, ~track3, ~track4].do { |t| t !? { t.stop } };
~track !? { ~track.stop };
~track = Routine({
    "[Q 0:00] === NEUROFUNK DNB 174 BPM ===".postln;
    [\acidSeq, \kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \melodySeq, \harmonySeq]
        .do { |k| Pdef(k).stop };
    TempoClock.default.tempo = 174 / 60;

    "[Q 0:00] intro pad sombre...".postln;
    ~melodyInst = \drone;
    ~melodyAttack = 0.8; ~melodyRelease = 2.5; ~melodyCutoff = 1500;
    ~melodyAmp = 0.18;
    ~melodyNotes = [36,0,0,0,0,0,0,0, 39,0,0,0,0,0,0,0,
                    36,0,0,0,0,0,0,0, 41,0,0,0,0,0,0,0];
    ~kickSteps=(0!16); ~hatSteps=(0!16); ~snareSteps=(0!16);
    ~clapSteps=(0!16); ~percSteps=(0!16); ~acidAmp=0;
    ~reload.value;
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq]
        .do { |k| Pdef(k).play };
    ~enableHarmony.(\bassline);
    20.wait;

    "[Q 0:20] amen syncope entre...".postln;
    ~kickSteps  = [1,0,0,0, 0,0,1,0, 0,0,1,0, 1,0,0,0]; ~kickAmp = 0.55;
    ~kickFreq = 55; ~kickPitchAmt = 4.0; ~kickDecay = 0.18;
    ~kickDrive = 1.8; ~kickClick = 0.35;
    ~snareSteps = [0,0,0,0, 1,0,0,0, 0,0,0,1, 1,0,1,0]; ~snareAmp = 0.55;
    ~snareFreq = 240; ~snareNoiseAmt = 0.7; ~snareDecay = 0.10;
    ~hatSteps = [1,1,1,1, 0,1,1,1, 1,1,1,1, 0,1,1,1]; ~hatAmp = 0.13;
    ~reload.value;
    25.wait;

    "[Q 0:45] BUILD vers DROP reese...".postln;
    Synth(\riser, [\dur, 8, \startCutoff, 400, \endCutoff, 11000, \amp, 0.35]);
    8.wait;
    Synth(\impact, [\freq, 40, \decay, 2, \amp, 0.6]);

    "[Q 0:53] === DROP reeseHard menacant ===".postln;
    ~melodyInst = \reeseHard;
    ~melodyAttack = 0.005; ~melodyRelease = 0.25; ~melodyCutoff = 600;
    ~melodyDrive = 4.0; ~melodyAmp = 0.28;
    ~melodyNotes = [36,0,0,0, 39,0,41,0, 36,0,0,0, 41,0,0,43,
                    36,0,38,0, 39,0,41,0, 41,0,43,0, 39,0,36,0];
    ~reload.value;
    100.wait;

    "[Q 2:33] section : variations bass + acid stabs...".postln;
    ~acidNotes = [36,0,48,0,36,0,43,0, 36,0,41,0,39,0,36,0];
    ~acidAccents = [1,0,0,0,1,0,1,0, 0,1,0,0,1,0,0,0];
    ~acidSlides = [0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0];
    ~acidCutoff = 1500; ~acidRq = 0.10; ~acidDrive = 3.0; ~acidAmp = 0.25;
    ~reload.value;
    80.wait;

    "[Q 3:53] breakdown atmospheric...".postln;
    ~kickSteps = (0!16); ~snareSteps = (0!16);
    ~hatAmp = 0.06; ~acidAmp = 0;
    ~melodyInst = \warmPad;
    ~melodyAttack = 0.5; ~melodyRelease = 1.8; ~melodyCutoff = 2200;
    ~melodyAmp = 0.20;
    ~melodyNotes = [60,0,0,0,63,0,0,0, 67,0,0,0,70,0,0,0,
                    72,0,0,0,70,0,0,0, 65,0,0,0,60,0,0,0];
    ~reload.value;
    35.wait;

    "[Q 4:28] DROP 2 hard reese + amen full...".postln;
    Synth(\impact, [\freq, 32, \decay, 3, \amp, 0.7]);
    Synth(\crash, [\decay, 3, \amp, 0.4]);
    ~kickSteps  = [1,0,0,0, 0,0,1,0, 0,0,1,0, 1,0,0,0]; ~kickAmp = 0.55;
    ~snareSteps = [0,0,0,0, 1,0,0,0, 0,0,0,1, 1,0,1,1]; ~snareAmp = 0.55;
    ~hatSteps = [1,1,1,1, 0,1,1,1, 1,1,1,1, 0,1,1,1]; ~hatAmp = 0.14;
    ~melodyInst = \reeseHard;
    ~melodyCutoff = 700; ~melodyDrive = 4.5; ~melodyAmp = 0.30;
    ~acidAmp = 0.28; ~acidCutoff = 1800; ~acidDrive = 3.5;
    ~reload.value;
    100.wait;
    "[Q 6:08] new -- reeseDnB + ml1 dnb + lfo wobble + vcf ladder...".postln;
    ~melodyInst = \reeseDnB;
    ~melodyAttack = 0.005; ~melodyRelease = 0.25; ~melodyCutoff = 700;
    ~melodyDrive = 4.0; ~melodyAmp = 0.28;
    ~melodyNotes = (~ml1 ? [36,0,0,0, 39,0,41,0, 36,0,0,0, 41,0,0,43]).copy;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.6, 800, \sin, 1200) };
    ~vcfOn !? { ~vcfOn.(\ladder, 1000, 0.55) };
    ~fxPreset !? { ~fxPreset.(\industrial) };
    TempoClock.default.tempo = ~bpm/60; ~reload.value;
    40.wait;

    "[Q 6:48] new -- hooverbass neuro + freqShift + glitch...".postln;
    ~melodyInst = \hooverbass;
    ~melodyAttack = 0.005; ~melodyRelease = 0.3; ~melodyCutoff = 1500;
    ~melodyAmp = 0.24;
    ~vcfOff !? { ~vcfOff.() };
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~freqShift !? { ~freqShift.(50, 2) };
    ~glitch !? { ~glitch.(1.5) };
    ~fxPreset !? { ~fxPreset.(\dubstep) };
    TempoClock.default.tempo = ~bpm/60; ~reload.value;
    25.wait;


    "[Q 7:13] outro fade...".postln;
    Synth(\sweep, [\dur, 6, \startCutoff, 8000, \endCutoff, 200, \amp, 0.3]);
    50.do { |k|
        var x = 1 - ((k + 1) / 50);
        ~kickAmp = x * 0.55; ~snareAmp = x * 0.55; ~hatAmp = x * 0.14;
        ~melodyAmp = x * 0.30; ~acidAmp = x * 0.28;
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq]
        .do { |k| Pdef(k).stop };
    "[Q 8:03] === fin NEUROFUNK ===".postln;
}).play;
"=== TRACK Q : NEUROFUNK DNB 7 min lancee ===".postln;
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

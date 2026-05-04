// =====================================================================
//  H_acid_trance.scd  -- 8 min, 145 BPM, acid trance epique
//  Acid 303 + warmPad + arp squareLead + build classique trance
//  PREREQUIS : engine + extra
// =====================================================================
(
[~track1, ~track2, ~track3, ~track4].do { |t| t !? { t.stop } };
~track !? { ~track.stop };
~track = Routine({
    "[H 0:00] === ACID TRANCE 145 BPM ===".postln;
    [\acidSeq, \kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \melodySeq, \harmonySeq]
        .do { |k| Pdef(k).stop };
    TempoClock.default.tempo = 145 / 60;

    "[H 0:00] intro pad...".postln;
    ~melodyInst = \warmPad; ~melodyAttack = 0.6; ~melodyRelease = 2.0;
    ~melodyCutoff = 1800; ~melodyAmp = 0.16;
    ~melodyNotes = [60,0,0,0,0,0,0,0, 67,0,0,0,0,0,0,0,
                    63,0,0,0,0,0,0,0, 70,0,0,0,0,0,0,0];
    ~kickSteps=(0!16); ~hatSteps=(0!16); ~snareSteps=(0!16);
    ~clapSteps=(0!16); ~percSteps=(0!16);
    ~acidNotes = [36,36,48,36,39,36,43,39, 36,41,36,39,43,36,36,41];
    ~acidAccents = [1,0,0,0,1,0,1,0, 0,1,0,0,1,0,0,1];
    ~acidSlides = [0,0,1,0,0,0,0,1, 0,0,0,1,0,0,0,0];
    ~acidCutoff = 600; ~acidRq = 0.18; ~acidDrive = 2.5; ~acidAmp = 0;
    ~reload.value;
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq]
        .do { |k| Pdef(k).play };
    ~enableHarmony.(\tranceLayer);
    30.wait;

    "[H 0:30] kick 4/4 trance + acid entre...".postln;
    ~kickSteps = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.55;
    ~kickFreq = 60; ~kickPitchAmt = 3.5; ~kickDecay = 0.25; ~kickClick = 0.2;
    ~hatSteps = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~hatAmp = 0.15;
    ~clapSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.3;
    ~acidAmp = 0.28;
    ~reload.value;
    45.wait;

    "[H 1:15] BUILD long vers DROP acid...".postln;
    Synth(\riser, [\dur, 16, \startCutoff, 400, \endCutoff, 12000, \amp, 0.35]);
    16.do { |k|
        var x = (k + 1) / 16;
        ~acidCutoff = 600 + (x * 1500); ~acidRq = 0.18 - (x * 0.10);
        ~hatAmp = 0.15 + (x * 0.06);
        ~reload.value; 1.wait;
    };
    Synth(\impact, [\freq, 45, \decay, 2.5, \amp, 0.6]);

    "[H 1:31] === DROP ACID + lead arp ===".postln;
    ~melodyInst = \squareLead;
    ~melodyAttack = 0.003; ~melodyRelease = 0.15; ~melodyCutoff = 6000;
    ~melodyAmp = 0.16;
    ~melodyNotes = [60, 67, 72, 75, 70, 67, 60, 67,
                    63, 70, 75, 77, 72, 70, 63, 67,
                    65, 72, 75, 79, 75, 72, 65, 67,
                    60, 67, 72, 75, 70, 67, 63, 60];
    ~reload.value;
    90.wait;

    "[H 3:01] breakdown choir + acid mute...".postln;
    ~kickSteps=(0!16); ~hatAmp=0.05; ~clapSteps=(0!16);
    ~acidAmp = 0;
    ~melodyInst = \choir;
    ~melodyAttack = 0.4; ~melodyRelease = 1.5; ~melodyCutoff = 2500;
    ~melodyAmp = 0.20;
    ~reload.value;
    45.wait;

    "[H 3:46] BUILD 2 + DROP FINAL...".postln;
    Synth(\riser, [\dur, 16, \startCutoff, 400, \endCutoff, 13000, \amp, 0.4]);
    ~kickSteps = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0];
    16.do { |k|
        var x = (k + 1) / 16;
        ~hatAmp = 0.05 + (x * 0.13);
        ~reload.value; 1.wait;
    };
    Synth(\impact, [\freq, 38, \decay, 3, \amp, 0.7]);
    Synth(\crash, [\decay, 4, \amp, 0.4]);

    "[H 4:02] === DROP FINAL hardLead + acid push ===".postln;
    ~melodyInst = \hardLead;
    ~melodyAttack = 0.002; ~melodyRelease = 0.25; ~melodyCutoff = 6000;
    ~melodyAmp = 0.18;
    ~hatSteps = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~hatAmp = 0.18;
    ~clapSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0];
    ~acidAmp = 0.32; ~acidCutoff = 1500; ~acidRq = 0.08; ~acidDrive = 3.5;
    ~reload.value;
    150.wait;
    "[H 6:32] new -- supersaw acid + mxl1 + vcf moog + lfo cutoff...".postln;
    ~melodyInst = \supersaw;
    ~melodyAttack = 0.003; ~melodyRelease = 0.3; ~melodyCutoff = 5000;
    ~melodyAmp = 0.20;
    ~melodyNotes = (~mxl1 ? [60,67,72,75, 70,67,63,67, 65,72,77,79, 75,72,65,67]).copy;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.4, 2500, \sin, 5500) };
    ~vcfOn !? { ~vcfOn.(\moog, 2500, 0.4) };
    ~fxPreset !? { ~fxPreset.(\trance) };
    TempoClock.default.tempo = ~bpm/60; ~reload.value;
    45.wait;

    "[H 7:17] new -- hooverbass + drop + bitCrush hardfloor...".postln;
    ~melodyInst = \hooverbass;
    ~melodyAttack = 0.005; ~melodyRelease = 0.25; ~melodyCutoff = 1500;
    ~melodyAmp = 0.20;
    ~drop !? { ~drop.() };
    ~bitCrushNow !? { ~bitCrushNow.(8, 8000, 2) };
    ~fxPreset !? { ~fxPreset.(\industrial) };
    TempoClock.default.tempo = ~bpm/60; ~reload.value;
    25.wait;
    ~vcfOff !? { ~vcfOff.() };
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };


    "[H 7:42] outro fade...".postln;
    ~melodyInst = \warmPad;
    ~melodyAttack = 0.6; ~melodyRelease = 2.5;
    ~reload.value;
    60.do { |k|
        var x = 1 - ((k + 1) / 60);
        ~kickAmp = x * 0.55; ~hatAmp = x * 0.18; ~clapAmp = x * 0.3;
        ~acidAmp = x * 0.32; ~melodyAmp = x * 0.20;
        ~acidCutoff = 200 + (x * 1300);
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq]
        .do { |k| Pdef(k).stop };
    "[H 8:42] === fin ACID TRANCE ===".postln;
}).play;
"=== TRACK H : ACID TRANCE 8 min lancee ===".postln;
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

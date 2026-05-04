// =====================================================================
//  I_liquid_dnb.scd  -- 7 min, 174 BPM, liquid drum'n'bass
//  amen-like + warmPad + smooth lead, atmospheric
//  PREREQUIS : engine + extra
// =====================================================================
(
[~track1, ~track2, ~track3, ~track4].do { |t| t !? { t.stop } };
~track !? { ~track.stop };
~track = Routine({
    "[I 0:00] === LIQUID DNB 174 BPM ===".postln;
    [\acidSeq, \kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \melodySeq, \harmonySeq]
        .do { |k| Pdef(k).stop };
    TempoClock.default.tempo = 174 / 60;

    "[I 0:00] intro warmPad...".postln;
    ~melodyInst = \warmPad; ~melodyAttack = 0.5; ~melodyRelease = 1.8;
    ~melodyCutoff = 2000; ~melodyAmp = 0.18;
    ~melodyNotes = [60,0,0,0,0,0,0,0, 67,0,0,0,0,0,0,0,
                    63,0,0,0,0,0,0,0, 70,0,0,0,0,0,0,0];
    ~kickSteps=(0!16); ~hatSteps=(0!16); ~snareSteps=(0!16);
    ~clapSteps=(0!16); ~percSteps=(0!16); ~acidAmp=0;
    ~reload.value;
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq]
        .do { |k| Pdef(k).play };
    ~enableHarmony.(\bassline);
    20.wait;

    "[I 0:20] amen break entre...".postln;
    ~kickSteps  = [1,0,0,0, 0,0,1,0, 0,0,1,0, 1,0,0,0]; ~kickAmp = 0.5;
    ~kickFreq = 55; ~kickPitchAmt = 4.0; ~kickDecay = 0.18; ~kickClick = 0.3;
    ~snareSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,1]; ~snareAmp = 0.5;
    ~snareFreq = 240; ~snareNoiseAmt = 0.7; ~snareDecay = 0.10;
    ~hatSteps = [1,1,1,1, 0,1,1,1, 1,1,1,1, 0,1,1,1]; ~hatAmp = 0.12;
    ~reload.value;
    40.wait;

    "[I 1:00] smooth lead par-dessus...".postln;
    ~melodyInst = \fmLead;
    ~melodyAttack = 0.005; ~melodyRelease = 0.4; ~melodyCutoff = 5000;
    ~melodyAmp = 0.16;
    ~melodyNotes = [60,0,67,0,70,0,67,65, 63,0,60,0,0,67,70,72,
                    75,0,72,70,67,0,0,65, 63,60,0,67,70,0,72,0];
    ~reload.value;
    80.wait;

    "[I 2:20] reese sub bass entre...".postln;
    ~acidAmp = 0;
    ~kickAmp = 0.55;
    // sub bass via melody 2eme couche par modification
    ~melodyInst = \subBoom;
    ~melodyAttack = 0.005; ~melodyRelease = 0.6;
    ~melodyAmp = 0.30;
    ~melodyNotes = [36,0,0,0, 36,0,0,0, 39,0,0,0, 41,0,0,0,
                    36,0,0,0, 36,0,0,0, 41,0,0,0, 39,0,0,0];
    ~reload.value;
    60.wait;

    "[I 3:20] breakdown smooth choir...".postln;
    ~kickSteps=(0!16); ~snareSteps=(0!16); ~hatAmp=0.06;
    ~melodyInst = \choir;
    ~melodyAttack = 0.4; ~melodyRelease = 1.5; ~melodyCutoff = 2800;
    ~melodyAmp = 0.20;
    ~melodyNotes = [60,0,0,0,67,0,0,0, 70,0,0,0,72,0,0,0,
                    70,0,0,0,67,0,0,0, 63,0,0,0,60,0,0,0];
    ~reload.value;
    40.wait;

    "[I 4:00] DROP retour amen + lead...".postln;
    Synth(\impact, [\freq, 45, \decay, 2, \amp, 0.5]);
    ~kickSteps  = [1,0,0,0, 0,0,1,0, 0,0,1,0, 1,0,0,0];
    ~snareSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,1];
    ~hatSteps = [1,1,1,1, 0,1,1,1, 1,1,1,1, 0,1,1,1]; ~hatAmp = 0.13;
    ~melodyInst = \fmLead;
    ~melodyAttack = 0.005; ~melodyRelease = 0.4; ~melodyCutoff = 5500;
    ~melodyAmp = 0.18;
    ~melodyNotes = [60,67,72,75, 70,67,63,60, 65,70,75,77, 72,70,67,63,
                    63,70,75,79, 75,72,70,67, 60,65,70,75, 67,63,60,0];
    ~reload.value;
    120.wait;
    "[I 6:00] new -- reeseDnB + ml1 + vcf ladder + lfo wobble...".postln;
    ~melodyInst = \reeseDnB;
    ~melodyAttack = 0.005; ~melodyRelease = 0.4; ~melodyCutoff = 1200;
    ~melodyDrive = 2.2; ~melodyAmp = 0.20;
    ~melodyNotes = (~ml1 ? [36,0,0,0,36,0,0,0, 39,0,0,0,41,0,0,0]).copy;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.4, 1200, \sin, 2000) };
    ~vcfOn !? { ~vcfOn.(\ladder, 1500, 0.5) };
    ~fxPreset !? { ~fxPreset.(\dub) };
    TempoClock.default.tempo = ~bpm/60; ~reload.value;
    40.wait;

    "[I 6:40] new -- rhodes liquid + vocalPad + reverbTail...".postln;
    ~melodyInst = \rhodes;
    ~melodyAttack = 0.01; ~melodyRelease = 0.7; ~melodyCutoff = 3500;
    ~melodyAmp = 0.18;
    ~vcfOff !? { ~vcfOff.() };
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~reverbTail !? { ~reverbTail.(4) };
    ~fxPreset !? { ~fxPreset.(\dream) };
    TempoClock.default.tempo = ~bpm/60; ~reload.value;
    25.wait;


    "[I 7:05] outro pad fade...".postln;
    ~melodyInst = \warmPad;
    ~melodyAttack = 0.5; ~melodyRelease = 2.0;
    ~reload.value;
    60.do { |k|
        var x = 1 - ((k + 1) / 60);
        ~kickAmp = x * 0.5; ~snareAmp = x * 0.5; ~hatAmp = x * 0.13;
        ~melodyAmp = x * 0.20;
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq]
        .do { |k| Pdef(k).stop };
    "[I 8:05] === fin LIQUID DNB ===".postln;
}).play;
"=== TRACK I : LIQUID DNB 7 min lancee ===".postln;
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

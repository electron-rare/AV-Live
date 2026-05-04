// =====================================================================
//  F_trance_uplifter.scd  -- 10 min, 138 BPM, trance classique
//  warmPad + arp squareLead + organLead, build/drop epique
//  PREREQUIS : engine + extra
// =====================================================================
(
[~track1, ~track2, ~track3, ~track4].do { |t| t !? { t.stop } };
~track !? { ~track.stop };
~track = Routine({
    "[F 0:00] === TRANCE UPLIFTER 138 BPM ===".postln;
    [\acidSeq, \kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \melodySeq, \harmonySeq]
        .do { |k| Pdef(k).stop };
    TempoClock.default.tempo = 138 / 60;

    "[F 0:00] intro warmPad...".postln;
    ~melodyInst = \warmPad; ~melodyAttack = 0.6; ~melodyRelease = 2.0;
    ~melodyCutoff = 1800; ~melodyAmp = 0.18;
    ~melodyNotes = [60,0,0,0,67,0,0,0, 70,0,0,0,72,0,0,0,
                    72,0,0,0,70,0,0,0, 67,0,0,0,63,0,0,0];
    ~kickSteps = (0!16); ~hatSteps = (0!16); ~snareSteps = (0!16);
    ~clapSteps = (0!16); ~percSteps = (0!16); ~acidAmp = 0;
    ~reload.value;
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq]
        .do { |k| Pdef(k).play };
    ~enableHarmony.(\tranceLayer);
    45.wait;

    "[F 0:45] kick 4/4 + hat offbeat...".postln;
    ~kickSteps = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.5;
    ~kickFreq = 50; ~kickPitchAmt = 2.8; ~kickDecay = 0.32; ~kickClick = 0.15;
    ~hatSteps = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~hatAmp = 0.16;
    ~clapSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.3;
    ~reload.value;
    45.wait;

    "[F 1:30] arp squareLead entre...".postln;
    ~melodyInst = \squareLead;
    ~melodyAttack = 0.005; ~melodyRelease = 0.2; ~melodyCutoff = 5000;
    ~melodyAmp = 0.16;
    ~melodyNotes = [60, 67, 70, 72, 70, 67, 60, 67,
                    63, 70, 72, 75, 72, 70, 63, 70,
                    65, 72, 75, 77, 75, 72, 65, 72,
                    63, 70, 72, 75, 72, 70, 63, 60];
    ~reload.value;
    60.wait;

    "[F 2:30] BUILD vers DROP...".postln;
    Synth(\riser, [\dur, 16, \startCutoff, 400, \endCutoff, 11000, \amp, 0.3]);
    16.do { |k|
        var x = (k + 1) / 16;
        ~hatAmp = 0.16 + (x * 0.08);
        ~melodyCutoff = 5000 + (x * 3000);
        ~reload.value;
        1.wait;
    };
    Synth(\impact, [\freq, 45, \decay, 2.5, \amp, 0.6]);

    "[F 2:46] === DROP organLead trance ===".postln;
    ~melodyInst = \organLead;
    ~melodyAttack = 0.005; ~melodyRelease = 0.15; ~melodyCutoff = 4500;
    ~melodyAmp = 0.20;
    ~kickAmp = 0.55;
    ~reload.value;
    90.wait;

    "[F 4:16] verse hardLead...".postln;
    ~melodyInst = \hardLead;
    ~melodyAttack = 0.002; ~melodyRelease = 0.25; ~melodyCutoff = 5500;
    ~reload.value;
    60.wait;

    "[F 5:16] breakdown choir + strings...".postln;
    ~kickSteps = (0!16); ~hatAmp = 0.06; ~clapSteps = (0!16);
    ~melodyInst = \choir;
    ~melodyAttack = 0.4; ~melodyRelease = 1.5; ~melodyCutoff = 2500;
    ~melodyAmp = 0.18;
    ~melodyNotes = [60, 0, 0, 0, 63, 0, 0, 0, 67, 0, 0, 0, 70, 0, 0, 0,
                    72, 0, 0, 0, 70, 0, 0, 0, 67, 0, 0, 0, 63, 0, 0, 0];
    ~reload.value;
    45.wait;

    "[F 6:01] BUILD 2 + impact final...".postln;
    Synth(\riser, [\dur, 16, \startCutoff, 500, \endCutoff, 12000, \amp, 0.4]);
    ~kickSteps = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.5;
    ~hatSteps = [1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1];
    16.do { |k| ~hatAmp = 0.06 + ((k + 1) / 16 * 0.10); ~reload.value; 1.wait };
    Synth(\impact, [\freq, 38, \decay, 3, \amp, 0.7]);
    Synth(\crash, [\decay, 4, \amp, 0.4]);

    "[F 6:17] === DROP FINAL squareLead arp ===".postln;
    ~melodyInst = \squareLead;
    ~melodyAttack = 0.003; ~melodyRelease = 0.2; ~melodyCutoff = 6500;
    ~melodyAmp = 0.20;
    ~hatSteps = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~hatAmp = 0.18;
    ~clapSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0];
    ~reload.value;
    150.wait;
    "[F 8:47] new -- supersaw + mxl1 trance epic + lfo cutoff...".postln;
    ~melodyInst = \supersaw;
    ~melodyAttack = 0.005; ~melodyRelease = 0.4; ~melodyCutoff = 4500;
    ~melodyAmp = 0.20;
    ~melodyNotes = (~mxl1 ? [60,67,72,75, 70,67,63,60, 65,72,77,79, 75,72,70,67]).copy;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.5, 2000, \sin, 5000) };
    ~vcfOn !? { ~vcfOn.(\moog, 2200, 0.4) };
    ~fxPreset !? { ~fxPreset.(\trance) };
    TempoClock.default.tempo = ~bpm/60; ~reload.value;
    50.wait;

    "[F 9:37] new -- vocalPad breakdown + buildup + drop final...".postln;
    ~melodyInst = \vocalPad;
    ~melodyAttack = 0.4; ~melodyRelease = 1.8; ~melodyCutoff = 2500;
    ~melodyAmp = 0.20;
    ~breakdown !? { ~breakdown.(6) };
    ~fxPreset !? { ~fxPreset.(\space) };
    TempoClock.default.tempo = ~bpm/60; ~reload.value;
    20.wait;
    ~buildup !? { ~buildup.(6) };
    ~drop !? { ~drop.() };
    ~vcfOff !? { ~vcfOff.() };
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    20.wait;


    "[F 10:17] outro warmPad fade...".postln;
    ~melodyInst = \warmPad;
    ~melodyAttack = 0.6; ~melodyRelease = 2.5; ~melodyCutoff = 1500;
    ~reload.value;
    60.do { |k|
        var x = 1 - ((k + 1) / 60);
        ~kickAmp = x * 0.55; ~hatAmp = x * 0.18; ~clapAmp = x * 0.3;
        ~melodyAmp = x * 0.18; ~melodyCutoff = 200 + (x * 1300);
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq]
        .do { |k| Pdef(k).stop };
    "[F 11:17] === fin TRANCE UPLIFTER ===".postln;
}).play;
"=== TRACK F : TRANCE UPLIFTER 10 min lancee ===".postln;
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

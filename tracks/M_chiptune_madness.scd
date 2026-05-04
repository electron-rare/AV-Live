// =====================================================================
//  M_chiptune_madness.scd  -- 6 min, 150 BPM, chiptune 8-bit
//  squareLead arp + kick chiptune + melodies harmonisees
//  PREREQUIS : engine + extra
// =====================================================================
(
[~track1, ~track2, ~track3, ~track4].do { |t| t !? { t.stop } };
~track !? { ~track.stop };
~track = Routine({
    "[M 0:00] === CHIPTUNE MADNESS 150 BPM ===".postln;
    [\acidSeq, \kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \melodySeq, \harmonySeq]
        .do { |k| Pdef(k).stop };
    TempoClock.default.tempo = 150 / 60;

    "[M 0:00] intro arp seul...".postln;
    ~melodyInst = \squareLead;
    ~melodyAttack = 0.003; ~melodyRelease = 0.15; ~melodyCutoff = 5500;
    ~melodyAmp = 0.18;
    ~melodyNotes = [60,67,72,67, 60,65,72,65, 63,70,75,70, 63,67,72,67,
                    60,67,72,79, 75,72,67,60, 63,67,75,79, 75,72,67,63];
    ~kickSteps=(0!16); ~hatSteps=(0!16); ~snareSteps=(0!16);
    ~clapSteps=(0!16); ~percSteps=(0!16); ~acidAmp=0;
    ~reload.value;
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq]
        .do { |k| Pdef(k).play };
    ~enableHarmony.(\arp);
    20.wait;

    "[M 0:20] kick chip + hat fast...".postln;
    ~kickSteps = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.45;
    ~kickFreq = 70; ~kickPitchAmt = 4.0; ~kickDecay = 0.15; ~kickClick = 0.4;
    ~hatSteps = [1,0,1,0, 1,0,1,0, 1,0,1,0, 1,0,1,0]; ~hatAmp = 0.12;
    ~snareSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~snareAmp = 0.4;
    ~snareFreq = 280;
    ~reload.value;
    40.wait;

    "[M 1:00] arp variations...".postln;
    ~melodyNotes = [60,67,72,75, 70,67,60,67, 63,70,75,77, 72,70,63,70,
                    65,72,77,79, 75,72,65,72, 60,67,72,79, 75,72,67,60];
    ~reload.value;
    50.wait;

    "[M 1:50] DROP square + sub punchy...".postln;
    ~melodyInst = \squareLead;
    ~melodyCutoff = 6500; ~melodyAmp = 0.20;
    ~kickAmp = 0.5;
    Synth(\impact, [\freq, 50, \decay, 1.5, \amp, 0.4]);
    ~melodyNotes = [60, 0, 67, 60, 72, 67, 60, 67,
                    63, 0, 70, 63, 75, 70, 63, 70,
                    65, 0, 72, 65, 77, 72, 65, 72,
                    63, 0, 70, 63, 75, 70, 67, 60];
    ~reload.value;
    70.wait;

    "[M 3:00] breakdown handpan asiatique...".postln;
    ~kickSteps = [1,0,0,0, 0,0,0,0, 1,0,0,0, 0,0,0,0];
    ~hatAmp = 0.06;
    ~melodyInst = \handpan;
    ~melodyAttack = 0.001; ~melodyRelease = 1.0; ~melodyCutoff = 4500;
    ~melodyAmp = 0.20;
    ~melodyNotes = [60,0,67,0,72,0,67,0, 65,0,70,0,75,0,70,0,
                    63,0,70,0,75,0,79,0, 75,0,72,0,67,0,60,0];
    ~reload.value;
    30.wait;

    "[M 3:30] DROP FINAL chip arp + tom rolls...".postln;
    Synth(\impact, [\freq, 45, \decay, 1.5, \amp, 0.4]);
    Synth(\crash, [\decay, 2, \amp, 0.3]);
    ~kickSteps = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0];
    ~hatSteps = [1,1,1,0, 1,1,1,0, 1,1,1,0, 1,1,1,0]; ~hatAmp = 0.13;
    ~melodyInst = \squareLead;
    ~melodyAttack = 0.002; ~melodyRelease = 0.12; ~melodyCutoff = 7000;
    ~melodyAmp = 0.22;
    ~melodyNotes = [60,67,72,79, 75,72,67,72, 63,70,75,82, 79,75,70,75,
                    65,72,77,84, 79,77,72,77, 60,67,72,79, 75,72,67,60];
    ~percInst = \tom; ~tomFreq = 140;
    ~percSteps = [0,0,0,0, 0,0,0,0, 0,0,0,1, 0,1,0,1]; ~percAmp = 0.3;
    ~reload.value;
    100.wait;
    "[M 5:10] new -- squareLead + bitCrush constant + glitch chip...".postln;
    ~melodyInst = \squareLead;
    ~melodyAttack = 0.002; ~melodyRelease = 0.12; ~melodyCutoff = 7500;
    ~melodyAmp = 0.22;
    ~melodyNotes = (~ml5 ? [60,67,72,79, 75,72,67,60, 63,70,75,79, 75,72,67,63]).copy;
    ~bitCrushNow !? { ~bitCrushNow.(4, 4000, 4) };
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 1.5, 3000, \sqr, 6500) };
    ~fxPreset !? { ~fxPreset.(\retro) };
    TempoClock.default.tempo = ~bpm/60; ~reload.value;
    35.wait;

    "[M 5:45] new -- fmLead + glitch + ringMod chiptune chaos...".postln;
    ~melodyInst = \fmLead;
    ~melodyAttack = 0.002; ~melodyRelease = 0.15; ~melodyCutoff = 7000;
    ~melodyAmp = 0.20;
    ~glitch !? { ~glitch.(2) };
    ~ringMod !? { ~ringMod.(440, 2) };
    ~fxPreset !? { ~fxPreset.(\retro) };
    TempoClock.default.tempo = ~bpm/60; ~reload.value;
    20.wait;
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };


    "[M 6:05] outro chip degrade...".postln;
    50.do { |k|
        var x = 1 - ((k + 1) / 50);
        ~kickAmp = x * 0.5; ~hatAmp = x * 0.13; ~percAmp = x * 0.3;
        ~melodyAmp = x * 0.22;
        ~melodyCutoff = 200 + (x * 6000);
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq]
        .do { |k| Pdef(k).stop };
    "[M 6:55] === fin CHIPTUNE ===".postln;
}).play;
"=== TRACK M : CHIPTUNE MADNESS 6 min lancee ===".postln;
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

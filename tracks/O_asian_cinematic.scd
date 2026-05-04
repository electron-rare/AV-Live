// =====================================================================
//  O_asian_cinematic.scd  -- 10 min, 92 BPM, asian cinematic non-dance
//  erhu + koto + pipa + gong + flute, ample, expressif
//  PREREQUIS : engine + asia + extra
// =====================================================================
(
[~track1, ~track2, ~track3, ~track4].do { |t| t !? { t.stop } };
~track !? { ~track.stop };
~scaleVietnamMaj = [60, 62, 65, 67, 69, 72, 74, 77];
~track = Routine({
    "[O 0:00] === ASIAN CINEMATIC 92 BPM ===".postln;
    [\acidSeq, \kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \melodySeq, \harmonySeq]
        .do { |k| Pdef(k).stop };
    TempoClock.default.tempo = 92 / 60;

    "[O 0:00] gong puis koto solo...".postln;
    Synth(\gong, [\freq, 60, \decay, 8, \amp, 0.6]);
    ~melodyInst = \koto;
    ~melodyAttack = 0.001; ~melodyRelease = 0.6; ~melodyCutoff = 6000;
    ~melodyAmp = 0.24;
    ~melodyNotes = [60,0,67,0,72,0,67,65, 63,0,60,0,0,67,70,72,
                    65,0,72,0,67,0,72,75, 70,0,67,0,65,0,60,0];
    ~kickSteps=(0!16); ~hatSteps=(0!16); ~snareSteps=(0!16);
    ~clapSteps=(0!16); ~percSteps=(0!16); ~acidAmp=0;
    ~reload.value;
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq]
        .do { |k| Pdef(k).play };
    ~enableHarmony.(\counter);
    60.wait;

    "[O 1:00] erhu chante par-dessus...".postln;
    ~melodyInst = \erhu;
    ~melodyAttack = 0.05; ~melodyRelease = 0.5; ~melodyCutoff = 2500;
    ~melodyAmp = 0.22;
    ~melodyNotes = [60,0,0,65,67,0,69,0, 72,0,69,67,65,0,60,0,
                    65,0,0,69,72,0,74,0, 77,0,74,72,69,0,65,0];
    ~reload.value;
    90.wait;

    "[O 2:30] tom doux entre (rythme tres lent)...".postln;
    ~percInst = \tom; ~tomFreq = 80;
    ~percSteps = [1,0,0,0, 0,0,0,0, 0,0,1,0, 0,0,0,0]; ~percAmp = 0.3;
    ~reload.value;
    60.wait;

    "[O 3:30] pipa solo expressif...".postln;
    Synth(\gong, [\freq, 70, \decay, 7, \amp, 0.4]);
    ~melodyInst = \pipa;
    ~melodyAttack = 0.001; ~melodyRelease = 0.6; ~melodyCutoff = 4500;
    ~melodyAmp = 0.24;
    ~melodyNotes = [72,0,75,77,79,0,77,75, 72,0,69,0,67,0,65,0,
                    77,0,79,82,84,0,82,79, 77,0,72,0,69,0,67,0];
    ~reload.value;
    90.wait;

    "[O 5:00] section ample : strings + flute layered...".postln;
    ~melodyInst = \strings;
    ~melodyAttack = 0.4; ~melodyRelease = 1.5; ~melodyCutoff = 3500;
    ~melodyAmp = 0.20;
    ~melodyNotes = [60,0,0,0,67,0,0,0, 70,0,0,0,72,0,0,0,
                    72,0,0,0,70,0,0,0, 65,0,0,0,60,0,0,0];
    ~percSteps = [1,0,0,1, 0,0,1,0, 0,0,0,0, 1,0,0,0]; ~percAmp = 0.32;
    ~reload.value;
    90.wait;

    "[O 6:30] flute melodique aerienne...".postln;
    ~melodyInst = \flute;
    ~melodyAttack = 0.1; ~melodyRelease = 0.6; ~melodyCutoff = 4000;
    ~melodyAmp = 0.22;
    ~melodyNotes = [72,0,77,0,79,77,72,0, 70,0,72,77,75,72,67,0,
                    77,0,82,0,84,82,79,0, 77,0,79,82,77,72,69,0];
    ~reload.value;
    90.wait;

    "[O 8:00] retour koto + erhu duo descente...".postln;
    Synth(\gong, [\freq, 50, \decay, 10, \amp, 0.55]);
    ~percSteps = [1,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0]; ~percAmp = 0.2;
    ~melodyInst = \erhu;
    ~melodyAttack = 0.06; ~melodyRelease = 0.6; ~melodyCutoff = 2000;
    ~melodyAmp = 0.20;
    ~melodyNotes = [72,0,0,0,69,0,0,0, 67,0,0,0,65,0,0,0,
                    63,0,0,0,60,0,0,0, 65,0,0,0,60,0,0,0];
    ~reload.value;
    60.wait;
    "[O 9:00] new -- guzheng + ml10 hirajoshi + tapeReverse cinematic...".postln;
    ~melodyInst = \guzheng;
    ~melodyAttack = 0.001; ~melodyRelease = 0.7; ~melodyCutoff = 4500;
    ~melodyAmp = 0.24;
    ~melodyNotes = (~ml10 ? [60,0,62,0,63,0,67,68, 60,0,62,63,67,0,68,72]).copy;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.2, 1200, \sin, 4000) };
    ~tapeReverse !? { ~tapeReverse.(3) };
    ~fxPreset !? { ~fxPreset.(\dream) };
    TempoClock.default.tempo = ~bpm/60; ~reload.value;
    50.wait;

    "[O 9:50] new -- shakuhachi + vocalPad + reverbTail asian...".postln;
    ~melodyInst = \shakuhachi;
    ~melodyAttack = 0.05; ~melodyRelease = 0.9; ~melodyCutoff = 3500;
    ~melodyAmp = 0.22;
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~reverbTail !? { ~reverbTail.(5) };
    ~fxPreset !? { ~fxPreset.(\cosmic) };
    TempoClock.default.tempo = ~bpm/60; ~reload.value;
    40.wait;


    "[O 10:30] outro long, gong final...".postln;
    Synth(\gong, [\freq, 40, \decay, 15, \amp, 0.7]);
    60.do { |k|
        var x = 1 - ((k + 1) / 60);
        ~percAmp = x * 0.2;
        ~melodyAmp = x * 0.20; ~melodyCutoff = 200 + (x * 1800);
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq]
        .do { |k| Pdef(k).stop };
    "[O 11:30] === fin ASIAN CINEMATIC ===".postln;
}).play;
"=== TRACK O : ASIAN CINEMATIC 10 min lancee ===".postln;
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

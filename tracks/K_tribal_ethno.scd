// =====================================================================
//  K_tribal_ethno.scd  -- 8 min, 100 BPM, tribal ethnique
//  handpan + tom + flute + percussions, organique
//  PREREQUIS : engine + extra
// =====================================================================
(
[~track1, ~track2, ~track3, ~track4].do { |t| t !? { t.stop } };
~track !? { ~track.stop };
~track = Routine({
    "[K 0:00] === TRIBAL ETHNO 100 BPM ===".postln;
    [\acidSeq, \kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \melodySeq, \harmonySeq]
        .do { |k| Pdef(k).stop };
    TempoClock.default.tempo = 100 / 60;

    "[K 0:00] tom + handpan intro...".postln;
    ~melodyInst = \handpan;
    ~melodyAttack = 0.001; ~melodyRelease = 1.5; ~melodyCutoff = 5000;
    ~melodyAmp = 0.22;
    ~melodyNotes = [60,0,67,0,70,0,72,0, 70,67,0,63,0,0,60,0,
                    63,0,67,0,70,0,75,0, 70,0,67,0,63,0,60,0];
    ~percInst = \tom; ~tomFreq = 90;
    ~percSteps = [1,0,0,1, 0,0,1,0, 1,0,0,0, 0,1,0,0]; ~percAmp = 0.4;
    ~kickSteps=(0!16); ~hatSteps=(0!16); ~snareSteps=(0!16); ~clapSteps=(0!16);
    ~acidAmp=0;
    ~reload.value;
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq]
        .do { |k| Pdef(k).play };
    ~enableHarmony.(\fifth);
    45.wait;

    "[K 0:45] kick lent + tom plus dense...".postln;
    ~kickSteps  = [1,0,0,0, 0,0,0,0, 1,0,0,0, 0,0,0,0]; ~kickAmp = 0.5;
    ~kickFreq = 50; ~kickPitchAmt = 2.5; ~kickDecay = 0.4; ~kickClick = 0.1;
    ~percSteps = [1,0,1,1, 0,1,0,1, 1,0,1,0, 0,1,1,0]; ~percAmp = 0.35;
    ~reload.value;
    45.wait;

    "[K 1:30] flute chante par-dessus...".postln;
    ~melodyInst = \flute;
    ~melodyAttack = 0.08; ~melodyRelease = 0.4; ~melodyCutoff = 3500;
    ~melodyAmp = 0.20;
    ~melodyNotes = [72,0,75,0,77,75,72,0, 70,0,72,0,75,0,77,0,
                    79,0,77,75,72,0,70,0, 72,0,75,0,77,0,79,0];
    ~reload.value;
    60.wait;

    "[K 2:30] hat secondaire entre...".postln;
    ~percInst = \openHat;
    ~hatSteps = [0,0,1,0, 0,0,0,1, 0,0,1,0, 0,1,0,0]; ~hatAmp = 0.10;
    ~percSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,1,0]; ~percAmp = 0.18;
    ~reload.value;
    60.wait;

    "[K 3:30] handpan duo avec flute...".postln;
    ~melodyInst = \handpan;
    ~melodyAttack = 0.001; ~melodyRelease = 1.2; ~melodyCutoff = 4500;
    ~melodyAmp = 0.22;
    ~melodyNotes = [72,0,79,0,75,72,67,0, 70,0,72,0,77,0,75,0,
                    79,0,82,79,77,72,67,0, 75,0,77,0,79,0,82,0];
    ~reload.value;
    60.wait;

    "[K 4:30] section dense full ensemble...".postln;
    ~percInst = \tom; ~tomFreq = 90;
    ~percSteps = [1,0,1,0, 0,1,1,0, 1,0,0,1, 0,1,0,1]; ~percAmp = 0.38;
    ~hatSteps = [1,0,1,0, 1,0,1,0, 1,0,1,0, 1,0,1,0]; ~hatAmp = 0.10;
    ~kickSteps = [1,0,0,0, 0,0,1,0, 1,0,0,0, 0,0,1,0];
    ~reload.value;
    90.wait;

    "[K 6:00] descente, juste flute + drone...".postln;
    Synth(\gong, [\freq, 60, \decay, 6, \amp, 0.4]);
    ~kickSteps = [1,0,0,0, 0,0,0,0, 1,0,0,0, 0,0,0,0]; ~kickAmp = 0.4;
    ~percSteps = [1,0,0,0, 0,0,1,0, 0,0,0,0, 0,0,0,0]; ~percAmp = 0.25;
    ~hatAmp = 0.06;
    ~melodyInst = \flute;
    ~melodyAttack = 0.1; ~melodyRelease = 0.6;
    ~melodyAmp = 0.18;
    ~reload.value;
    60.wait;
    "[K 7:00] new -- taiko + tabla + didgeridoo + ml10 ethno...".postln;
    ~melodyInst = \didgeridoo;
    ~melodyAttack = 0.4; ~melodyRelease = 1.5; ~melodyCutoff = 1500;
    ~melodyAmp = 0.20;
    ~melodyNotes = (~ml10 ? [48,0,0,0,55,0,0,0, 0,0,0,0,0,0,0,0]).copy;
    ~percInst = \taiko; ~tomFreq = 75; ~percAmp = 0.45;
    ~percSteps = [1,0,0,1, 0,0,1,0, 1,0,0,0, 0,1,0,0];
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.2, 800, \sin, 1500) };
    ~fxPreset !? { ~fxPreset.(\dub) };
    TempoClock.default.tempo = ~bpm/60; ~reload.value;
    50.wait;

    "[K 7:50] new -- handpan + tabla world evolve + glitch...".postln;
    ~melodyInst = \handpan;
    ~melodyAttack = 0.001; ~melodyRelease = 1.5; ~melodyCutoff = 4500;
    ~melodyAmp = 0.22;
    ~percInst = \tabla; ~percAmp = 0.4;
    ~percSteps = [1,0,1,0, 0,1,0,1, 1,0,1,0, 0,1,0,1];
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~stutter !? { ~stutter.(6, 1.5) };
    ~fxPreset !? { ~fxPreset.(\space) };
    TempoClock.default.tempo = ~bpm/60; ~reload.value;
    35.wait;


    "[K 8:25] outro fade...".postln;
    Synth(\gong, [\freq, 45, \decay, 8, \amp, 0.5]);
    60.do { |k|
        var x = 1 - ((k + 1) / 60);
        ~kickAmp = x * 0.4; ~hatAmp = x * 0.06; ~percAmp = x * 0.25;
        ~melodyAmp = x * 0.18;
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq]
        .do { |k| Pdef(k).stop };
    "[K 9:25] === fin TRIBAL ETHNO ===".postln;
}).play;
"=== TRACK K : TRIBAL ETHNO 8 min lancee ===".postln;
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

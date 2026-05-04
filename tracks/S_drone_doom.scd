// =====================================================================
//  S_drone_doom.scd  -- 15 min, 60 BPM, drone doom ultra lent
//  drone + handpan + flute + gong, evolution glaciale
//  PREREQUIS : engine + asia + extra
// =====================================================================
(
[~track1, ~track2, ~track3, ~track4].do { |t| t !? { t.stop } };
~track !? { ~track.stop };
~track = Routine({
    "[S 0:00] === DRONE DOOM 60 BPM ===".postln;
    [\acidSeq, \kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \melodySeq, \harmonySeq]
        .do { |k| Pdef(k).stop };
    TempoClock.default.tempo = 60 / 60;

    "[S 0:00] gong + drone profond...".postln;
    Synth(\gong, [\freq, 35, \decay, 20, \amp, 0.7]);
    ~melodyInst = \drone;
    ~melodyAttack = 3.0; ~melodyRelease = 4.0; ~melodyCutoff = 1000;
    ~melodyAmp = 0.22;
    ~melodyNotes = [36,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,
                    36,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0];
    ~kickSteps=(0!16); ~hatSteps=(0!16); ~snareSteps=(0!16);
    ~clapSteps=(0!16); ~percSteps=(0!16); ~acidAmp=0;
    ~reload.value;
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq]
        .do { |k| Pdef(k).play };
    ~enableHarmony.(\fifth);
    120.wait;

    "[S 2:00] couches drone evolutives...".postln;
    ~melodyNotes = [36,0,0,0,39,0,0,0, 0,0,0,0,0,0,0,0,
                    36,0,0,0,41,0,0,0, 0,0,0,0,0,0,0,0];
    ~melodyCutoff = 1500;
    ~reload.value;
    120.wait;

    "[S 4:00] handpan emerge tres lent...".postln;
    Synth(\gong, [\freq, 50, \decay, 15, \amp, 0.5]);
    ~melodyInst = \handpan;
    ~melodyAttack = 0.001; ~melodyRelease = 3.0; ~melodyCutoff = 4000;
    ~melodyAmp = 0.22;
    ~melodyNotes = [48,0,0,0,55,0,0,0, 0,0,0,0,0,0,0,0,
                    48,0,0,0,60,0,0,0, 0,0,0,0,0,0,0,0];
    ~reload.value;
    150.wait;

    "[S 6:30] flute solitaire...".postln;
    ~melodyInst = \flute;
    ~melodyAttack = 0.2; ~melodyRelease = 1.0; ~melodyCutoff = 3500;
    ~melodyAmp = 0.18;
    ~melodyNotes = [60,0,0,0,65,0,0,0, 0,67,0,0,0,0,0,0,
                    65,0,0,60,0,0,0,0, 67,0,0,0,72,0,0,0];
    ~reload.value;
    120.wait;

    "[S 8:30] retour drone + pulsation tres lente...".postln;
    Synth(\gong, [\freq, 30, \decay, 25, \amp, 0.8]);
    ~percInst = \tom; ~tomFreq = 60;
    ~percSteps = [1,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0]; ~percAmp = 0.35;
    ~melodyInst = \drone;
    ~melodyAttack = 2.5; ~melodyRelease = 4.0; ~melodyCutoff = 800;
    ~melodyAmp = 0.20;
    ~melodyNotes = [36,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,
                    36,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0];
    ~reload.value;
    150.wait;

    "[S 11:00] choir mystique...".postln;
    ~melodyInst = \choir;
    ~melodyAttack = 1.0; ~melodyRelease = 2.5; ~melodyCutoff = 2200;
    ~melodyAmp = 0.18;
    ~melodyNotes = [48,0,0,0,55,0,0,0, 60,0,0,0,55,0,0,0,
                    48,0,0,0,55,0,0,0, 63,0,0,0,55,0,0,0];
    ~reload.value;
    120.wait;
    "[S 13:00] new -- didgeridoo drone + mepic1 ambient + freeze constant...".postln;
    ~melodyInst = \didgeridoo;
    ~melodyAttack = 1.5; ~melodyRelease = 3.0; ~melodyCutoff = 1000;
    ~melodyAmp = 0.20;
    ~melodyNotes = (~mepic1 ? [36,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0]).copy;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.05, 400, \sin, 1000) };
    ~freeze !? { ~freeze.(10) };
    ~fxPreset !? { ~fxPreset.(\drone) };
    TempoClock.default.tempo = ~bpm/60; ~reload.value;
    100.wait;

    "[S 14:40] new -- vocalPad + reverbTail final doom...".postln;
    ~melodyInst = \vocalPad;
    ~melodyAttack = 2.0; ~melodyRelease = 4.0; ~melodyCutoff = 1500;
    ~melodyAmp = 0.18;
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~reverbTail !? { ~reverbTail.(8) };
    ~fxPreset !? { ~fxPreset.(\cosmic) };
    TempoClock.default.tempo = ~bpm/60; ~reload.value;
    60.wait;


    "[S 15:40] outro tres lent fade...".postln;
    Synth(\gong, [\freq, 25, \decay, 30, \amp, 0.9]);
    ~percSteps = (0!16);
    120.do { |k|
        var x = 1 - ((k + 1) / 120);
        ~melodyAmp = x * 0.18; ~melodyCutoff = 200 + (x * 1000);
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq]
        .do { |k| Pdef(k).stop };
    "[S 17:40] === fin DRONE DOOM ===".postln;
}).play;
"=== TRACK S : DRONE DOOM 15 min lancee ===".postln;
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

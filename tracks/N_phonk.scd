// =====================================================================
//  N_phonk.scd  -- 5 min, 130 BPM, phonk dark drift
//  cowbell + 808 sub + dark melody + lazy kick
//  PREREQUIS : engine + extra
// =====================================================================
(
[~track1, ~track2, ~track3, ~track4].do { |t| t !? { t.stop } };
~track !? { ~track.stop };
~track = Routine({
    "[N 0:00] === PHONK 130 BPM ===".postln;
    [\acidSeq, \kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \melodySeq, \harmonySeq]
        .do { |k| Pdef(k).stop };
    TempoClock.default.tempo = 130 / 60;

    "[N 0:00] cowbell + dark pad...".postln;
    ~melodyInst = \warmPad;
    ~melodyAttack = 0.5; ~melodyRelease = 1.5; ~melodyCutoff = 1200;
    ~melodyAmp = 0.16;
    ~melodyNotes = [48,0,0,0,0,0,0,0, 51,0,0,0,53,0,0,0,
                    48,0,0,0,0,0,0,0, 51,0,0,0,55,0,0,0];
    ~percInst = \cowbell; ~cowbellFreq = 800;
    ~percSteps = [0,0,1,0, 0,1,0,0, 1,0,0,1, 0,0,1,0]; ~percAmp = 0.3;
    ~kickSteps=(0!16); ~hatSteps=(0!16); ~snareSteps=(0!16);
    ~clapSteps=(0!16); ~acidAmp=0;
    ~reload.value;
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq]
        .do { |k| Pdef(k).play };
    ~enableHarmony.(\bassline);
    20.wait;

    "[N 0:20] kick + hi-hats triplets...".postln;
    ~kickSteps = [1,0,0,0, 0,0,0,1, 1,0,0,0, 0,1,0,0]; ~kickAmp = 0.55;
    ~kickFreq = 45; ~kickPitchAmt = 2.5; ~kickDecay = 0.5; ~kickClick = 0.1;
    ~hatSteps = [1,0,1,1, 0,1,1,0, 1,0,1,1, 0,1,1,0]; ~hatAmp = 0.10;
    ~clapSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.32;
    ~reload.value;
    30.wait;

    "[N 0:50] sub 808 entre...".postln;
    ~melodyInst = \subBoom;
    ~melodyAttack = 0.005; ~melodyRelease = 0.5; ~melodyAmp = 0.36;
    ~melodyNotes = [36,0,0,0, 0,0,0,36, 39,0,0,0, 0,41,0,0,
                    36,0,0,0, 0,0,0,38, 41,0,0,0, 0,39,0,0];
    ~reload.value;
    60.wait;

    "[N 1:50] section dark fmBass...".postln;
    ~melodyInst = \fmBass;
    ~melodyAttack = 0.005; ~melodyRelease = 0.3; ~melodyCutoff = 1500;
    ~melodyAmp = 0.32;
    ~melodyNotes = [36,0,39,0, 36,0,0,41, 39,0,36,0, 41,0,43,0,
                    36,0,39,0, 41,0,43,0, 39,0,36,0, 41,39,36,0];
    ~reload.value;
    60.wait;

    "[N 2:50] breakdown atmosphere + cowbell solo...".postln;
    ~kickSteps=(0!16); ~hatAmp=0.05; ~clapSteps=(0!16);
    ~percAmp = 0.4;
    ~melodyInst = \warmPad;
    ~melodyAttack = 0.5; ~melodyRelease = 1.8; ~melodyCutoff = 1500;
    ~melodyAmp = 0.18;
    ~reload.value;
    25.wait;

    "[N 3:15] DROP retour + sub massif...".postln;
    Synth(\impact, [\freq, 30, \decay, 2.5, \amp, 0.6]);
    ~kickSteps = [1,0,0,0, 0,0,0,1, 1,0,0,0, 0,1,0,0];
    ~hatSteps = [1,0,1,1, 0,1,1,0, 1,0,1,1, 0,1,1,0]; ~hatAmp = 0.11;
    ~clapSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.35;
    ~melodyInst = \subBoom;
    ~melodyAmp = 0.40;
    ~melodyNotes = [36,0,0,0, 39,0,0,0, 36,0,0,41, 39,0,0,0,
                    36,0,38,0, 39,0,0,41, 43,0,41,0, 39,0,36,0];
    ~reload.value;
    75.wait;
    "[N 4:30] new -- vocalPad pitched + bitCrush phonk dark + 808...".postln;
    ~melodyInst = \vocalPad;
    ~melodyAttack = 0.4; ~melodyRelease = 1.5; ~melodyCutoff = 1800;
    ~melodyAmp = 0.18;
    ~melodyNotes = (~ml5 ? [48,0,0,0,51,0,0,0, 53,0,0,0,55,0,0,0]).copy;
    ~bitCrushNow !? { ~bitCrushNow.(8, 8000, 3) };
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.25, 800, \sin, 1800) };
    ~fxPreset !? { ~fxPreset.(\industrial) };
    TempoClock.default.tempo = ~bpm/60; ~reload.value;
    30.wait;

    "[N 5:00] new -- subBoom 808 + tapeStop dark phonk drop...".postln;
    ~melodyInst = \bass808;
    ~melodyAttack = 0.005; ~melodyRelease = 0.6; ~melodyAmp = 0.34;
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~tapeStop !? { ~tapeStop.(1.5) };
    ~fxPreset !? { ~fxPreset.(\dub) };
    TempoClock.default.tempo = ~bpm/60; ~reload.value;
    20.wait;


    "[N 5:20] outro fade...".postln;
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~kickAmp = x * 0.55; ~hatAmp = x * 0.11; ~clapAmp = x * 0.35;
        ~percAmp = x * 0.3; ~melodyAmp = x * 0.40;
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq]
        .do { |k| Pdef(k).stop };
    "[N 5:50] === fin PHONK ===".postln;
}).play;
"=== TRACK N : PHONK 5 min lancee ===".postln;
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

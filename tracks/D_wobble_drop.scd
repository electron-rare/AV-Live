// =====================================================================
//  D_wobble_drop.scd
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
//  PREREQUIS : engine.scd evalue (les SynthDef + helpers doivent exister).
// =====================================================================

// --- TRACK D : "WOBBLE DROP" -- 7 minutes dubstep --------------------
//   140 BPM half-time : kick 1+9, snare 5+13, hat 16ths, fmBell wobble
//   intro / drop1 / break / drop2 / outro
(
[~track1, ~track2, ~track3, ~track4].do { |t| t !? { t.stop } };
[~chaosRoutine, ~breathRoutine, ~rythmRoutine, ~accelRoutine,
 ~filterSweep, ~introRoutine, ~outroRoutine].do { |r| r !? { r.stop } };
~track !? { ~track.stop };
~track = Routine({
    "[D 0:00] === WOBBLE DROP -- 7 minutes 140 BPM ===".postln;
    [\acidSeq, \kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    TempoClock.default.tempo = 140 / 60;

    // ------ 0:00 INTRO -- pad atmospherique seul ------
    "[D 0:00] intro pad sombre...".postln;
    ~melodyInst = \pad;
    ~melodyAttack = 0.5; ~melodyRelease = 2.0; ~melodyCutoff = 1200;
    ~melodyAmp = 0.18;
    ~melodyNotes = [60, 0, 0, 0, 0, 0, 0, 0, 63, 0, 0, 0, 0, 0, 0, 0,
                    65, 0, 0, 0, 0, 0, 0, 0, 60, 0, 0, 0, 0, 0, 0, 0];
    ~kickSteps = (0 ! 16); ~snareSteps = (0 ! 16);
    ~hatSteps = (0 ! 16); ~acidAmp = 0;
    ~reload.value;
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).play };
    ~enableHarmony.(\dubBass);
    30.wait;

    // ------ 0:30 DRUM ENTRY -- kick + snare half-time ------
    "[D 0:30] drum entry half-time...".postln;
    ~kickSteps  = [1,0,0,0, 0,0,0,0, 1,0,0,0, 0,0,0,0];
    ~kickFreq = 48; ~kickPitchAmt = 3.5; ~kickDecay = 0.5;
    ~kickDrive = 1.5; ~kickClick = 0.15; ~kickAmp = 0.6;
    ~snareSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0];
    ~snareAmp = 0.45; ~snareFreq = 220; ~snareNoiseAmt = 0.65; ~snareDecay = 0.16;
    ~reload.value;
    30.wait;

    // ------ 1:00 BUILD -- hat 16ths + riser ------
    "[D 1:00] build avec hat 16ths + riser...".postln;
    ~hatSteps = [1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1]; ~hatAmp = 0.10;
    ~reload.value;
    Synth(\riser, [\dur, 12, \startCutoff, 200, \endCutoff, 8000, \amp, 0.25]);
    12.wait;

    // ------ 1:12 IMPACT + DROP 1 ------
    "[D 1:12] === IMPACT + DROP 1 wobble dubstep ===".postln;
    Synth(\impact, [\freq, 45, \decay, 1.8, \amp, 0.7]);
    0.1.wait;
    ~melodyInst = \fmBell;
    ~melodyAttack = 0.005; ~melodyRelease = 0.4;
    ~melodyCutoff = 350; ~melodyDrive = 4.0;
    ~melodyWobbleRate = 4; ~melodyWobbleDepth = 2200;
    ~melodyWobbleShape = 0; ~melodySubAmt = 0.95;
    ~melodyAmp = 0.20; ~melodyBoost = 1.8;
    ~melodyNotes = [36, 0, 0, 0, 36, 0, 0, 0,
                    39, 0, 0, 0, 39, 0, 0, 0,
                    36, 0, 0, 0, 36, 0, 0, 0,
                    41, 0, 0, 0, 39, 0, 0, 0];
    ~hatAmp = 0.08;
    ~reload.value;
    18.do { |k|
        if (0.3.coin) {
            ~melodyWobbleRate = [2, 4, 4, 8].choose;
            ~melodyWobbleShape = [0, 0, 1].choose;
            ~melodyWobbleDepth = rrand(1500, 2800);
            ~reload.value;
            ("  -> wobble " ++ ~melodyWobbleRate ++ "Hz shape" ++ ~melodyWobbleShape).postln;
        };
        if (0.2.coin) {
            ~melodyNotes = ~mutate.(~melodyNotes, 0.15,
                [24, 36, 36, 39, 41, 43, 48]);
            ~reload.value;
        };
        5.wait;
    };
    // 2:42

    // ------ 2:42 MID BREAKDOWN ------
    "[D 2:42] mid breakdown -- pad seul...".postln;
    ~kickSteps = (0 ! 16); ~snareSteps = (0 ! 16);
    ~hatSteps = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~hatAmp = 0.06;
    ~melodyInst = \pad;
    ~melodyAttack = 0.6; ~melodyRelease = 2.0; ~melodyCutoff = 1500;
    ~melodyAmp = 0.16;
    ~melodyNotes = [60, 0, 0, 0, 63, 0, 0, 0, 65, 0, 0, 0, 67, 0, 0, 0,
                    65, 0, 0, 0, 63, 0, 0, 0, 60, 0, 0, 0, 0, 0, 0, 0];
    ~reload.value;
    30.wait;

    // ------ 3:12 BUILD 2 -- snare roll + riser ------
    "[D 3:12] build 2 avec snare roll...".postln;
    Synth(\riser, [\dur, 16, \startCutoff, 400, \endCutoff, 9000, \amp, 0.3]);
    16.do { |k|
        var rate = (k / 4).floor + 2;
        if (k.mod((16 / rate).round.max(1)) == 0) {
            Synth(\snare, [\amp, 0.35 + (k * 0.012), \decay, 0.06]);
        };
        ~hatAmp = 0.06 + (k * 0.005);
        ~reload.value;
        1.wait;
    };
    // 3:28

    // ------ 3:28 IMPACT + DROP 2 -- wobble CHOP ------
    "[D 3:28] === IMPACT + DROP 2 wobble chop ===".postln;
    Synth(\impact, [\freq, 40, \decay, 2.0, \amp, 0.75]);
    0.1.wait;
    ~kickSteps = [1,0,0,0, 0,0,0,0, 1,0,0,0, 0,0,0,0];
    ~snareSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0];
    ~hatSteps = [1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1]; ~hatAmp = 0.10;
    ~melodyInst = \fmBell;
    ~melodyAttack = 0.005; ~melodyRelease = 0.3;
    ~melodyCutoff = 300; ~melodyDrive = 4.5;
    ~melodyWobbleRate = 8; ~melodyWobbleDepth = 2800;
    ~melodyWobbleShape = 1;          // CHOP square wobble
    ~melodySubAmt = 1.0;
    ~melodyAmp = 0.22;
    ~melodyNotes = [36, 0, 39, 0, 36, 0, 0, 41,
                    36, 0, 39, 41, 0, 0, 36, 0,
                    36, 0, 39, 0, 36, 0, 43, 41,
                    39, 0, 0, 36, 0, 41, 39, 0];
    ~reload.value;
    20.do { |k|
        if (0.4.coin) {
            ~melodyWobbleRate = [4, 8, 8, 16].choose;
            ~melodyWobbleShape = [0, 1, 1].choose;
            ~melodyWobbleDepth = rrand(1500, 3200);
            ~reload.value;
        };
        if (0.25.coin) {
            ~melodyNotes = ~mutate.(~melodyNotes, 0.2, [24, 36, 39, 41, 43, 48]);
            ~reload.value;
        };
        if (0.1.coin) {
            ~snareSteps = [0,0,0,0, 1,0,0,1, 0,0,0,0, 1,0,1,0];
            ~reload.value;
        };
        5.wait;
    };
    // 5:08

    // ------ 5:08 OUTRO -- fade out ------
    "[D 5:08] new -- DROP 3 ringMod + reeseHard fx industrial...".postln;
    ~melodyInst = \reeseHard;
    ~melodyAttack = 0.005; ~melodyRelease = 0.3; ~melodyCutoff = 280;
    ~melodyDrive = 4.5; ~melodyAmp = 0.20;
    ~melodyNotes = [36, 0, 0, 0, 39, 0, 0, 0,
                    36, 0, 41, 0, 39, 0, 36, 0,
                    36, 0, 0, 0, 41, 0, 43, 0,
                    39, 0, 36, 0, 41, 0, 39, 0];
    ~ringMod !? { ~ringMod.(220, 3) };
    ~vcfOn !? { ~vcfOn.(\ladder, 800, 0.55) };
    ~fxPreset !? { ~fxPreset.(\industrial) };
    TempoClock.default.tempo = ~bpm/60; ~reload.value;
    35.wait;

    "[D 5:43] new -- vocalPad breakdown + mepic1 cinematic...".postln;
    ~melodyInst = \vocalPad;
    ~melodyAttack = 0.4; ~melodyRelease = 1.8; ~melodyCutoff = 2200;
    ~melodyAmp = 0.18;
    ~vcfOff !? { ~vcfOff.() };
    ~melodyNotes = (~mepic1 ? [60,0,63,0,67,0,70,0, 72,0,70,67,63,0,60,0]).copy;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.2, 1000, \sin, 2200) };
    ~fxPreset !? { ~fxPreset.(\dream) };
    TempoClock.default.tempo = ~bpm/60; ~reload.value;
    25.wait;
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };

    "[D 6:08] outro fade...".postln;
    ~melodyInst = \pad;
    ~melodyAttack = 0.6; ~melodyRelease = 2.5; ~melodyCutoff = 800;
    ~reload.value;
    60.do { |k|
        var x = 1 - ((k + 1) / 60);
        ~kickAmp = x * 0.6;
        ~snareAmp = x * 0.45;
        ~hatAmp = x * 0.10;
        ~melodyAmp = x * 0.18;
        ~melodyCutoff = 200 + (x * 600);
        ~reload.value;
        2.wait;
    };
    // 7:08

    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    "[D 8:08] === fin WOBBLE DROP ===".postln;
}).play;
"=== TRACK D : WOBBLE DROP 7 min lancee ===".postln;
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

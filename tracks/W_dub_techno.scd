// =====================================================================
//  W_dub_techno.scd  -- 10 min, 120 BPM, dub techno (Plastikman style)
//  sub + chord stabs warmPad avec long releases + minimal kick
//  PREREQUIS : engine + extra
// =====================================================================
(
[~track1, ~track2, ~track3, ~track4].do { |t| t !? { t.stop } };
~track !? { ~track.stop };
~track = Routine({
    "[W 0:00] === DUB TECHNO 120 BPM ===".postln;
    [\acidSeq, \kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \melodySeq, \harmonySeq]
        .do { |k| Pdef(k).stop };
    TempoClock.default.tempo = 120 / 60;

    "[W 0:00] intro drone...".postln;
    ~melodyInst = \drone;
    ~melodyAttack = 1.5; ~melodyRelease = 3.0; ~melodyCutoff = 1200;
    ~melodyAmp = 0.18;
    ~melodyNotes = [36,0,0,0,0,0,0,0, 0,0,0,0,39,0,0,0,
                    36,0,0,0,0,0,0,0, 0,0,0,0,41,0,0,0];
    ~kickSteps=(0!16); ~hatSteps=(0!16); ~snareSteps=(0!16);
    ~clapSteps=(0!16); ~percSteps=(0!16); ~acidAmp=0;
    ~reload.value;
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq]
        .do { |k| Pdef(k).play };
    ~enableHarmony.(\dubBass);
    45.wait;

    "[W 0:45] kick minimal 4/4 + hat tres discret...".postln;
    ~kickSteps  = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.5;
    ~kickFreq = 48; ~kickPitchAmt = 2.5; ~kickDecay = 0.45; ~kickClick = 0.08;
    ~hatSteps = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~hatAmp = 0.06;
    ~reload.value;
    45.wait;

    "[W 1:30] chord stabs warmPad avec long release...".postln;
    ~melodyInst = \warmPad;
    ~melodyAttack = 0.05; ~melodyRelease = 1.8; ~melodyCutoff = 2000;
    ~melodyAmp = 0.18;
    ~melodyNotes = [60,0,0,0,0,0,0,0, 0,0,0,0,67,0,0,0,
                    63,0,0,0,0,0,0,0, 0,0,0,0,70,0,0,0];
    ~reload.value;
    90.wait;

    "[W 3:00] sub bass profond...".postln;
    Synth(\gong, [\freq, 50, \decay, 5, \amp, 0.4]);
    ~melodyInst = \subBoom;
    ~melodyAttack = 0.005; ~melodyRelease = 0.7; ~melodyAmp = 0.30;
    ~melodyNotes = [36,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,
                    39,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0];
    ~reload.value;
    90.wait;

    "[W 4:30] section accord stabs evolutifs...".postln;
    ~melodyInst = \warmPad;
    ~melodyAttack = 0.05; ~melodyRelease = 2.0; ~melodyCutoff = 1800;
    ~melodyAmp = 0.20;
    ~melodyNotes = [60,0,0,67, 0,0,70,0, 0,0,72,0, 67,0,0,0,
                    63,0,0,70, 0,0,72,0, 0,0,75,0, 70,0,0,0];
    ~reload.value;
    100.wait;

    "[W 6:10] cutoff sweep tres lent (caracteristique dub)...".postln;
    60.do { |k|
        var x = (k + 1) / 60;
        ~melodyCutoff = 1800 + ((x * 2 * pi).sin.abs * 1500);
        ~reload.value; 1.wait;
    };
    // 7:10

    "[W 7:10] retour drone + gong...".postln;
    Synth(\gong, [\freq, 45, \decay, 8, \amp, 0.5]);
    ~melodyInst = \drone;
    ~melodyAttack = 1.0; ~melodyRelease = 2.5; ~melodyCutoff = 1500;
    ~melodyAmp = 0.20;
    ~melodyNotes = [36,0,0,0,0,0,0,0, 0,0,0,0,39,0,0,0,
                    36,0,0,0,0,0,0,0, 0,0,0,0,41,0,0,0];
    ~reload.value;
    90.wait;
    "[W 8:40] new -- rhodes dub + ml5 + heavy delay + freeze...".postln;
    ~melodyInst = \rhodes;
    ~melodyAttack = 0.01; ~melodyRelease = 1.0; ~melodyCutoff = 2500;
    ~melodyAmp = 0.18;
    ~melodyNotes = (~ml5 ? [60,0,0,0,67,0,0,0, 70,0,0,0,72,0,0,0]).copy;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.1, 800, \sin, 2200) };
    ~vcfOn !? { ~vcfOn.(\moog, 1800, 0.4) };
    ~setFx !? { ~setFx.(\dly, \mix, 0.6) };
    ~fxPreset !? { ~fxPreset.(\dub) };
    TempoClock.default.tempo = ~bpm/60; ~reload.value;
    50.wait;

    "[W 9:30] new -- vocalPad dub techno + reverb freeze...".postln;
    ~melodyInst = \vocalPad;
    ~melodyAttack = 0.6; ~melodyRelease = 2.0; ~melodyCutoff = 2000;
    ~melodyAmp = 0.20;
    ~vcfOff !? { ~vcfOff.() };
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~freeze !? { ~freeze.(6) };
    ~reverbTail !? { ~reverbTail.(5) };
    ~fxPreset !? { ~fxPreset.(\dub) };
    TempoClock.default.tempo = ~bpm/60; ~reload.value;
    40.wait;


    "[W 10:10] outro long fade tres dub...".postln;
    Synth(\gong, [\freq, 35, \decay, 12, \amp, 0.6]);
    ~hatAmp = 0.04;
    80.do { |k|
        var x = 1 - ((k + 1) / 80);
        ~kickAmp = x * 0.5; ~hatAmp = x * 0.04;
        ~melodyAmp = x * 0.20; ~melodyCutoff = 200 + (x * 1300);
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq]
        .do { |k| Pdef(k).stop };
    "[W 11:30] === fin DUB TECHNO ===".postln;
}).play;
"=== TRACK W : DUB TECHNO 10 min lancee ===".postln;
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

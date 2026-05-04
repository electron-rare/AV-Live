// =====================================================================
//  L_future_garage.scd  -- 7 min, 130 BPM, future garage / 2-step
//  warmPad atmospheric + subBoom + skippy hats + clap garage
//  PREREQUIS : engine + extra
// =====================================================================
(
[~track1, ~track2, ~track3, ~track4].do { |t| t !? { t.stop } };
~track !? { ~track.stop };
~track = Routine({
    "[L 0:00] === FUTURE GARAGE 130 BPM ===".postln;
    [\acidSeq, \kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \melodySeq, \harmonySeq]
        .do { |k| Pdef(k).stop };
    TempoClock.default.tempo = 130 / 60;

    "[L 0:00] intro warmPad atmospherique...".postln;
    ~melodyInst = \warmPad;
    ~melodyAttack = 0.7; ~melodyRelease = 2.0; ~melodyCutoff = 1500;
    ~melodyAmp = 0.18;
    ~melodyNotes = [60,0,0,0,67,0,0,0, 70,0,0,0,72,0,0,0,
                    72,0,0,0,70,0,0,0, 67,0,0,0,63,0,0,0];
    ~kickSteps=(0!16); ~hatSteps=(0!16); ~snareSteps=(0!16);
    ~clapSteps=(0!16); ~percSteps=(0!16); ~acidAmp=0;
    ~reload.value;
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq]
        .do { |k| Pdef(k).play };
    ~enableHarmony.(\dubBass);
    25.wait;

    "[L 0:25] beat 2-step + clap...".postln;
    ~kickSteps  = [1,0,0,0, 0,0,1,0, 0,0,0,0, 1,0,0,0]; ~kickAmp = 0.5;
    ~kickFreq = 48; ~kickPitchAmt = 2.5; ~kickDecay = 0.5; ~kickClick = 0.1;
    ~hatSteps = [0,1,1,0, 1,1,0,1, 0,1,1,0, 1,1,0,1]; ~hatAmp = 0.10;
    ~clapSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,1]; ~clapAmp = 0.32;
    ~snareSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,1,0,0]; ~snareAmp = 0.3;
    ~snareFreq = 220; ~snareNoiseAmt = 0.7;
    ~reload.value;
    35.wait;

    "[L 1:00] subBoom 808 entre...".postln;
    ~melodyInst = \subBoom;
    ~melodyAttack = 0.005; ~melodyRelease = 0.5; ~melodyAmp = 0.32;
    ~melodyNotes = [36,0,0,0, 36,0,0,0, 0,0,41,0, 39,0,0,0,
                    36,0,0,0, 38,0,0,0, 0,0,41,0, 39,0,0,0];
    ~reload.value;
    60.wait;

    "[L 2:00] section : warmPad lead par-dessus...".postln;
    ~melodyInst = \warmPad;
    ~melodyAttack = 0.3; ~melodyRelease = 1.2; ~melodyCutoff = 2200;
    ~melodyAmp = 0.18;
    ~melodyNotes = [60,0,0,67, 0,70,0,72, 70,0,67,0, 63,0,0,60,
                    65,0,0,72, 0,75,0,77, 75,0,72,0, 67,0,0,60];
    ~reload.value;
    80.wait;

    "[L 3:20] breakdown reverb-like...".postln;
    ~kickSteps = [1,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0]; ~kickAmp = 0.4;
    ~hatAmp = 0.05; ~clapAmp = 0;
    ~melodyInst = \choir;
    ~melodyAttack = 0.5; ~melodyRelease = 1.5; ~melodyCutoff = 2500;
    ~melodyAmp = 0.20;
    ~reload.value;
    40.wait;

    "[L 4:00] retour beat + sub massif...".postln;
    Synth(\impact, [\freq, 35, \decay, 2.5, \amp, 0.55]);
    ~kickSteps  = [1,0,0,0, 0,0,1,0, 0,0,0,0, 1,0,0,0]; ~kickAmp = 0.5;
    ~hatSteps = [0,1,1,0, 1,1,0,1, 0,1,1,0, 1,1,0,1]; ~hatAmp = 0.12;
    ~clapSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,1]; ~clapAmp = 0.35;
    ~melodyInst = \subBoom;
    ~melodyAttack = 0.005; ~melodyRelease = 0.6; ~melodyAmp = 0.36;
    ~melodyNotes = [36,0,0,0, 36,0,0,0, 0,0,41,0, 39,0,0,0,
                    36,0,0,0, 38,0,0,0, 0,0,41,0, 36,0,0,0];
    ~reload.value;
    100.wait;
    "[L 5:40] new -- handpan future garage + ml5 + lfo + reverb...".postln;
    ~melodyInst = \handpan;
    ~melodyAttack = 0.001; ~melodyRelease = 1.5; ~melodyCutoff = 4500;
    ~melodyAmp = 0.22;
    ~melodyNotes = (~ml5 ? [60,0,67,0,72,0,67,0, 65,0,70,0,75,0,70,0]).copy;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.3, 1500, \sin, 3500) };
    ~vcfOn !? { ~vcfOn.(\bpf, 1500, 0.6) };
    ~fxPreset !? { ~fxPreset.(\dream) };
    TempoClock.default.tempo = ~bpm/60; ~reload.value;
    40.wait;

    "[L 6:20] new -- vocalPad + glitch garage + tapeStop...".postln;
    ~melodyInst = \vocalPad;
    ~melodyAttack = 0.4; ~melodyRelease = 1.6; ~melodyCutoff = 2500;
    ~melodyAmp = 0.20;
    ~vcfOff !? { ~vcfOff.() };
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~glitch !? { ~glitch.(1.5) };
    ~tapeStop !? { ~tapeStop.(2) };
    ~fxPreset !? { ~fxPreset.(\space) };
    TempoClock.default.tempo = ~bpm/60; ~reload.value;
    20.wait;


    "[L 6:40] outro pad fade...".postln;
    ~melodyInst = \warmPad;
    ~melodyAttack = 0.7; ~melodyRelease = 2.0; ~melodyCutoff = 1200;
    ~melodyAmp = 0.18;
    ~reload.value;
    60.do { |k|
        var x = 1 - ((k + 1) / 60);
        ~kickAmp = x * 0.5; ~hatAmp = x * 0.12; ~clapAmp = x * 0.35;
        ~melodyAmp = x * 0.18;
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq]
        .do { |k| Pdef(k).stop };
    "[L 7:40] === fin FUTURE GARAGE ===".postln;
}).play;
"=== TRACK L : FUTURE GARAGE 7 min lancee ===".postln;
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

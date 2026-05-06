// =====================================================================
//  L05_submerged_bass.scd  --  Album L "SUBMERGED BASS", track 05/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK L05 : "SUBMERGED BASS" 8 minutes ----------------------
//   0:00 intro -> 1:36 build -> 3:36 drop -> 5:36 variation -> 7:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[L05 0:00] intro -- subBoom solo + perc hat...".postln;
    ~bpm = 130;
    ~kickAmp = 0.55; ~hatAmp = 0.06; ~melodyAmp = 0.19;
    ~kickFreq = 57; ~kickPitchAmt = 3.0; ~kickDecay = 0.31;
    ~kickDrive = 1.2; ~kickClick = 0.16;
    ~melodyInst = \subBoom;
    ~melodyAttack = 0.05; ~melodyRelease = 0.8; ~melodyCutoff = 2760;
    ~melodyNotes = [0,0,0,60,0,0,0,60,60,77,65,70,0,74,0,0,0,0,67,0,0,77,0,0,0,60,0,0,0,0,0,69];
    ~kickSteps = [0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,1];
    ~hatSteps = [0,0,1,0,0,1,0,1,0,0,0,0,1,0,0,1];
    ~percInst = \hat;
    ~percSteps = [0,0,0,0,1,0,0,0,0,1,0,0,0,0,1,0]; ~percAmp = 0.32;
    ~snareSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~clapSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~acidAmp = 0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\dub) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\bassline);
    96.wait;

    "[L05 1:36] build -- kick + hat + melody plus dense...".postln;
    ~bpm = 126; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0];
    ~hatSteps = [0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0]; ~hatAmp = 0.10;
    ~melodyNotes = [65,72,0,0,69,69,0,72,62,0,65,0,70,0,77,65,60,60,0,69,74,65,0,0,67,77,0,72,0,0,0,0];
    ~melodyCutoff = 3260;
    ~percSteps = [0,0,1,1,1,1,0,1,0,1,0,1,1,1,1,1]; ~percAmp = 0.36;
    ~reload.value;
    24.do { |k|
        if (0.20.coin) { ~melodyNotes = ~mutate.(~melodyNotes, 0.2); ~reload.value };
        if (0.15.coin) { ~melodyCutoff = rrand(1061, 3760); ~reload.value };
        if (0.10.coin) { ~melodyNotes = ~octavate.(~melodyNotes, 0.2); ~reload.value };
        5.wait;
    };

    "[L05 3:36] drop -- variation + ensemble dense...".postln;
    ~bpm = 130; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,0,0,1,0,0,0,0,0,1,0,1,0]; ~kickAmp = 0.6;
    ~clapSteps = [0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0]; ~clapAmp = 0.32;
    ~melodyNotes = [72,0,75,82,87,0,0,0,72,82,87,0,0,0,70,0,0,0,0,0,84,84,0,0,0,0,0,0,0,82,0,75];
    ~melodyAmp = 0.21;
    ~reload.value;
    20.do { |k|
        if (0.25.coin) {
            ~melodyNotes = ~genMelody.(0.5, ~scaleDorian);
            ~reload.value;
        };
        if (0.20.coin) { ~melodyNotes = ~transpose.(~melodyNotes, [-5, -3, 3, 5, 7].choose); ~reload.value };
        if (0.15.coin) { ~percSteps = [0,0,1,1,1,1,0,1,0,1,0,1,1,1,1,1].scramble; ~reload.value };
        6.wait;
    };

    "[L05 5:36] variation -- timbre nouveau + fx evolve...".postln;
    ~bpm = 128; TempoClock.default.tempo = ~bpm/60;
    ~melodyInst = \subBoom;
    ~melodyAttack = 0.01; ~melodyRelease = 0.5; ~melodyCutoff = 3560;
    ~melodyNotes = [0,0,0,52,0,35,0,45,0,42,35,0,0,49,40,0,49,0,0,0,44,0,0,0,0,52,0,35,49,0,49,0];
    ~melodyAmp = 0.19;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.21, 1061, \sin, 2760) };
    ~vcfOn !? { ~vcfOn.(\moog, 1261, 0.4) };
    ~fxPreset !? { ~fxPreset.(\dub) };
    ~reload.value;
    114.wait;

    "[L05 7:30] outro -- fade global...".postln;
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~vcfOff !? { ~vcfOff.() };
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~melodyAmp = x * 0.19; ~kickAmp = x * 0.55;
        ~hatAmp = x * 0.10; ~percAmp = x * 0.32; ~clapAmp = x * 0.32;
        ~melodyCutoff = 250 + (x * 2760);
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[L05 8:00] === fin SUBMERGED BASS ===".postln;
}).play;
"=== TRACK L05 : SUBMERGED BASS 8 min lancee ===".postln;
)

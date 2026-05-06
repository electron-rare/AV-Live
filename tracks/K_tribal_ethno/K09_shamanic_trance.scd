// =====================================================================
//  K09_shamanic_trance.scd  --  Album K "SHAMANIC TRANCE", track 09/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK K09 : "SHAMANIC TRANCE" 7 minutes ----------------------
//   0:00 intro -> 1:24 build -> 3:09 drop -> 4:54 variation -> 6:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[K09 0:00] intro -- drone solo + perc taiko...".postln;
    ~bpm = 112;
    ~kickAmp = 0.53; ~hatAmp = 0.06; ~melodyAmp = 0.19;
    ~kickFreq = 62; ~kickPitchAmt = 2.1; ~kickDecay = 0.5;
    ~kickDrive = 1.2; ~kickClick = 0.25;
    ~melodyInst = \drone;
    ~melodyAttack = 0.05; ~melodyRelease = 0.8; ~melodyCutoff = 3650;
    ~melodyNotes = [0,0,0,65,0,60,65,0,57,0,0,0,0,69,0,0,0,0,55,0,0,0,0,0,65,0,0,0,64,55,0,0];
    ~kickSteps = [0,1,1,0,0,0,1,1,0,0,0,0,1,0,0,0];
    ~hatSteps = [0,0,1,0,0,1,1,1,1,1,1,1,0,0,0,0];
    ~percInst = \taiko;
    ~percSteps = [0,0,0,1,1,0,0,0,0,0,0,0,0,0,1,0]; ~percAmp = 0.32;
    ~snareSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~clapSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~acidAmp = 0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\cosmic) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\cinematic);
    84.wait;

    "[K09 1:24] build -- kick + hat + melody plus dense...".postln;
    ~bpm = 110; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0];
    ~hatSteps = [0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0]; ~hatAmp = 0.10;
    ~melodyNotes = [64,65,65,69,57,0,0,64,0,64,0,55,0,0,62,0,0,0,65,64,55,60,0,0,0,57,55,0,55,0,67,72];
    ~melodyCutoff = 4150;
    ~percSteps = [0,1,1,1,1,0,0,0,0,1,1,0,1,0,1,0]; ~percAmp = 0.36;
    ~reload.value;
    21.do { |k|
        if (0.20.coin) { ~melodyNotes = ~mutate.(~melodyNotes, 0.2); ~reload.value };
        if (0.15.coin) { ~melodyCutoff = rrand(1372, 4650); ~reload.value };
        if (0.10.coin) { ~melodyNotes = ~octavate.(~melodyNotes, 0.2); ~reload.value };
        5.wait;
    };

    "[K09 3:09] drop -- variation + ensemble dense...".postln;
    ~bpm = 116; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,0,0,1,0,0,0,0,0,1,0,1,0]; ~kickAmp = 0.58;
    ~clapSteps = [0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0]; ~clapAmp = 0.32;
    ~melodyNotes = [0,0,76,0,69,83,86,86,0,79,76,0,0,0,86,71,74,0,86,0,76,0,0,71,76,0,69,0,83,79,0,0];
    ~melodyAmp = 0.21;
    ~reload.value;
    17.do { |k|
        if (0.25.coin) {
            ~melodyNotes = ~genMelody.(0.5, ~scaleHarmonicMin);
            ~reload.value;
        };
        if (0.20.coin) { ~melodyNotes = ~transpose.(~melodyNotes, [-5, -3, 3, 5, 7].choose); ~reload.value };
        if (0.15.coin) { ~percSteps = [0,1,1,1,1,0,0,0,0,1,1,0,1,0,1,0].scramble; ~reload.value };
        6.wait;
    };

    "[K09 4:54] variation -- timbre nouveau + fx evolve...".postln;
    ~bpm = 108; TempoClock.default.tempo = ~bpm/60;
    ~melodyInst = \drone;
    ~melodyAttack = 0.01; ~melodyRelease = 0.5; ~melodyCutoff = 4450;
    ~melodyNotes = [0,38,41,0,0,0,0,40,0,0,45,48,38,48,0,43,0,0,31,0,0,0,0,43,0,0,40,40,0,38,43,0];
    ~melodyAmp = 0.19;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.28, 1372, \sin, 3650) };
    ~vcfOn !? { ~vcfOn.(\moog, 1572, 0.4) };
    ~fxPreset !? { ~fxPreset.(\cosmic) };
    ~reload.value;
    96.wait;

    "[K09 6:30] outro -- fade global...".postln;
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~vcfOff !? { ~vcfOff.() };
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~melodyAmp = x * 0.19; ~kickAmp = x * 0.53;
        ~hatAmp = x * 0.10; ~percAmp = x * 0.32; ~clapAmp = x * 0.32;
        ~melodyCutoff = 250 + (x * 3650);
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[K09 7:00] === fin SHAMANIC TRANCE ===".postln;
}).play;
"=== TRACK K09 : SHAMANIC TRANCE 7 min lancee ===".postln;
)

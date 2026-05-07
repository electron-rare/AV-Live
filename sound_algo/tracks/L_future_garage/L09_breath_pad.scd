// =====================================================================
//  L09_breath_pad.scd  --  Album L "BREATH PAD", track 09/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK L09 : "BREATH PAD" 7 minutes ----------------------
//   0:00 intro -> 1:24 build -> 3:09 drop -> 4:54 variation -> 6:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[L09 0:00] intro -- warmPad solo + perc hat...".postln;
    ~bpm = 130;
    ~kickAmp = 0.46; ~hatAmp = 0.06; ~melodyAmp = 0.22;
    ~kickFreq = 44; ~kickPitchAmt = 2.8; ~kickDecay = 0.46;
    ~kickDrive = 1.2; ~kickClick = 0.3;
    ~melodyInst = \warmPad;
    ~melodyAttack = 0.05; ~melodyRelease = 0.8; ~melodyCutoff = 3270;
    ~melodyNotes = [62,0,57,69,64,0,0,0,57,0,0,0,0,71,0,0,0,0,71,0,0,0,59,0,0,0,74,0,0,0,0,69];
    ~kickSteps = [0,0,0,0,0,1,0,1,0,0,0,0,1,0,0,0];
    ~hatSteps = [0,1,0,1,1,1,1,0,0,0,1,1,0,0,0,0];
    ~percInst = \hat;
    ~percSteps = [0,0,1,0,0,1,1,1,0,1,1,1,0,0,0,1]; ~percAmp = 0.32;
    ~snareSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~clapSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~acidAmp = 0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\dream) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\fifth);
    84.wait;

    "[L09 1:24] build -- kick + hat + melody plus dense...".postln;
    ~bpm = 132; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0];
    ~hatSteps = [0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0]; ~hatAmp = 0.10;
    ~melodyNotes = [57,0,74,74,0,66,0,0,0,66,0,59,69,0,57,0,62,69,0,0,69,59,0,0,69,64,0,59,0,0,0,64];
    ~melodyCutoff = 3770;
    ~percSteps = [1,1,1,0,1,0,1,0,1,0,1,1,0,1,0,1]; ~percAmp = 0.36;
    ~reload.value;
    21.do { |k|
        if (0.20.coin) { ~melodyNotes = ~mutate.(~melodyNotes, 0.2); ~reload.value };
        if (0.15.coin) { ~melodyCutoff = rrand(1348, 4270); ~reload.value };
        if (0.10.coin) { ~melodyNotes = ~octavate.(~melodyNotes, 0.2); ~reload.value };
        5.wait;
    };

    "[L09 3:09] drop -- variation + ensemble dense...".postln;
    ~bpm = 126; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,0,0,1,0,0,0,0,0,1,0,1,0]; ~kickAmp = 0.51;
    ~clapSteps = [0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0]; ~clapAmp = 0.32;
    ~melodyNotes = [75,0,75,72,0,79,84,84,82,0,0,0,0,77,0,84,0,0,0,84,84,0,70,72,79,79,0,0,0,0,0,0];
    ~melodyAmp = 0.24;
    ~reload.value;
    17.do { |k|
        if (0.25.coin) {
            ~melodyNotes = ~genMelody.(0.5, ~scaleMinor);
            ~reload.value;
        };
        if (0.20.coin) { ~melodyNotes = ~transpose.(~melodyNotes, [-5, -3, 3, 5, 7].choose); ~reload.value };
        if (0.15.coin) { ~percSteps = [1,1,1,0,1,0,1,0,1,0,1,1,0,1,0,1].scramble; ~reload.value };
        6.wait;
    };

    "[L09 4:54] variation -- timbre nouveau + fx evolve...".postln;
    ~bpm = 134; TempoClock.default.tempo = ~bpm/60;
    ~melodyInst = \warmPad;
    ~melodyAttack = 0.01; ~melodyRelease = 0.5; ~melodyCutoff = 4070;
    ~melodyNotes = [0,0,0,0,0,0,45,0,0,50,38,0,0,0,48,43,45,0,46,43,0,0,41,0,0,43,36,0,0,0,48,0];
    ~melodyAmp = 0.22;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.3, 1348, \sin, 3270) };
    ~vcfOn !? { ~vcfOn.(\moog, 1548, 0.4) };
    ~fxPreset !? { ~fxPreset.(\dream) };
    ~reload.value;
    96.wait;

    "[L09 6:30] outro -- fade global...".postln;
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~vcfOff !? { ~vcfOff.() };
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~melodyAmp = x * 0.22; ~kickAmp = x * 0.46;
        ~hatAmp = x * 0.10; ~percAmp = x * 0.32; ~clapAmp = x * 0.32;
        ~melodyCutoff = 250 + (x * 3270);
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[L09 7:00] === fin BREATH PAD ===".postln;
}).play;
"=== TRACK L09 : BREATH PAD 7 min lancee ===".postln;
)

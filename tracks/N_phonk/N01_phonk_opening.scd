// =====================================================================
//  N01_phonk_opening.scd  --  Album N "PHONK OPENING", track 01/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK N01 : "PHONK OPENING" 4 minutes ----------------------
//   0:00 intro -> 0:48 build -> 1:48 drop -> 2:48 variation -> 3:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[N01 0:00] intro -- warmPad solo + perc cowbell...".postln;
    ~bpm = 130;
    ~kickAmp = 0.54; ~hatAmp = 0.06; ~melodyAmp = 0.23;
    ~kickFreq = 61; ~kickPitchAmt = 2.4; ~kickDecay = 0.34;
    ~kickDrive = 1.2; ~kickClick = 0.17;
    ~melodyInst = \warmPad;
    ~melodyAttack = 0.05; ~melodyRelease = 0.8; ~melodyCutoff = 2870;
    ~melodyNotes = [0,72,70,0,0,0,72,70,62,0,0,0,67,67,0,0,70,0,65,0,0,62,0,62,0,77,0,0,60,0,72,60];
    ~kickSteps = [0,1,0,0,0,0,0,0,0,0,0,0,1,1,1,0];
    ~hatSteps = [1,1,0,0,0,0,0,1,1,0,0,0,0,0,1,0];
    ~percInst = \cowbell;
    ~percSteps = [1,0,0,0,0,0,0,0,1,0,0,1,1,1,0,0]; ~percAmp = 0.32;
    ~snareSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~clapSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~acidAmp = 0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\industrial) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\bassline);
    48.wait;

    "[N01 0:48] build -- kick + hat + melody plus dense...".postln;
    ~bpm = 128; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0];
    ~hatSteps = [0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0]; ~hatAmp = 0.10;
    ~melodyNotes = [72,0,62,69,74,0,62,67,0,0,62,60,0,67,0,60,60,72,0,69,70,0,0,0,0,60,0,0,0,0,72,72];
    ~melodyCutoff = 3370;
    ~percSteps = [0,1,0,1,0,0,0,0,0,1,1,1,1,1,0,1]; ~percAmp = 0.36;
    ~reload.value;
    12.do { |k|
        if (0.20.coin) { ~melodyNotes = ~mutate.(~melodyNotes, 0.2); ~reload.value };
        if (0.15.coin) { ~melodyCutoff = rrand(970, 3870); ~reload.value };
        if (0.10.coin) { ~melodyNotes = ~octavate.(~melodyNotes, 0.2); ~reload.value };
        5.wait;
    };

    "[N01 1:48] drop -- variation + ensemble dense...".postln;
    ~bpm = 134; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,0,0,1,0,0,0,0,0,1,0,1,0]; ~kickAmp = 0.59;
    ~clapSteps = [0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0]; ~clapAmp = 0.32;
    ~melodyNotes = [79,81,0,79,84,0,84,84,76,0,0,77,79,81,84,0,67,0,0,0,79,77,69,0,0,0,0,0,69,84,72,0];
    ~melodyAmp = 0.25;
    ~reload.value;
    10.do { |k|
        if (0.25.coin) {
            ~melodyNotes = ~genMelody.(0.5, ~scalePhrygian);
            ~reload.value;
        };
        if (0.20.coin) { ~melodyNotes = ~transpose.(~melodyNotes, [-5, -3, 3, 5, 7].choose); ~reload.value };
        if (0.15.coin) { ~percSteps = [0,1,0,1,0,0,0,0,0,1,1,1,1,1,0,1].scramble; ~reload.value };
        6.wait;
    };

    "[N01 2:48] variation -- timbre nouveau + fx evolve...".postln;
    ~bpm = 130; TempoClock.default.tempo = ~bpm/60;
    ~melodyInst = \warmPad;
    ~melodyAttack = 0.01; ~melodyRelease = 0.5; ~melodyCutoff = 3670;
    ~melodyNotes = [47,0,35,40,50,0,0,0,0,0,0,33,0,33,0,0,40,0,0,0,0,35,0,47,0,0,45,38,50,0,0,0];
    ~melodyAmp = 0.23;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.2, 970, \sin, 2870) };
    ~vcfOn !? { ~vcfOn.(\moog, 1170, 0.4) };
    ~fxPreset !? { ~fxPreset.(\industrial) };
    ~reload.value;
    42.wait;

    "[N01 3:30] outro -- fade global...".postln;
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~vcfOff !? { ~vcfOff.() };
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~melodyAmp = x * 0.23; ~kickAmp = x * 0.54;
        ~hatAmp = x * 0.10; ~percAmp = x * 0.32; ~clapAmp = x * 0.32;
        ~melodyCutoff = 250 + (x * 2870);
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[N01 4:00] === fin PHONK OPENING ===".postln;
}).play;
"=== TRACK N01 : PHONK OPENING 4 min lancee ===".postln;
)

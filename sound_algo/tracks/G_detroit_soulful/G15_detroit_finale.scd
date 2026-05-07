// =====================================================================
//  G15_detroit_finale.scd  --  Album G, track 15/15
// =====================================================================

// --- TRACK G15 : "DETROIT FINALE" 6 minutes --------------------------
//   0:00 pad -> 0:45 kick -> 1:30 organ + stab -> 3:30 climax all -> 5:00 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[G15 0:00] warmPad final...".postln;
    ~bpm = 126;
    ~melodyInst = \warmPad; ~melodyAttack = 0.5; ~melodyRelease = 1.8;
    ~melodyCutoff = 1800; ~melodyAmp = 0.20;
    ~melodyNotes = [60,0,0,0, 65,0,0,0, 67,0,0,0, 72,0,0,0,
                    70,0,0,0, 67,0,0,0, 65,0,0,0, 60,0,0,0];
    ~kickSteps=(0!16); ~hatSteps=(0!16); ~clapSteps=(0!16); ~acidAmp=0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\space) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\chord);
    45.wait;

    "[G15 0:45] kick 4/4 final...".postln;
    ~kickSteps = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.55;
    ~kickFreq = 52; ~kickPitchAmt = 3.0; ~kickDecay = 0.32; ~kickClick = 0.15;
    ~hatSteps = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~hatAmp = 0.16;
    ~clapSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.35;
    ~reload.value;
    45.wait;

    "[G15 1:30] organ + stab apotheose...".postln;
    ~melodyInst = \organLead;
    ~melodyAttack = 0.005; ~melodyRelease = 0.18; ~melodyCutoff = 4800;
    ~melodyAmp = 0.20;
    ~melodyNotes = [63,0,67,0, 70,0,72,0, 70,0,67,0, 63,0,60,0,
                    65,0,67,0, 72,0,75,0, 72,0,70,0, 67,0,65,0];
    ~reload.value;
    24.do { |k|
        if (0.20.coin) {
            ~melodyNotes = ~mutate.(~melodyNotes, 0.25, ~scaleMinor);
            ~reload.value;
        };
        5.wait;
    };

    "[G15 3:30] climax -- supersaw + vcf + lfo...".postln;
    ~melodyInst = \supersaw;
    ~melodyAttack = 0.005; ~melodyRelease = 0.4; ~melodyCutoff = 5000;
    ~melodyAmp = 0.22;
    ~vcfOn !? { ~vcfOn.(\moog, 2500, 0.4) };
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.2, 2500, \sin, 5000) };
    ~reload.value;
    90.wait;

    "[G15 5:00] outro grand fade...".postln;
    ~vcfOff !? { ~vcfOff.() };
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~melodyInst = \warmPad;
    ~melodyAttack = 0.6; ~melodyRelease = 2.5;
    ~reload.value;
    60.do { |k|
        var x = 1 - ((k + 1) / 60);
        ~kickAmp = x * 0.55; ~hatAmp = x * 0.16; ~clapAmp = x * 0.35;
        ~melodyAmp = x * 0.22;
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[G15 6:00] === fin DETROIT FINALE ===".postln;
}).play;
"=== TRACK G15 : DETROIT FINALE 6 min lancee ===".postln;
)

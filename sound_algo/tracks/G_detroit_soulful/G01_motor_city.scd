// =====================================================================
//  G01_motor_city.scd  --  Album G "Detroit Soulful", track 1/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK G01 : "MOTOR CITY" 4 minutes ------------------------------
//   0:00 intro pad -> 0:45 kick 4/4 -> 1:30 organ stabs -> 3:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[G01 0:00] intro warmPad...".postln;
    ~bpm = 124;
    ~melodyInst = \warmPad; ~melodyAttack = 0.5; ~melodyRelease = 1.8;
    ~melodyCutoff = 1800; ~melodyAmp = 0.18;
    ~melodyNotes = [60,0,0,0, 63,0,0,0, 67,0,0,0, 70,0,0,0,
                    72,0,0,0, 70,0,0,0, 67,0,0,0, 63,0,0,0];
    ~kickSteps=(0!16); ~hatSteps=(0!16); ~snareSteps=(0!16);
    ~clapSteps=(0!16); ~percSteps=(0!16); ~acidAmp=0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\dub) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\chord);
    45.wait;

    "[G01 0:45] kick 4/4 + clap backbeat...".postln;
    ~kickSteps = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.5;
    ~kickFreq = 50; ~kickPitchAmt = 2.8; ~kickDecay = 0.35; ~kickClick = 0.12;
    ~hatSteps = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~hatAmp = 0.15;
    ~clapSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.32;
    ~reload.value;
    45.wait;

    "[G01 1:30] organ stabs Detroit + variations...".postln;
    ~melodyInst = \organLead;
    ~melodyAttack = 0.005; ~melodyRelease = 0.18; ~melodyCutoff = 4500;
    ~melodyAmp = 0.18;
    ~melodyNotes = [63,0,0,0, 67,0,70,0, 65,0,0,0, 70,0,72,0,
                    63,0,0,0, 67,0,70,0, 60,0,67,0, 63,0,0,0];
    ~reload.value;
    24.do { |k|
        if (0.20.coin) {
            ~melodyNotes = ~genMelody.(0.4,
                [~scaleMinor, ~scaleDorian, ~scaleMinorPent].choose);
            ~reload.value;
        };
        if (0.10.coin) { ~melodyCutoff = rrand(3500, 5500); ~reload.value };
        5.wait;
    };

    "[G01 3:30] outro -- pad fade...".postln;
    ~melodyInst = \warmPad;
    ~melodyAttack = 0.6; ~melodyRelease = 2.0;
    ~reload.value;
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~kickAmp = x * 0.5; ~hatAmp = x * 0.15; ~clapAmp = x * 0.32;
        ~melodyAmp = x * 0.18;
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[G01 4:00] === fin MOTOR CITY ===".postln;
}).play;
"=== TRACK G01 : MOTOR CITY 4 min lancee ===".postln;
)

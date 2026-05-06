// =========================================================
//  Argument optionnel : duree totale en mesures -- extrait de sequences.scd
// =========================================================
(
~seqBuildup = { |bars = 4|
    var stepsPerBar = 16;
    ~seqPlay.value([
        [stepsPerBar, {
            ~hatSteps   = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0];
            ~clapSteps  = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0];
            ~clapAmp    = 0.30;
            ~reload.value;
            "buildup 1: hat + clap".postln;
        }],
        [stepsPerBar, {
            ~hatSteps   = [1,0,1,0, 1,0,1,0, 1,0,1,0, 1,0,1,0];
            ~clapSteps  = [0,0,0,0, 1,0,0,0, 0,0,1,0, 1,0,0,0];
            ~clapAmp    = 0.36;
            ~reload.value;
            "buildup 2: hat 8th + clap dense".postln;
        }],
        [stepsPerBar, {
            ~hatSteps   = [1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1];
            ~clapSteps  = [0,0,1,0, 1,0,1,0, 0,1,0,1, 1,0,1,0];
            ~clapAmp    = 0.40;
            ~reload.value;
            "buildup 3: hat 16th + clap dense".postln;
        }],
        [stepsPerBar * (bars - 3).max(1), {
            ~hatSteps   = [1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1];
            ~snareSteps = [1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1];
            ~snareAmp   = 0.5;
            ~reload.value;
            "buildup 4: snare roll TENSION".postln;
        }],
    ]);
};
"=== ~seqBuildup defini ===".postln;
)

// =========================================================
//  mesure 4 : tout -- extrait de sequences.scd
// =========================================================
(
~seqIntro = {
    ~seqPlay.value([
        [16, {
            ~kickSteps  = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0];
            ~hatSteps   = (0!16);
            ~clapSteps  = (0!16);
            ~percSteps  = (0!16);
            ~reload.value;
            "intro 1/4 : kick seul".postln;
        }],
        [16, {
            ~hatSteps   = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0];
            ~reload.value;
            "intro 2/4 : + hat".postln;
        }],
        [16, {
            ~clapSteps  = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0];
            ~clapAmp = 0.35;
            ~reload.value;
            "intro 3/4 : + clap".postln;
        }],
        [16, {
            ~percSteps  = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0];
            ~percAmp = 0.25;
            ~reload.value;
            "intro 4/4 : tout".postln;
        }],
    ]);
};
"=== ~seqIntro defini ===".postln;
)

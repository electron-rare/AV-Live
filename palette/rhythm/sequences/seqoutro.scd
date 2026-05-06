// =========================================================
//  ~seqOutro -- fade-out progressif sur 32 steps -- extrait de sequences.scd
// =========================================================
(
~seqOutro = {
    ~seqPlay.value([
        [8, {
            ~percSteps = (0!16);
            ~reload.value;
            "outro 1 : perc out".postln;
        }],
        [8, {
            ~clapSteps = (0!16);
            ~reload.value;
            "outro 2 : clap out".postln;
        }],
        [8, {
            ~hatSteps = (0!16);
            ~snareSteps = (0!16);
            ~reload.value;
            "outro 3 : hat + snare out".postln;
        }],
        [8, {
            ~kickSteps = [1,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
            ~reload.value;
            "outro 4 : kick minimal".postln;
        }],
    ]);
};
"=== ~seqOutro defini ===".postln;
)

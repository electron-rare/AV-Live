// =========================================================
//  ~seqDnBSwitch -- alterne 4 patterns DnB toutes les 32 steps -- extrait de sequences.scd
// =========================================================
(
~seqDnBSwitch = { |repeats = 2|
    ~seqLoop.value([
        [32, {
            ~kickSteps  = [1,0,0,0, 0,0,1,0, 0,0,1,0, 1,0,0,0];
            ~snareSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,1];
            ~hatSteps   = [1,1,1,1, 0,1,1,1, 1,1,1,1, 0,1,1,1];
            ~kickAmp = 0.55; ~snareAmp = 0.5; ~hatAmp = 0.12;
            ~reload.value; "DnB A: amen".postln;
        }],
        [32, {
            ~kickSteps  = [1,0,0,1, 0,0,1,0, 0,0,1,0, 1,0,0,0];
            ~snareSteps = [0,0,0,0, 1,0,0,0, 0,0,0,1, 1,0,1,1];
            ~hatSteps   = [1,1,0,1, 1,0,1,1, 1,1,0,1, 1,0,1,1];
            ~reload.value; "DnB B: jungle".postln;
        }],
        [32, {
            ~kickSteps  = [1,0,0,0, 0,1,1,0, 0,0,1,0, 0,1,0,0];
            ~snareSteps = [0,0,0,0, 1,0,0,1, 0,0,0,0, 1,0,1,0];
            ~hatSteps   = [1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1];
            ~reload.value; "DnB C: jump-up".postln;
        }],
        [32, {
            ~kickSteps  = [1,0,0,0, 0,0,1,0, 0,0,1,0, 1,0,0,0];
            ~snareSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0];
            ~hatSteps   = [1,0,1,1, 0,1,0,1, 1,0,1,1, 0,1,0,1];
            ~reload.value; "DnB D: liquid".postln;
        }],
    ], repeats);
};
"=== ~seqDnBSwitch defini ===".postln;
)

// =========================================================
//  HELPERS DE BASE -- evaluer ce bloc une fois pour exposer les helpers -- extrait de sequences.scd
// =========================================================
(
~stepDur = 0.25;     // duree d'un step en battement (1/16 a 4/4)
~currentSeq = nil;   // Routine en cours


// --- ~seqPlay.([[steps, action], ...]) ------------------------------
//   Joue une suite d'actions a intervalles donnes en steps.
//   Stoppe toute sequence precedente avant de demarrer.
~seqPlay = { |actions|
    ~seqStop.value;
    ~currentSeq = Routine({
        actions.do { |entry|
            var steps = entry[0];
            var action = entry[1];
            action.value;
            (steps * ~stepDur).wait;
        };
        ~currentSeq = nil;
    }).play(TempoClock.default);
    "=== seqPlay : % steps en cours ===".format(actions.collect(_[0]).sum).postln;
};


// --- ~seqStop.() ----------------------------------------------------
~seqStop = {
    ~currentSeq !? { ~currentSeq.stop; ~currentSeq = nil; "=== seqStop ===".postln };
};


// --- ~seqLoop.(actions, repeats) ------------------------------------
//   Enchaine la liste d'actions en boucle N fois (defaut 1).
~seqLoop = { |actions, repeats = 1|
    var expanded = Array.new(actions.size * repeats);
    repeats.do { actions.do { |a| expanded.add(a) } };
    ~seqPlay.value(expanded);
    "=== seqLoop : % cycles ===".format(repeats).postln;
};


// --- ~seqEvolve.(steps, mutator) ------------------------------------
//   Appelle 'mutator' en boucle toutes les 'steps' steps. La routine
//   tourne jusqu'a seqStop.
~seqEvolve = { |stepsBetween = 16, mutator|
    ~seqStop.value;
    ~currentSeq = Routine({
        inf.do { |i|
            mutator.value(i);
            (stepsBetween * ~stepDur).wait;
        };
    }).play(TempoClock.default);
    "=== seqEvolve : mutator chaque % steps ===".format(stepsBetween).postln;
};


// --- ~beatChainPlay.(presets) ---------------------------------------
//   Enchaine plusieurs presets sous forme de [stepsToHold, action].
//   Equivalent a ~seqPlay mais sucre syntaxique pour chains de drumkits.
~beatChainPlay = { |presets|
    ~seqPlay.value(presets);
};

"=== sequences helpers : ~seqPlay ~seqStop ~seqLoop ~seqEvolve ~beatChainPlay ===".postln;
)

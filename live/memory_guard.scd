// =====================================================================
//  live/memory_guard.scd  --  Garde-fous fuite memoire scsynth
//
//  Expose les helpers live :
//
//    ~killAllOrphans.()           stop toutes les Routines + Pdefs +
//                                 LFO connus + libere les bus FX
//                                 dynamiques, SANS toucher au master
//                                 bus ni aux FX bus statiques.
//                                 -> a appeler avant chaque relance.
//
//    ~freeDynFxBuses.()           libere uniquement les Bus.audio
//                                 alloues a la volee par ~addFx.
//
//    ~nukeOrphanSynths.()         PANIQUE : defaultGroup.freeAll.
//                                 Coupe l'audio, relance ~setupAll.
//
//    ~auditBuses.()               compte bus statiques + dynamiques
//                                 et liste les orphelins (dyn sans FX).
//
//    ~memReport.()                snapshot numSynths/Groups/UGens/CPU.
//
//    ~watchdogOn.(seuil, interval)  Routine fond, log si numSynths
//                                 depasse le seuil. Defauts : 80, 10s.
//
//    ~watchdogOff.()              arrete le watchdog.
//
//    ~guardCmdPeriodOn.()         hook auto : Cmd-. declenche aussi
//                                 ~killAllOrphans. Idempotent.
//
//    ~guardCmdPeriodOff.()        retire le hook.
//
//  PREREQUIS : engine.scd + setup.scd evalues, serveur boote.
//  Convention : un seul bloc top-level (compatible .load).
// =====================================================================

(

// =====================================================================
//  Registry des Routines connues
//   On ne touche jamais a master_comp / master_lim / vinyl /
//   les FX bus (~fxFx) -- ils doivent rester pour ne pas tuer l'audio.
// =====================================================================

~guardKnownRoutines = [
    \track,                  // tracks/*.scd
    \albumRoutine,           // tracks/<L>_<slug>/_album.scd
    \filterSweep,            // engine.scd
    \randomLoop,             // engine.scd
    \melodyEvolve,           // engine.scd
    \lRotate,                // engine.scd / live
    \crossfadeFxRoutine,     // live/fx_bus.scd
    \chainRoutine,           // live/chains.scd
    \playlist,               // live/scenes
    \vcfSweepRoutine,        // live/live.scd ~vcfSweep (sweep cutoff VCF)
    \guardWatchdog,          // notre propre watchdog (auto-stop)
];

~guardKnownPdefs = [
    \kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq,
    \acidSeq, \melodySeq, \harmonySeq,
];


// =====================================================================
//  ~killAllOrphans : stop tout ce qui peut accumuler des Synths
//   Ne free pas l'infra audio (master bus + FX bus restent vivants).
// =====================================================================

~killAllOrphans = {
    var stopped = 0;

    // 1. Routines simples enregistrees
    ~guardKnownRoutines.do { |key|
        var r = currentEnvironment[key];
        if (r.notNil) {
            try { r.stop } { |err| };
            currentEnvironment[key] = nil;
            stopped = stopped + 1;
        };
    };

    // 2. Pdefs sequenceurs connus
    ~guardKnownPdefs.do { |key| Pdef(key).stop };

    // 3. Tricks routines (live.scd : ~trickRoutines[\stutter|\drop|...])
    ~trickRoutines !? {
        ~trickRoutines.keysValuesDo { |k, v|
            try { v.stop } { |err| };
            stopped = stopped + 1;
        };
        ~trickRoutines.clear;
    };

    // 4. LFO assignables (live.scd : ~lfos[paramName])
    ~lfos !? {
        ~lfos.keysValuesDo { |k, v|
            try { v.stop } { |err| };
            stopped = stopped + 1;
        };
        ~lfos.clear;
    };
    ~lfoStopEverything !? { ~lfoStopEverything.value };

    // 5. Envelopes one-shot (live.scd : ~envs[paramName])
    ~envs !? {
        ~envs.keysValuesDo { |k, v|
            try { v.stop } { |err| };
            stopped = stopped + 1;
        };
        ~envs.clear;
    };

    // 6. LFO du bus FX (fx_bus.scd : ~fxLfos[fxKey])
    ~fxLfos !? {
        ~fxLfos.keysValuesDo { |k, v|
            try { v.stop } { |err| };
            stopped = stopped + 1;
        };
        ~fxLfos.clear;
    };
    ~lfoStopAll !? { ~lfoStopAll.value };

    // 7. Loops live (live.scd : ~loops[name])
    ~loopOffAll !? { ~loopOffAll.value };

    // 8. Auto-fx panning / tremolo
    ~stopAutoFx !? {
        [\kick, \hat, \snare, \clap, \perc, \acid, \melody, \harmony]
            .do { |v| try { ~stopAutoFx.(v) } { |err| } };
    };

    // 9. Bus FX alloues dynamiquement par ~addFx (live.scd) - non
    //    couverts par le guard de fx_bus.scd
    ~freeDynFxBuses !? { ~freeDynFxBuses.value };

    ("[guard] killAllOrphans : " ++ stopped ++ " routines stoppees, "
     ++ ~guardKnownPdefs.size ++ " Pdefs stoppes").postln;
    stopped;
};


// =====================================================================
//  ~freeDynFxBuses : libere les Bus.audio alloues a la volee par
//   ~addFx (live.scd). Detruit aussi le Synth FX correspondant pour
//   eviter qu'il pointe sur un bus libere.
// =====================================================================

~freeDynFxBuses = {
    var n = 0;
    ~fxBusesDyn !? {
        ~fxBusesDyn.keysValuesDo { |key, bus|
            ~fxFx !? {
                ~fxFx[key] !? { try { ~fxFx[key].free }; ~fxFx[key] = nil };
            };
            ~fxBuses !? { ~fxBuses[key] = nil };
            try { bus.free };
            n = n + 1;
        };
        ~fxBusesDyn.clear;
    };
    if (n > 0) { ("[guard] freeDynFxBuses : " ++ n ++ " bus liberes").postln };
    n;
};


// =====================================================================
//  ~nukeOrphanSynths : option PANIQUE. Free tous les Synths du
//   defaultGroup -- a n'utiliser que si ~killAllOrphans n'a pas suffi.
//   Risque : coupe l'audio en cours. Conserve les Groups et l'infra.
// =====================================================================

~nukeOrphanSynths = {
    var srv = Server.default;
    if (srv.serverRunning) {
        var before = srv.numSynths;
        srv.defaultGroup.freeAll;
        ("[guard] NUKE : defaultGroup.freeAll  (synths avant=" ++ before
         ++ ")  -- relance ~setupAll pour reconstruire").postln;
    } {
        "[guard] !! serveur non boote".postln;
    };
};


// =====================================================================
//  ~auditBuses : compte les Bus alloues (statiques + dynamiques) et
//   detecte les fuites probables (dyn buses orphelins sans Synth FX).
// =====================================================================

~auditBuses = {
    var nStatic = 0, nDyn = 0, orphans = [];
    ~fxBuses !? { nStatic = ~fxBuses.size };
    ~fxBusesDyn !? {
        nDyn = ~fxBusesDyn.size;
        ~fxBusesDyn.keysValuesDo { |k, b|
            if (~fxFx.isNil or: { ~fxFx[k].isNil }) {
                orphans = orphans.add(k);
            };
        };
    };
    ("[audit] fxBuses static=" ++ nStatic ++ "  dyn=" ++ nDyn
     ++ "  orphans=" ++ orphans).postln;
    (static: nStatic, dyn: nDyn, orphans: orphans);
};


// =====================================================================
//  ~guardCmdPeriodOn / Off : hook CmdPeriod automatique.
//   Quand l'utilisateur fait Cmd-. (panic stop), on lance
//   ~killAllOrphans en plus du free standard de SC. Idempotent.
// =====================================================================

~guardCmdPeriodFn = ~guardCmdPeriodFn ?? { { ~killAllOrphans.value } };

~guardCmdPeriodOn = {
    CmdPeriod.remove(~guardCmdPeriodFn);  // idempotence
    CmdPeriod.add(~guardCmdPeriodFn);
    "[guard] CmdPeriod hook ON  (~killAllOrphans sur Cmd-.)".postln;
};

~guardCmdPeriodOff = {
    CmdPeriod.remove(~guardCmdPeriodFn);
    "[guard] CmdPeriod hook OFF".postln;
};


// =====================================================================
//  ~memReport : snapshot ponctuel de l'etat scsynth
// =====================================================================

~memReport = {
    var srv = Server.default;
    var nSynths, nGroups, nUGens, line;
    if (srv.serverRunning.not) {
        "[guard] !! serveur non boote".postln;
        nil;
    } {
        nSynths = srv.numSynths;
        nGroups = srv.numGroups;
        nUGens  = srv.numUGens;
        line = "[mem] synths=" ++ nSynths
            ++ "  groups=" ++ nGroups
            ++ "  ugens=" ++ nUGens
            ++ "  avgCPU=" ++ srv.avgCPU.round(0.1) ++ "%"
            ++ "  peakCPU=" ++ srv.peakCPU.round(0.1) ++ "%";
        line.postln;
        nSynths;
    };
};


// =====================================================================
//  ~watchdogOn / ~watchdogOff : surveillance numSynths en tache de fond
//   Ne tue rien automatiquement -- log seulement un warning si depasse.
//   Tu decides si tu veux ~killAllOrphans.() en reponse.
// =====================================================================

~watchdogOn = { |seuil = 80, interval = 10|
    ~guardWatchdog !? { ~guardWatchdog.stop; ~guardWatchdog = nil };
    ~guardSeuil = seuil;
    ~guardInterval = interval;
    ~guardLastN = 0;
    ~guardWatchdog = Routine({
        loop {
            interval.wait;
            if (Server.default.serverRunning) {
                var n = Server.default.numSynths;
                var dn = n - ~guardLastN;
                ~guardLastN = n;
                if (n > seuil) {
                    ("[GUARD] !! synths=" ++ n ++ " > seuil " ++ seuil
                     ++ " (Δ=" ++ dn ++ ")"
                     ++ "  -- envisage ~killAllOrphans.()").postln;
                };
            };
        };
    }).play(AppClock);
    ("[guard] watchdog ON  (seuil=" ++ seuil
     ++ " synths, interval=" ++ interval ++ "s)").postln;
};

~watchdogOff = {
    ~guardWatchdog !? { ~guardWatchdog.stop; ~guardWatchdog = nil };
    "[guard] watchdog OFF".postln;
};


"[memory_guard] OK -- ~killAllOrphans / ~freeDynFxBuses / ~nukeOrphanSynths / ~auditBuses / ~memReport / ~watchdogOn(seuil,intv) / ~watchdogOff / ~guardCmdPeriodOn".postln;

)


// =====================================================================
//  RACCOURCIS LIVE -- Cmd+Entree sur la ligne souhaitee
// =====================================================================

( ~memReport.(); )                   // snapshot ponctuel
( ~auditBuses.(); )                  // compte bus + orphelins
( ~killAllOrphans.(); )              // nettoyage avant relance
( ~freeDynFxBuses.(); )              // free uniquement bus FX dynamiques
( ~nukeOrphanSynths.(); )            // PANIQUE : defaultGroup.freeAll
( ~watchdogOn.(80, 10); )            // surveille (seuil 80, toutes les 10s)
( ~watchdogOn.(120, 5); )            // session lourde (seuil 120, toutes les 5s)
( ~watchdogOff.(); )                 // arrete la surveillance
( ~guardCmdPeriodOn.(); )            // Cmd-. declenche aussi killAllOrphans
( ~guardCmdPeriodOff.(); )           // retire le hook

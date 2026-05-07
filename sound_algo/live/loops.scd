// =====================================================================
//  loops.scd  --  Gestionnaire de pistes / boucles pour live SuperCollider
//
//  PREREQUIS : engine.scd charge (Pdef nommes + ~bpm + ~reload).
//              Optionnel : palette/melodies/tracks.scd (~melTrackOn/Off),
//              palette/rhythm/sequences.scd (~seqPlay/~seqStop),
//              live/mixer.scd.
//
//  CONCEPT
//    Une "boucle" est une entite a etat (ON / OFF, count, max, source).
//    Source possible :
//      - un Symbol -> Pdef de ce nom (ex: \kickSeq, \m1Seq)
//      - une Function -> jouee en Routine (yields = beats)
//
//  HELPERS PRINCIPAUX
//    ~loopOn / ~loopOff / ~loopOffAll / ~loopToggle / ~loopIsOn
//    ~loopList / ~loopInfo / ~loopProgress / ~loopShow
//    ~loopRepeat / ~loopBeats / ~loopBars / ~loopSync
//    ~loopCount / ~loopReset / ~loopMax
//    ~loopCountdown / ~loopWithCountdown
//    ~loopSnapshot / ~loopRestore / ~loopSave / ~loopLoad
//    ~loopChain / ~loopParallel
//    ~loopFade / ~loopFadeIn / ~loopAutoStop / ~loopAutoFade
//    ~kickLoop / ~hatLoop / ~snareLoop / ~clapLoop / ~percLoop
//    ~acidLoop / ~melodyLoop / ~harmonyLoop / ~allOn / ~allOff
//
//  Un seul bloc top-level pour compatibilite .load
// =====================================================================
(
// ---------- Etat global ---------------------------------------------
~loops      = ~loops      ?? { () };           // dict des boucles (Event)
~loopsSnap  = ~loopsSnap  ?? { () };           // snapshots (params + amps)
~loopAutos  = ~loopAutos  ?? { () };           // routines d'auto-stop / auto-fade
~loopChainR = ~loopChainR ?? { nil };          // routine chain en cours
~loopParR   = ~loopParR   ?? { () };           // routines parallel par groupe

// ---------- Pdef du moteur (8 voies nommees) ------------------------
~loopEngineSyms = [\kickSeq, \hatSeq, \snareSeq, \clapSeq,
                   \percSeq, \acidSeq, \melodySeq, \harmonySeq];

// ---------- Utilitaires internes ------------------------------------
// Renvoie true si la source est un Symbol qui correspond a un Pdef
~loopIsPdef = { |source| source.isKindOf(Symbol) };

// Demarre une source dans une Routine (Function) ou via Pdef (Symbol).
// Renvoie une "handle" : un EventStreamPlayer / Routine selon le cas.
~loopStartSource = { |source, name|
    var handle;
    if (~loopIsPdef.(source)) {
        Pdef(source).play;
        handle = (kind: \pdef, sym: source);
    } {
        // Function : on l'execute en Routine. La fonction recoit le
        // nom de la boucle pour pouvoir incrementer le compteur si elle
        // veut (sinon on incrementera depuis l'exterieur).
        var r = Routine({ source.value(name) }).play;
        handle = (kind: \routine, rout: r);
    };
    handle
};

~loopStopHandle = { |h|
    if (h.notNil) {
        switch (h[\kind],
            \pdef,    { Pdef(h[\sym]).stop },
            \routine, { h[\rout] !? { h[\rout].stop } }
        );
    };
};

// =====================================================================
//  1. GESTION DE BASE  (on/off/toggle/list/isOn)
// =====================================================================

// ~loopOn.(\name, source [, max])
//   source : Symbol (Pdef) ou Function. max optionnel (defaut inf).
~loopOn = { |name, source, max = inf|
    var l = ~loops[name];
    if (l.notNil and: { l[\state] == \on }) {
        ("[loop] " ++ name ++ " deja ON").postln;
    } {
        // Source heritee si pas fournie
        var src = source ?? { l !? { l[\source] } };
        if (src.isNil) {
            ("[loop] " ++ name ++ " : pas de source connue").postln;
        } {
            var handle = ~loopStartSource.(src, name);
            ~loops[name] = (
                state:    \on,
                source:   src,
                handle:   handle,
                count:    (l !? { l[\count] }) ? 0,
                max:      max,
                startedAt: Main.elapsedTime,
                lastResetAt: Main.elapsedTime,
            );
            ("[loop] ON  " ++ name).postln;
        };
    };
    name
};

~loopOff = { |name|
    var l = ~loops[name];
    if (l.isNil) {
        ("[loop] " ++ name ++ " inconnue").postln;
    } {
        ~loopStopHandle.(l[\handle]);
        // Annule auto-stop / auto-fade en cours
        ~loopAutos[name] !? { |r| r.stop; ~loopAutos[name] = nil };
        l[\state] = \off;
        l[\handle] = nil;
        ("[loop] OFF " ++ name).postln;
    };
};

~loopOffAll = {
    ~loops.keysDo { |k|
        var l = ~loops[k];
        if (l.notNil and: { l[\state] == \on }) { ~loopOff.(k) };
    };
    "[loop] offAll".postln;
};

~loopToggle = { |name|
    var l = ~loops[name];
    if (l.notNil and: { l[\state] == \on }) {
        ~loopOff.(name);
    } {
        ~loopOn.(name);
    };
};

~loopIsOn = { |name|
    var l = ~loops[name];
    (l.notNil and: { l[\state] == \on })
};

// Affichage : etat / source / count / max
~loopList = {
    "=== loops ===".postln;
    if (~loops.isEmpty) {
        "  (aucune boucle)".postln;
    } {
        ~loops.keysValuesDo { |k, v|
            var st  = if (v[\state] == \on) { "ON " } { "off" };
            var src = v[\source];
            var srcStr = if (src.isKindOf(Symbol)) { src.asString }
                         { if (src.isKindOf(Function)) { "<fn>" } { "?" } };
            var maxStr = if (v[\max] == inf) { "inf" } { v[\max].asString };
            ("  [" ++ st ++ "] " ++ k
                ++ "  src=" ++ srcStr
                ++ "  count=" ++ (v[\count] ? 0)
                ++ "/" ++ maxStr
            ).postln;
        };
    };
};

// =====================================================================
//  2. COMPTEURS
// =====================================================================

// ~loopRepeat.(\name, source, n, dur)
//   Joue source N fois (chaque iter dure `dur` battements), puis stop.
~loopRepeat = { |name, source, n = 4, dur = 4|
    var t = TempoClock.default;
    var max = n;
    ~loopOn.(name, source, max);
    // Routine qui incremente le compteur a chaque dur, et stoppe a max
    ~loopAutos[name] !? { |r| r.stop };
    ~loopAutos[name] = Routine({
        n.do { |i|
            dur.wait;
            if (~loops[name].notNil) {
                ~loops[name][\count] = (~loops[name][\count] ? 0) + 1;
            };
        };
        // Fin atteinte : stop
        ~loopOff.(name);
    }).play(t);
    ("[loop] repeat " ++ name ++ " n=" ++ n ++ " dur=" ++ dur ++ "b").postln;
    name
};

~loopCount = { |name|
    var l = ~loops[name];
    if (l.isNil) { 0 } { l[\count] ? 0 }
};

~loopReset = { |name|
    var l = ~loops[name];
    if (l.notNil) {
        l[\count] = 0;
        l[\lastResetAt] = Main.elapsedTime;
        ("[loop] reset " ++ name).postln;
    };
};

~loopMax = { |name, n|
    var l = ~loops[name];
    if (l.notNil) {
        l[\max] = n;
        ("[loop] max " ++ name ++ " = " ++ n).postln;
    };
};

// =====================================================================
//  3. SYNCHRONISATION AU TEMPO
// =====================================================================

// Joue une source pendant N battements, puis stop.
~loopBeats = { |name, source, beats = 16|
    var t = TempoClock.default;
    ~loopOn.(name, source, beats);
    ~loopAutos[name] !? { |r| r.stop };
    ~loopAutos[name] = Routine({
        beats.wait;
        ~loopOff.(name);
    }).play(t);
    ("[loop] " ++ name ++ " pendant " ++ beats ++ " beats").postln;
    name
};

// N mesures (defaut 4 battements/mesure)
~loopBars = { |name, source, bars = 4, beatsPerBar = 4|
    ~loopBeats.(name, source, bars * beatsPerBar);
};

// Aligne le demarrage de toutes les boucles ON au prochain temps fort
// (utilise pour resync apres avoir lance plusieurs boucles).
~loopSync = { |beatsPerBar = 4|
    var t = TempoClock.default;
    var now = t.beats;
    var nextBar = now.ceil + ((beatsPerBar - (now.ceil.asInteger % beatsPerBar)) % beatsPerBar);
    var wait = nextBar - now;
    var snapshot = (); // {name -> source}
    ~loops.keysValuesDo { |k, v|
        if (v[\state] == \on) { snapshot[k] = v[\source] };
    };
    if (snapshot.isEmpty) {
        "[loop] sync : aucune boucle ON".postln;
    } {
        ("[loop] sync dans " ++ wait.round(0.01) ++ " beats ("
            ++ snapshot.size ++ " boucles)").postln;
        // Stop immediat, restart sur la barre suivante
        snapshot.keysDo { |k| ~loopOff.(k) };
        Routine({
            wait.wait;
            snapshot.keysValuesDo { |k, src| ~loopOn.(k, src) };
            "[loop] sync OK".postln;
        }).play(t);
    };
};

// =====================================================================
//  4. PRE-ROLL / COUNTDOWN
// =====================================================================

// Compte avant de lancer une action. action est une Function (sans arg).
~loopCountdown = { |beats = 4, action|
    var t = TempoClock.default;
    Routine({
        beats.do { |i|
            var n = beats - i;
            (n.asString ++ "...").postln;
            1.wait;
        };
        "GO".postln;
        action !? { action.value };
    }).play(t);
    ("[loop] countdown " ++ beats ++ "b").postln;
};

// Countdown puis lance la boucle (max optionnel)
~loopWithCountdown = { |name, source, beats = 4, max = inf|
    ~loopCountdown.(beats, { ~loopOn.(name, source, max) });
};

// =====================================================================
//  5. SNAPSHOT / RESTORE / SAVE / LOAD
// =====================================================================

// Cle des "params interessants" a sauvegarder (heuristique).
// On capture toutes les vars ~xxx qui sont des Number/Symbol/SimpleNumber
// liees au prefixe du nom (ex: \kick -> ~kickAmp, ~kickDrive...) +
// les amps connus du moteur.
~loopSnapKeys = (~loopSnapKeys ?? { [
    \bpm,
    \kickAmp, \kickDrive, \kickDecay,
    \hatAmp, \hatDecay,
    \snareAmp, \snareDrive,
    \clapAmp,
    \percAmp,
    \acidAmp, \acidCutoff, \acidDrive, \acidRq,
    \melodyAmp, \melodyBoost, \melodyCutoff,
    \harmonyAmp,
    \leadScAmt, \scShape,
] });

~loopSnapshot = { |name|
    var snap = ();
    ~loopSnapKeys.do { |k|
        var v = currentEnvironment[k];
        if (v.notNil and: { v.isKindOf(Number) or: { v.isKindOf(Symbol) } }) {
            snap[k] = v;
        };
    };
    // Ajoute les coefs mixer si presents
    if (~mix.notNil) { snap[\__mix] = ~mix.copy };
    // Ajoute l'etat de la boucle si elle existe
    if (~loops[name].notNil) {
        snap[\__loopState] = (
            count: ~loops[name][\count] ? 0,
            max:   ~loops[name][\max]   ? inf,
            source: ~loops[name][\source]
        );
    };
    ~loopsSnap[name] = snap;
    ("[loop] snapshot " ++ name ++ " (" ++ snap.size ++ " cles)").postln;
    snap
};

~loopRestore = { |name|
    var snap = ~loopsSnap[name];
    if (snap.isNil) {
        ("[loop] restore : pas de snapshot pour " ++ name).postln;
    } {
        snap.keysValuesDo { |k, v|
            if (k == \__mix) {
                if (~mix.notNil) {
                    v.keysValuesDo { |k2, v2| ~mix[k2] = v2 };
                };
            } {
                if (k != \__loopState) {
                    currentEnvironment[k] = v;
                };
            };
        };
        // Reload des Pdef du moteur si dispo
        ~reload !? { ~reload.value };
        ("[loop] restore " ++ name).postln;
    };
};

// Save / Load disque (en .scd : on serialise via Object.asCompileString)
~loopSavePath = { |name|
    (~base ? "") ++ ".loops_" ++ name.asString ++ ".scd"
};

~loopSave = { |name|
    var snap = ~loopsSnap[name] ?? { ~loopSnapshot.(name) };
    var path = ~loopSavePath.(name);
    var f = File.open(path, "w");
    if (f.isNil) {
        ("[loop] save : impossible d'ouvrir " ++ path).postln;
    } {
        f.write(snap.asCompileString);
        f.close;
        ("[loop] save " ++ name ++ " -> " ++ path).postln;
    };
};

~loopLoad = { |name|
    var path = ~loopSavePath.(name);
    if (File.exists(path).not) {
        ("[loop] load : fichier absent " ++ path).postln;
    } {
        var snap = path.load;
        if (snap.notNil) {
            ~loopsSnap[name] = snap;
            ("[loop] load " ++ name ++ " <- " ++ path).postln;
        };
    };
};

// =====================================================================
//  6. COMPOSITIONS
// =====================================================================

// Chaine sequentielle : [[name, source, beats], ...]
// Chaque entree joue `beats` battements, puis on passe au suivant.
~loopChain = { |entries|
    var t = TempoClock.default;
    ~loopChainR !? { |r| r.stop };
    ~loopChainR = Routine({
        entries.do { |e|
            var name   = e[0];
            var source = e[1];
            var beats  = e[2] ? 16;
            ~loopOn.(name, source);
            beats.wait;
            ~loopOff.(name);
        };
        "[loop] chain done".postln;
    }).play(t);
    ("[loop] chain " ++ entries.size ++ " entrees").postln;
};

// Lance plusieurs boucles simultanement : [[name, source], ...]
~loopParallel = { |entries|
    entries.do { |e|
        var name   = e[0];
        var source = e[1];
        ~loopOn.(name, source);
    };
    ("[loop] parallel " ++ entries.size ++ " boucles").postln;
};

// Fade-out d'une boucle (sur l'amp de la voie correspondante au
// prefixe du nom : \kickXxx -> ~kickAmp). Stoppe a la fin.
~loopFadeAmpKey = { |name|
    // \kickLoop -> \kickAmp ; \m1 -> nil (cas multi-pistes : on
    // fait un fade local en surtout via un Pdef)
    var s = name.asString;
    var prefixes = ["kick","hat","snare","clap","perc","acid",
                    "melody","harmony"];
    var found = nil;
    prefixes.do { |p|
        if (found.isNil and: { s.beginsWith(p) }) {
            found = (p ++ "Amp").asSymbol;
        };
    };
    found
};

~loopFade = { |name, fadeOutDur = 2|
    var t = TempoClock.default;
    var ampKey = ~loopFadeAmpKey.(name);
    var l = ~loops[name];
    if (l.isNil) {
        ("[loop] fade : " ++ name ++ " inconnue").postln;
    } {
        if (ampKey.notNil) {
            var startAmp = currentEnvironment[ampKey] ? 0.3;
            var steps = (fadeOutDur * 20).asInteger.max(1);
            var step = 1.0 / steps;
            ~loopAutos[name] !? { |r| r.stop };
            ~loopAutos[name] = Routine({
                steps.do { |i|
                    currentEnvironment[ampKey] = startAmp * (1 - ((i + 1) * step));
                    ~reload !? { ~reload.value };
                    (fadeOutDur / steps).wait;
                };
                ~loopOff.(name);
                currentEnvironment[ampKey] = startAmp; // restore amp
                ~reload !? { ~reload.value };
            }).play(t);
            ("[loop] fade " ++ name ++ " (" ++ fadeOutDur ++ "s)").postln;
        } {
            // Pas d'ampKey : on attend simplement, puis stop
            ~loopAutos[name] !? { |r| r.stop };
            ~loopAutos[name] = Routine({
                fadeOutDur.wait;
                ~loopOff.(name);
            }).play(t);
            ("[loop] fade " ++ name ++ " (timed, no amp key)").postln;
        };
    };
};

~loopFadeIn = { |name, source, fadeInDur = 2, max = inf|
    var t = TempoClock.default;
    var ampKey = ~loopFadeAmpKey.(name);
    var targetAmp = if (ampKey.notNil) {
        currentEnvironment[ampKey] ? 0.3
    } { nil };
    if (ampKey.notNil) {
        currentEnvironment[ampKey] = 0.0001;
        ~reload !? { ~reload.value };
    };
    ~loopOn.(name, source, max);
    if (ampKey.notNil) {
        var steps = (fadeInDur * 20).asInteger.max(1);
        ~loopAutos[name] !? { |r| r.stop };
        ~loopAutos[name] = Routine({
            steps.do { |i|
                currentEnvironment[ampKey] = targetAmp * ((i + 1) / steps);
                ~reload !? { ~reload.value };
                (fadeInDur / steps).wait;
            };
        }).play(t);
        ("[loop] fadeIn " ++ name ++ " -> " ++ targetAmp).postln;
    } {
        ("[loop] fadeIn " ++ name ++ " (no amp key)").postln;
    };
};

// =====================================================================
//  7. AFFICHAGE / DEBUG
// =====================================================================

// Bargraph ASCII court pour count/max
~loopBar = { |count, max, width = 20|
    var ratio, full, str;
    if (max == inf or: { max == 0 }) {
        // Pas de max : on affiche un placeholder
        "[--------------------]"
    } {
        ratio = (count / max).clip(0, 1);
        full  = (ratio * width).asInteger;
        str   = "[" ++ ("#" ! full).join ++ ("." ! (width - full)).join ++ "]";
        str
    }
};

~loopProgress = {
    "=== loop progress ===".postln;
    if (~loops.isEmpty) {
        "  (aucune boucle)".postln;
    } {
        ~loops.keysValuesDo { |k, v|
            var st  = if (v[\state] == \on) { "ON " } { "off" };
            var c   = v[\count] ? 0;
            var m   = v[\max]   ? inf;
            var bar = ~loopBar.(c, m, 20);
            var maxStr = if (m == inf) { "inf" } { m.asString };
            ("  [" ++ st ++ "] " ++ k ++ "  " ++ bar
                ++ "  " ++ c ++ "/" ++ maxStr).postln;
        };
    };
};

// Alias visuel
~loopShow = { ~loopProgress.value };

// Info compacte d'une seule boucle
~loopInfo = { |name|
    var v = ~loops[name];
    if (v.isNil) {
        ("[loop] " ++ name ++ " inconnue").postln;
    } {
        var st  = if (v[\state] == \on) { "ON" } { "off" };
        var src = v[\source];
        var srcStr = if (src.isKindOf(Symbol)) { src.asString }
                     { if (src.isKindOf(Function)) { "<fn>" } { "?" } };
        var c = v[\count] ? 0;
        var m = v[\max]   ? inf;
        var bar = ~loopBar.(c, m, 20);
        var maxStr = if (m == inf) { "inf" } { m.asString };
        var elapsed = (Main.elapsedTime - (v[\startedAt] ? Main.elapsedTime)).round(0.1);
        ("[loop] " ++ name ++ " " ++ st
            ++ "  src=" ++ srcStr
            ++ "  " ++ bar ++ "  " ++ c ++ "/" ++ maxStr
            ++ "  age=" ++ elapsed ++ "s").postln;
    };
};

// =====================================================================
//  8. AUTO-STOP / AUTO-FADE PROGRAMMES
// =====================================================================

~loopAutoStop = { |name, beats = 16|
    var t = TempoClock.default;
    if (~loops[name].isNil) {
        ("[loop] autoStop : " ++ name ++ " inconnue").postln;
    } {
        ~loopAutos[name] !? { |r| r.stop };
        ~loopAutos[name] = Routine({
            beats.wait;
            ~loopOff.(name);
        }).play(t);
        ("[loop] autoStop " ++ name ++ " dans " ++ beats ++ "b").postln;
    };
};

~loopAutoFade = { |name, beats = 16, fadeDur = 1|
    var t = TempoClock.default;
    if (~loops[name].isNil) {
        ("[loop] autoFade : " ++ name ++ " inconnue").postln;
    } {
        ~loopAutos[name] !? { |r| r.stop };
        ~loopAutos[name] = Routine({
            beats.wait;
            ~loopFade.(name, fadeDur);
        }).play(t);
        ("[loop] autoFade " ++ name ++ " dans " ++ beats ++ "b ("
            ++ fadeDur ++ "s)").postln;
    };
};

// =====================================================================
//  9. HELPERS POUR LES PDEF DU MOTEUR
// =====================================================================
// Chaque helper utilise un nom de boucle base sur la voie + source
// Pdef correspondant. Si beats = inf -> simple ~loopOn ; sinon ~loopBeats.

~loopEngineHelper = { |voiceSym, beats|
    var seqSym = (voiceSym.asString ++ "Seq").asSymbol;
    var loopName = (voiceSym.asString ++ "Loop").asSymbol;
    if (beats == inf or: { beats.isNil }) {
        ~loopOn.(loopName, seqSym);
    } {
        ~loopBeats.(loopName, seqSym, beats);
    };
    loopName
};

~kickLoop    = { |beats = inf| ~loopEngineHelper.(\kick,    beats) };
~hatLoop     = { |beats = inf| ~loopEngineHelper.(\hat,     beats) };
~snareLoop   = { |beats = inf| ~loopEngineHelper.(\snare,   beats) };
~clapLoop    = { |beats = inf| ~loopEngineHelper.(\clap,    beats) };
~percLoop    = { |beats = inf| ~loopEngineHelper.(\perc,    beats) };
~acidLoop    = { |beats = inf| ~loopEngineHelper.(\acid,    beats) };
~melodyLoop  = { |beats = inf| ~loopEngineHelper.(\melody,  beats) };
~harmonyLoop = { |beats = inf| ~loopEngineHelper.(\harmony, beats) };

// Lance / stoppe les 8 Pdef du moteur d'un coup
~allOn = {
    ~loopEngineSyms.do { |sym|
        var voice = sym.asString.replace("Seq", "").asSymbol;
        var loopName = (voice.asString ++ "Loop").asSymbol;
        ~loopOn.(loopName, sym);
    };
    "[loop] allOn (8 voies moteur)".postln;
};

~allOff = {
    ~loopEngineSyms.do { |sym|
        var voice = sym.asString.replace("Seq", "").asSymbol;
        var loopName = (voice.asString ++ "Loop").asSymbol;
        if (~loops[loopName].notNil and: { ~loops[loopName][\state] == \on }) {
            ~loopOff.(loopName);
        };
    };
    // Coupe aussi les Pdef directement, au cas ou on n'est pas passe
    // par ~loopOn (compatibilite avec l'ancien workflow PLAY)
    ~loopEngineSyms.do { |sym| Pdef(sym).stop };
    "[loop] allOff (8 voies moteur)".postln;
};

"[loops] gestionnaire pret -- ~loopList ~loopProgress ~allOn ~allOff".postln;
)


// =====================================================================
//  EXEMPLES (Cmd+Entree sur une parenthese)
// =====================================================================
//
// // --- Boucles simples sur les Pdef du moteur -----------------------
// ( ~kickLoop.(); )                  // kick infini
// ( ~hatLoop.(16); )                 // hat sur 16 beats
// ( ~loopOff.(\kickLoop); )
// ( ~allOn.(); )                     // les 8 voies du moteur
// ( ~allOff.(); )
//
// // --- Boucles sur fonctions custom ---------------------------------
// ( ~loopOn.(\blip, { 8.do { |i| (instrument: \pluck, midinote: 60+i).play; 0.25.wait } }); )
// ( ~loopOff.(\blip); )
//
// // --- Repeat / countdown -------------------------------------------
// ( ~loopRepeat.(\drop, \kickSeq, 4, 4); )    // 4 fois 4 beats
// ( ~loopWithCountdown.(\intro, \melodySeq, 4, inf); )
// ( ~loopCountdown.(4, { "drop !".postln }); )
//
// // --- Tempo-sync ---------------------------------------------------
// ( ~loopBeats.(\stab, \snareSeq, 8); )
// ( ~loopBars.(\verse, \melodySeq, 4); )      // 4 mesures
// ( ~loopSync.(); )                           // resync au temps fort
//
// // --- Compositions -------------------------------------------------
// ( ~loopChain.([
//     [\a, \kickSeq, 8],
//     [\b, \snareSeq, 8],
//     [\c, \melodySeq, 16]
// ]); )
// ( ~loopParallel.([[\k, \kickSeq], [\h, \hatSeq], [\m, \melodySeq]]); )
// ( ~loopFade.(\kickLoop, 2); )
// ( ~loopFadeIn.(\melodyLoop, \melodySeq, 4); )
//
// // --- Compteurs ----------------------------------------------------
// ( ~loopCount.(\drop).postln; )
// ( ~loopReset.(\drop); )
// ( ~loopMax.(\drop, 8); )
//
// // --- Auto-stop / auto-fade ----------------------------------------
// ( ~loopAutoStop.(\kickLoop, 32); )
// ( ~loopAutoFade.(\acidLoop, 16, 2); )
//
// // --- Snapshot / restore -------------------------------------------
// ( ~loopSnapshot.(\acidLoop); )
// ( ~loopRestore.(\acidLoop); )
// ( ~loopSave.(\acidLoop); )
// ( ~loopLoad.(\acidLoop); )
//
// // --- Affichage ----------------------------------------------------
// ( ~loopList.(); )
// ( ~loopProgress.(); )
// ( ~loopShow.(); )
// ( ~loopInfo.(\kickLoop); )
// ( ~loopIsOn.(\kickLoop).postln; )
//
// =====================================================================

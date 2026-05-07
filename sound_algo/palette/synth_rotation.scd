// =====================================================================
//  synth_rotation.scd  --  Rotation auto entre les versions de SynthDef
//
//  La palette dispose de ~20 versions de chaque SynthDef (acid_v1..v19,
//  bass808_v1..v19, lead_v1..v19, etc.) qui sont sous-utilisees parce
//  que les tracks figent l'instrument. Ce module fournit un Pfunc qui
//  cycle/randomise sur des banques par categorie, chaque N notes.
//
//  USAGE :
//    ~rotateAcid.value     -> Pfunc qui renvoie un nom \acid_vXX
//    ~rotateLead.value     -> idem pour lead
//    ~rotateBass.value     -> idem pour bass808
//    ~setRotationOn.(true) -> active toutes les rotations
//    ~setRotationOn.(false)-> revient aux SynthDefs canoniques
//
//  Integration : remplacer dans engine.scd
//    \instrument, \acid                       ->  \instrument, ~rotateAcid.value
//    \instrument, ~melodyInst                 ->  \instrument, ~rotateMelody.value
//
// =====================================================================

(
~rotationOn = ~rotationOn ? false;     // OFF par defaut, opt-in
~rotationEvery = ~rotationEvery ? 8;   // change tous les N events

~setRotationOn = { |b|
    ~rotationOn = b;
    ("[rotation] " ++ if(b) {"ON"} {"OFF"} ++
        " (every " ++ ~rotationEvery ++ " events)").postln;
};

// Banques de versions pour chaque famille. On peut elargir/restreindre
// pour piloter le caractere global (ex: que des versions saturees).
~rotPoolAcid    = (1..19).collect { |i| ("acid_v"    ++ i).asSymbol };
~rotPoolBass    = (1..19).collect { |i| ("bass808_v" ++ i).asSymbol };
~rotPoolLead    = (1..19).collect { |i| ("lead_v"    ++ i).asSymbol };
~rotPoolPad     = (1..19).collect { |i| ("pad_v"     ++ i).asSymbol };
~rotPoolPluck   = (1..19).collect { |i| ("pluck_v"   ++ i).asSymbol };
~rotPoolKick    = (1..19).collect { |i| ("kick_v"    ++ i).asSymbol };
~rotPoolHat     = (1..19).collect { |i| ("hat_v"     ++ i).asSymbol };
~rotPoolSnare   = (1..19).collect { |i| ("snare_v"   ++ i).asSymbol };

// Compteur global d'events pour switch synchro.
~rotIdx = ~rotIdx ? 0;

// Construit un Pfunc qui renvoie un instrument :
//   - default fallback si rotation OFF
//   - sinon : pioche dans le pool toutes les ~rotationEvery notes
~makeRotator = { |pool, fallback|
    Pfunc {
        if (~rotationOn and: { pool.size > 0 }) {
            // Index avance par groupe de ~rotationEvery
            var groupIdx = (~rotIdx div: ~rotationEvery) % pool.size;
            ~rotIdx = ~rotIdx + 1;
            // Verifie que le SynthDef existe avant de le renvoyer
            if (SynthDescLib.global.at(pool[groupIdx]).notNil) {
                pool[groupIdx]
            } { fallback }
        } { fallback }
    }
};

~rotateAcid   = { ~makeRotator.(~rotPoolAcid,   \acid) };
~rotateBass   = { ~makeRotator.(~rotPoolBass,   \bass808) };
~rotateLead   = { ~makeRotator.(~rotPoolLead,   \lead) };
~rotatePad    = { ~makeRotator.(~rotPoolPad,    \pad) };
~rotatePluck  = { ~makeRotator.(~rotPoolPluck,  \pluck) };
~rotateKick   = { ~makeRotator.(~rotPoolKick,   \kick) };
~rotateHat    = { ~makeRotator.(~rotPoolHat,    \hat) };
~rotateSnare  = { ~makeRotator.(~rotPoolSnare,  \snare) };

// Rotator generique pour la melody (utilise ~melodyInst comme fallback)
~rotateMelody = {
    Pfunc {
        if (~rotationOn) {
            // Choisit dans le pool correspondant a ~melodyInst
            var pool = (
                lead:    ~rotPoolLead,
                pad:     ~rotPoolPad,
                pluck:   ~rotPoolPluck,
            ).at(~melodyInst);
            if (pool.notNil and: { pool.size > 0 }) {
                var groupIdx = (~rotIdx div: ~rotationEvery) % pool.size;
                ~rotIdx = ~rotIdx + 1;
                pool[groupIdx]
            } { ~melodyInst }
        } { ~melodyInst }
    }
};

"[synth_rotation] loaded - ~setRotationOn.(true) to enable".postln;
)

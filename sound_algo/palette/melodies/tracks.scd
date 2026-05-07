// =====================================================================
//  palette/melodies/tracks.scd
//  Systeme multi-pistes melodiques  --  jusqu'a N voix simultanees.
//
//  Le legacy \melodySeq de engine.scd continue a fonctionner ; ce
//  systeme s'AJOUTE en parallele. Chaque piste a son propre Pdef
//  (\<name>Seq) construit a partir d'un Event de parametres stocke
//  dans ~mel[\name].
//
//  HELPERS EXPOSES
//    ~melTrackAdd.(\name, params)       cree une piste + Pdef
//    ~melTrackRemove.(\name)            stop + remove
//    ~melTrackOn.(\name) / Off          play / stop
//    ~melTrackSet.(\name, key, val)     edite un param + reload Pdef
//    ~melTrackSetAll.(\name, params)    edite plusieurs params en bloc
//    ~melTrackList.()                   etat de toutes les pistes
//    ~melTrackSolo.(\name) / Unsolo     mute toutes sauf une
//    ~melTrackChoke.()                  stop toutes
//    ~melTrackReload.(\name) / All
//    ~melTrackHarm.(\src, \dst, \pres)  ajoute une harmonie auto
//    ~melTrackByGenre.(\name, \genre)   melodie aleatoire du melodyBank
//
//  PARAMS d'une piste (Event) :
//    notes inst cutoff rq attack release drive amp dur boost pan octave
//
//  Charge en DERNIER par index.scd (apres scales/short/long/.../bank).
//  Un seul bloc top-level (compatible .load).
// =====================================================================
(
// ---------- Etat global ---------------------------------------------
~mel = ~mel ?? { () };          // dict des pistes melodiques (Event)
~melSoloed = ~melSoloed ?? { nil }; // backup amp pendant un solo

// ---------- Builder : construit (ou rebuild) le Pdef d'une piste ----
~melTrackBuildPdef = { |name|
    var t   = ~mel[name];
    var sym = (name.asString ++ "Seq").asSymbol;  // ex: \m1Seq
    if (t.isNil) {
        ("[melTrack] " ++ name ++ " inconnue").postln;
    } {
        // Defaults par champ : on guarantit que rien ne plante
        var notes   = (t[\notes]   ?? { (0 ! 32) });
        var inst    = (t[\inst]    ?? \pad);
        var cutoff  = (t[\cutoff]  ?? 2400);
        var rq      = (t[\rq]      ?? 0.5);
        var attack  = (t[\attack]  ?? 0.01);
        var release = (t[\release] ?? 0.3);
        var drive   = (t[\drive]   ?? 1.2);
        var amp     = (t[\amp]     ?? 0.14);
        var dur     = (t[\dur]     ?? 0.25);
        var boost   = (t[\boost]   ?? 1.0);
        var pan     = (t[\pan]     ?? 0);
        var octave  = (t[\octave]  ?? 0);
        var sawAmt  = (t[\sawAmt]  ?? 0.6);
        var detune  = (t[\detune]  ?? 0.006);
        var subAmt  = (t[\subAmt]  ?? 0.4);
        if (notes.isEmpty) { notes = (0 ! 32) };
        Pdef(sym, Pbind(
            \instrument, inst, \dur, dur,
            \legato,   0.9,
            \type,     Pseq(notes.collect { |n| if(n > 0) { \note } { \rest } }, inf),
            \midinote, Pseq(notes.collect { |n| if(n > 0) { n + (octave * 12) } { 60 } }, inf),
            \cutoff,   cutoff,
            \rq,       rq,
            \attack,   attack,
            \release,  release,
            \drive,    drive,
            \sawAmt,   sawAmt,
            \detune,   detune,
            \subAmt,   subAmt,
            \pan,      pan,
            \amp,      amp * boost,
            \scBus,    if (~scBus.notNil) { ~scBus.index } { 0 },
            \scAmt,    (~leadScAmt ?? 0.5),
        ));
        sym
    };
};

// ---------- ADD : enregistre (ou met a jour) une piste --------------
~melTrackAdd = { |name, params|
    var existing = ~mel[name];
    var p = params ?? { () };
    if (existing.isNil) {
        ~mel[name] = p;
    } {
        // Merge : on garde l'ancien et on ecrase avec les nouveaux champs
        p.keysValuesDo { |k, v| existing[k] = v };
        ~mel[name] = existing;
    };
    ~melTrackBuildPdef.(name);
    ("[melTrack] add " ++ name).postln;
    name
};

// ---------- REMOVE : stop + supprime du dict ------------------------
~melTrackRemove = { |name|
    var sym = (name.asString ++ "Seq").asSymbol;
    Pdef(sym).stop;
    Pdef(sym).clear;
    ~mel[name] = nil;
    ("[melTrack] remove " ++ name).postln;
};

// ---------- ON / OFF -----------------------------------------------
~melTrackOn = { |name|
    var sym = (name.asString ++ "Seq").asSymbol;
    if (~mel[name].isNil) {
        ("[melTrack] " ++ name ++ " inconnue").postln;
    } {
        ~melTrackBuildPdef.(name);
        Pdef(sym).play;
        ("[melTrack] ON  " ++ name).postln;
    };
};
~melTrackOff = { |name|
    var sym = (name.asString ++ "Seq").asSymbol;
    Pdef(sym).stop;
    ("[melTrack] OFF " ++ name).postln;
};

// ---------- SET / SETALL : edition + rebuild ------------------------
~melTrackSet = { |name, key, val|
    var t = ~mel[name];
    if (t.isNil) {
        ("[melTrack] " ++ name ++ " inconnue").postln;
    } {
        t[key] = val;
        ~melTrackBuildPdef.(name);
        ("[melTrack] " ++ name ++ " ." ++ key ++ " = " ++ val).postln;
    };
};
~melTrackSetAll = { |name, params|
    var t = ~mel[name];
    if (t.isNil) {
        ("[melTrack] " ++ name ++ " inconnue").postln;
    } {
        params.keysValuesDo { |k, v| t[k] = v };
        ~melTrackBuildPdef.(name);
        ("[melTrack] " ++ name ++ " setAll " ++ params.keys.asArray).postln;
    };
};

// ---------- LIST ----------------------------------------------------
~melTrackList = {
    "=== melodic tracks ===".postln;
    if (~mel.isEmpty) {
        "  (aucune piste)".postln;
    } {
        ~mel.keysValuesDo { |k, v|
            var sym = (k.asString ++ "Seq").asSymbol;
            // Pdef.player vaut nil si jamais joue, sinon a un EventStreamPlayer.
            var pl  = Pdef(sym).player;
            var st  = if (pl.notNil and: { pl.isPlaying }) { "ON " } { "off" };
            ("  [" ++ st ++ "] " ++ k
                ++ "  inst=" ++ (v[\inst] ? \unknown)
                ++ "  amp="  ++ (v[\amp]  ? \unknown)
                ++ "  oct="  ++ (v[\octave] ? 0)
                ++ "  notes=" ++ (v[\notes].notNil.if({v[\notes].size}, {0})) ++ "n"
            ).postln;
        };
    };
};

// ---------- SOLO / UNSOLO ------------------------------------------
~melTrackSolo = { |name|
    if (~mel[name].isNil) {
        ("[melTrack] solo : " ++ name ++ " inconnue").postln;
    } {
        // Backup amp courant avant le solo (si pas deja en solo)
        if (~melSoloed.isNil) {
            ~melSoloed = ();
            ~mel.keysValuesDo { |k, v| ~melSoloed[k] = (v[\amp] ? 0) };
        };
        ~mel.keysValuesDo { |k, v|
            if (k != name) {
                v[\amp] = 0;
                ~melTrackBuildPdef.(k);
            };
        };
        ("[melTrack] solo " ++ name).postln;
    };
};
~melTrackUnsolo = {
    if (~melSoloed.isNil) {
        "[melTrack] pas de solo actif".postln;
    } {
        ~melSoloed.keysValuesDo { |k, v|
            if (~mel[k].notNil) {
                ~mel[k][\amp] = v;
                ~melTrackBuildPdef.(k);
            };
        };
        ~melSoloed = nil;
        "[melTrack] unsolo (amps restaures)".postln;
    };
};

// ---------- CHOKE : stop tout ---------------------------------------
~melTrackChoke = {
    ~mel.keysDo { |k|
        var sym = (k.asString ++ "Seq").asSymbol;
        Pdef(sym).stop;
    };
    "[melTrack] choke (toutes les pistes off)".postln;
};

// ---------- RELOAD --------------------------------------------------
~melTrackReload = { |name|
    if (~mel[name].isNil) {
        ("[melTrack] reload : " ++ name ++ " inconnue").postln;
    } {
        ~melTrackBuildPdef.(name);
        ("[melTrack] reload " ++ name).postln;
    };
};
~melTrackReloadAll = {
    ~mel.keysDo { |k| ~melTrackBuildPdef.(k) };
    ("[melTrack] reloadAll (" ++ ~mel.size ++ " pistes)").postln;
};

// ---------- HARMONIE AUTO : derive une piste d'une autre -----------
//   ~melTrackHarm.(\src, \dst, \preset)
//   presets : \third \fifth \sixth \octave \counter \bassline \arp
~melTrackHarm = { |srcName, dstName, preset = \third|
    var src = ~mel[srcName];
    if (src.isNil) {
        ("[melTrack] harm : src " ++ srcName ++ " inconnue").postln;
    } {
        var srcNotes = src[\notes] ?? { (0 ! 32) };
        var dstNotes, dstInst, dstAmp, dstDur, dstAttack, dstRelease;
        switch (preset,
            \third, {
                dstNotes = (~genThirdHarmony ?? {{ |m, s = 4| m.collect { |n| if(n>0){n+s}{0} } }}).(srcNotes);
                dstInst = \warmPad; dstAmp = 0.12; dstDur = 0.25;
                dstAttack = 0.3; dstRelease = 1.2;
            },
            \fifth, {
                dstNotes = (~genFifthHarmony ?? {{ |m| m.collect { |n| if(n>0){n+7}{0} } }}).(srcNotes);
                dstInst = \warmPad; dstAmp = 0.12; dstDur = 0.25;
                dstAttack = 0.3; dstRelease = 1.2;
            },
            \sixth, {
                dstNotes = srcNotes.collect { |n| if (n > 0) { n + 9 } { 0 } };
                dstInst = \warmPad; dstAmp = 0.12; dstDur = 0.25;
                dstAttack = 0.3; dstRelease = 1.2;
            },
            \octave, {
                dstNotes = srcNotes.collect { |n| if (n > 0) { n + 12 } { 0 } };
                dstInst = \organLead; dstAmp = 0.12; dstDur = 0.25;
                dstAttack = 0.005; dstRelease = 0.2;
            },
            \counter, {
                dstNotes = (~genCounterMelody
                    ?? {{ |m, p = 132| m.collect { |n| if(n>0){(p-n).max(48).min(96)}{0} } }}
                ).(srcNotes);
                dstInst = \pluck; dstAmp = 0.13; dstDur = 0.25;
                dstAttack = 0.005; dstRelease = 0.4;
            },
            \bassline, {
                dstNotes = srcNotes.collect { |n| if (n > 0) { (n - 24).max(24) } { 0 } };
                dstInst = \subBoom; dstAmp = 0.30; dstDur = 0.5;
                dstAttack = 0.005; dstRelease = 0.6;
            },
            \arp, {
                dstNotes = srcNotes.collect { |n| if (n > 0) { n + 12 } { 0 } };
                dstInst = \pluck; dstAmp = 0.13; dstDur = 0.125;
                dstAttack = 0.001; dstRelease = 0.2;
            }
        );
        ~melTrackAdd.(dstName, (
            notes: dstNotes, inst: dstInst, amp: dstAmp, dur: dstDur,
            attack: dstAttack, release: dstRelease,
            cutoff: 2500, rq: 0.5, drive: 1.2, boost: 1.0, pan: 0, octave: 0
        ));
        ("[melTrack] harm " ++ srcName ++ " -> " ++ dstName ++ " (" ++ preset ++ ")").postln;
    };
};

// ---------- LIEN MELODYBANK : tirage par genre ----------------------
~melTrackByGenre = { |name, genre|
    var pool = ~melodyBank !? { ~melodyBank[genre] };
    if (pool.isNil or: { pool.size == 0 }) {
        ("[melTrack] byGenre : " ++ genre ++ " inconnu / vide").postln;
    } {
        var key = pool.choose;
        var notes = currentEnvironment[key];
        if (notes.notNil and: { notes.isArray }) {
            if (~mel[name].isNil) {
                ~melTrackAdd.(name, (notes: notes.copy));
            } {
                ~mel[name][\notes] = notes.copy;
                ~melTrackBuildPdef.(name);
            };
            ("[melTrack] byGenre " ++ name ++ " <- " ++ genre ++ "/" ++ key).postln;
        } { ("[melTrack] byGenre : " ++ key ++ " inconnue").postln };
    };
};

// ---------- 3 PISTES PAR DEFAUT (inactives) -------------------------
//   m1 = lead pad, m2 = counter pluck, m3 = sub boom
~melTrackAdd.(\m1, (
    notes: (~m1 ?? { (0 ! 32) }).copy,
    inst: \pad, cutoff: 2400, rq: 0.5,
    attack: 0.4, release: 1.5, drive: 1.0,
    amp: 0.14, dur: 0.25, boost: 1.0, pan: 0, octave: 0
));
~melTrackAdd.(\m2, (
    notes: (~m25 ?? { (0 ! 32) }).copy,
    inst: \pluck, cutoff: 4500, rq: 0.5,
    attack: 0.005, release: 0.4, drive: 1.0,
    amp: 0.12, dur: 0.25, boost: 1.0, pan: -0.3, octave: 0
));
~melTrackAdd.(\m3, (
    notes: (~m31 ?? { (0 ! 32) }).copy,
    inst: \subBoom, cutoff: 800, rq: 0.4,
    attack: 0.005, release: 0.6, drive: 1.2,
    amp: 0.25, dur: 0.5, boost: 1.0, pan: 0, octave: -1
));

"[melodies/tracks] systeme multi-pistes pret -- 3 pistes par defaut (m1 m2 m3, off). ~melTrackOn.(\\m1) pour lancer.".postln;
)

// =====================================================================
//  web_bridge.scd  --  Pont OSC vers le serveur web (sound-algo-web)
//
//  Le serveur Node.js (web/server.js) ecoute sur :57121 et nous envoie
//  les messages /control/... que la surface de controle declenche.
//  Nous lui renvoyons /sync/... (BPM, beats, amplitudes RMS par voie)
//  pour synchroniser le canvas Hydra avec le son.
//
//  PREREQUIS :
//    - 01_live.scd > bloc [0] charge (engine + setupAll + wrappers)
//    - web/node_modules installes (npm install fait une fois)
//
//  USAGE :
//    Cmd+Entree sur le bloc ci-dessous : enregistre les OSCdef.
//    Le serveur Node n'est PAS demarre automatiquement (relire le
//    fichier ne relance pas Node a chaque fois).
//      ~webStart.value          -- demarre Node + ouvre /control + /hydra
//      ~webBridgeStop.value     -- ferme les OSCdef SC
//      ~webServerStop.value     -- tue le serveur Node
//      ~webOpenPages.value      -- ouvre /control + /hydra a la main
// =====================================================================
(
// Idempotence : si on relit le fichier, on ferme l'ancien etat OSC
~webBridgeStop !? { ~webBridgeStop.value };

~webBridgeNode = NetAddr("127.0.0.1", 57122);    // <- vers le serveur Node
~webBridgeIn   = 57121;                          // <- ecoute du serveur
thisProcess.openUDPPort(~webBridgeIn);

// Relais additionnels pour oscope-of (openFrameworks visualizer) sur :57123.
// Tout /sync/* envoye au Node est aussi diffuse a ces adresses.
~webBridgeRelays = [NetAddr("127.0.0.1", 57123)];

// Wrapper d'envoi : Node + tous les relais
~webBroadcast = { |path ...args|
    ~webBridgeNode.sendMsg(path, *args);
    ~webBridgeRelays.do { |addr| addr.sendMsg(path, *args) };
};

~webBase = ~base ?? { "/Users/electron/Documents/Projets_Creatifs/sound_algo-refonte-v2/" };
~webHttpUrl = "http://localhost:3000";

// ---------- Auto-lancement serveur Node + ouverture pages -----------
~webServerCheck = {
    ("curl -sf " ++ ~webHttpUrl ++ "/api/health > /dev/null 2>&1").systemCmd == 0;
};

~webOpenUrl = { |url|
    var cmd = switch (thisProcess.platform.name,
        \osx,    "open " ++ url,
        \linux,  "xdg-open " ++ url,
        \windows, "start " ++ url,
        "open " ++ url
    );
    cmd.unixCmd;
};

~webOpenPages = {
    "[web_bridge] ouverture des pages...".postln;
    ~webOpenUrl.(~webHttpUrl ++ "/control/");
    ~webOpenUrl.(~webHttpUrl ++ "/hydra/");
};

~webServerStart = {
    var webDir = ~webBase ++ "web";
    if (~webServerCheck.()) {
        "[web_bridge] serveur Node deja actif sur :3000".postln;
        ~webOpenPages.();
    } {
        "[web_bridge] demarrage serveur Node en background...".postln;
        ("cd " ++ webDir.shellQuote
            ++ " && nohup node server.js > /tmp/sound_algo_web.log 2>&1 &"
        ).unixCmd;
        Routine({
            var tries = 20, ready = false;
            while { tries > 0 and: { ready.not } } {
                0.5.wait;
                ready = ~webServerCheck.();
                tries = tries - 1;
            };
            if (ready) {
                "[web_bridge] serveur Node ready".postln;
                ~webOpenPages.();
            } {
                "[web_bridge] !! timeout au demarrage du serveur Node".postln;
                "[web_bridge] !! voir /tmp/sound_algo_web.log".postln;
            };
        }).play(AppClock);
    };
};

~webServerStop = {
    "pkill -f 'node server.js' 2>/dev/null".unixCmd;
    "[web_bridge] serveur Node stoppe (pkill node server.js)".postln;
};

// Helper unique pour lancer Node + ouvrir les pages
~webStart = { ~webServerStart.value; };

// ---------- Broadcast steps/notes vers le browser -------------------
~webBroadcastSteps = {
    var binVoices = [\kick, \hat, \snare, \clap, \perc];
    var binSyms   = [\kickSteps, \hatSteps, \snareSteps, \clapSteps, \percSteps];
    var noteVoices = [\acid, \melody, \harmony];
    var noteSyms   = [\acidNotes, \melodyNotes, \harmonyNotes];
    var accents = (~acidAccents ? (0!16)).asArray.collect(_.asInteger);
    var slides  = (~acidSlides  ? (0!16)).asArray.collect(_.asInteger);
    binVoices.do { |v, i|
        var arr = (currentEnvironment[binSyms[i]] ? (0!16)).asArray.collect(_.asInteger);
        ~webBroadcast.value(*(["/sync/steps", v.asString] ++ arr));
    };
    noteVoices.do { |v, i|
        var arr = (currentEnvironment[noteSyms[i]] ? (0!16)).asArray.collect(_.asInteger);
        ~webBroadcast.value(*(["/sync/notes", v.asString] ++ arr));
    };
    // Acid : accents + slides + params (cutoff/rq/drive/amp)
    ~webBroadcast.value(*(["/sync/acidAccents"] ++ accents));
    ~webBroadcast.value(*(["/sync/acidSlides"]  ++ slides));
    ~webBroadcast.value("/sync/acidParams",
        (~acidCutoff ? 800).asFloat,
        (~acidRq ? 0.15).asFloat,
        (~acidDrive ? 2.0).asFloat,
        (~acidAmp ? 0.3).asFloat);
    ~webBroadcast.value("/sync/harmonyAmp", (~harmonyAmp ? 0.14).asFloat);
};

// ---------- Helpers de dispatch --------------------------------------
~webBridgeDefs = List.new;

// Wrapper protege : toute exception dans une action ne tue pas l'OSCdef
~webBridgeAdd = { |path, action|
    var key = ("web_" ++ path.replace("/", "_")).asSymbol;
    var safe = { |msg, time, addr, recvPort|
        try {
            action.value(msg, time, addr, recvPort);
        } { |err|
            ("[web_bridge] " ++ path ++ " err: " ++ err.errorString).postln;
        };
    };
    var def = OSCdef(key, safe, path, recvPort: ~webBridgeIn);
    ~webBridgeDefs.add(def);
    def;
};

~webBridgeStop = {
    ~webBridgeDefs.do(_.free);
    ~webBridgeDefs = List.new;
    ~webBeatRoutine !? { ~webBeatRoutine.stop; ~webBeatRoutine = nil };
    ~webAmpRoutine  !? { ~webAmpRoutine.stop;  ~webAmpRoutine  = nil };
    ~webBpmReloadTask !? { ~webBpmReloadTask.stop; ~webBpmReloadTask = nil };
    ~webStepReloadTask !? { ~webStepReloadTask.stop; ~webStepReloadTask = nil };
    // Restaure ~reload si wrappe par ce module
    ~webReloadOriginal !? {
        ~reload = ~webReloadOriginal;
        ~webReloadOriginal = nil;
    };
    "[web_bridge] OSCdef + Routines stopped (serveur Node toujours actif, ~webServerStop pour tuer)".postln;
};

// ---------- Debounce helper (200ms) ---------------------------------
// Utilise une Task qu'on reschedule -- le compteur est l'identite de
// la Task : seule la derniere lancee survit jusqu'a l'execution.
~webDebounce = { |slot, delay, action|
    currentEnvironment[slot] !? { currentEnvironment[slot].stop };
    currentEnvironment[slot] = Task({
        delay.wait;
        try { action.value } { |err|
            ("[web_bridge] debounce " ++ slot ++ " err: " ++ err.errorString).postln;
        };
        currentEnvironment[slot] = nil;
    }).play(AppClock);
};

// ---------- Transport ------------------------------------------------
~webBridgeAdd.("/control/bpm", { |msg|
    ~bpm = msg[1];
    TempoClock.default.tempo = ~bpm / 60;
    // Debounce reload : evite de reload a chaque tick du slider
    ~webDebounce.(\webBpmReloadTask, 0.2, { ~reload.value });
    ~webBroadcast.value("/sync/bpm", ~bpm);
});

~webBridgeAdd.("/control/masterVol", { |msg|
    ~masterVol.(msg[1]);
});

~webBridgeAdd.("/control/masterFadeOut", { |msg|
    ~masterFadeOut.(msg[1] ? 8);
});

~webBridgeAdd.("/control/teardown", { ~teardown.() });

// Reboot juste scsynth (audio engine). Conserve l'etat sclang
// (catalogues, dicts, OSCdef). Le client web doit re-emettre
// listAlbums/Sections apres ~5s via le retry persistant.
~webBridgeAdd.("/control/rebootServer", {
    "[web_bridge] /control/rebootServer reçu — quit puis ~setupAll".postln;
    Routine({
        Server.default.quit;
        2.wait;
        ~setupAll_done = nil;
        ~setupAll.();
    }).play(AppClock);
});

// Reboot serveur web (Node) : ecrit un sentinel que le launcher
// surveille. sclang reste en vie, juste le serveur Node redemarre.
~webBridgeAdd.("/control/rebootWeb", {
    var sentinel;
    "[web_bridge] /control/rebootWeb reçu — relance Node...".postln;
    sentinel = Platform.userHomeDir ++ "/.av-live-restart-web";
    File.use(sentinel, "w") { |f| f.write("1") };
});

// ---------- Live tab : triggers FX one-shot ------------------------
// /control/triggerSynth <name> -- joue un Synth one-shot du catalogue
// trick : impact / riser / sweep / crash / gong / ...
~webBridgeAdd.("/control/triggerSynth", { |msg|
    var name = msg[1].asString.asSymbol;
    {
        Synth(name, [\decay, 2, \amp, 0.5]);
    }.try { |err|
        ("[web_bridge] triggerSynth " ++ name ++ " : " ++ err.errorString).postln;
    };
});

~webBridgeAdd.("/control/snareFill", {
    currentEnvironment[\snareFill] !? { ~snareFill.value }
        ?? { "[web_bridge] ~snareFill n/a".postln };
});
~webBridgeAdd.("/control/tomFill", {
    currentEnvironment[\tomFill] !? { ~tomFill.value }
        ?? { "[web_bridge] ~tomFill n/a".postln };
});
~webBridgeAdd.("/control/randomTweak", {
    currentEnvironment[\randomTweak] !? { ~randomTweak.value }
        ?? { "[web_bridge] ~randomTweak n/a".postln };
});

// Reboot complet sclang : suicide via pkill, le launcher detecte
// l'exit et relance sclang via terminationHandler + wantsAutoRestart.
~webBridgeAdd.("/control/rebootSclang", {
    "[web_bridge] /control/rebootSclang reçu — sclang suicide en 0.5s...".postln;
    AppClock.sched(0.5, {
        // Touche un fichier sentinel que le launcher surveille
        var sentinel = Platform.userHomeDir ++ "/.av-live-restart-sclang";
        File.use(sentinel, "w") { |f| f.write("1") };
        // Puis suicide
        "pkill -TERM -f 'sclang.*boot.scd' 2>/dev/null".unixCmd;
        nil;
    });
});

// ---------- Mixer ----------------------------------------------------
~webBridgeAdd.("/control/setVol", { |msg|
    ~setVol.(msg[1].asString.asSymbol, msg[2]);
});

~webBridgeAdd.("/control/mute",   { |msg| ~mute.(msg[1].asString.asSymbol) });
~webBridgeAdd.("/control/unmute", { |msg| ~unmute.(msg[1].asString.asSymbol) });
~webBridgeAdd.("/control/solo",   { |msg| ~solo.(msg[1].asString.asSymbol) });
~webBridgeAdd.("/control/unsolo", { ~unsolo.() });

// ---------- Kicks / Patterns / FX preset -----------------------------
~webBridgeAdd.("/control/kk", { |msg| ~kk.(msg[1].asString.asSymbol) });
~webBridgeAdd.("/control/pKit",   { |msg| ~pKit.(msg[1].asString.asSymbol) });
~webBridgeAdd.("/control/pGenre", { |msg| ~pGenre.(msg[1].asString.asSymbol) });
~webBridgeAdd.("/control/ff",     { |msg| ~ff.(msg[1].asString.asSymbol) });

// ---------- Step sequencer (8 voies x 16 pas) -----------------------
// Voies drums + 3 voies melodiques (acid/melody/harmony)
[\kickSteps, \hatSteps, \snareSteps, \clapSteps, \percSteps,
 \melodySteps, \harmonySteps, \acidSteps].do { |sym|
    ~webBridgeAdd.("/control/" ++ sym.asString, { |msg|
        var steps = msg[1..].asArray.collect(_.asInteger);
        currentEnvironment.put(sym, steps);
        // Debounce reload : si l'UI envoie plusieurs voies a la suite
        ~webDebounce.(\webStepReloadTask, 0.2, { ~reload.value });
    });
};

// ---------- Acid / Harmony -------------------------------------------
// Acid : notes + accents + slides + cutoff/rq/drive/amp + random
~webBridgeAdd.("/control/acidNotes", { |msg|
    var arr = msg[1..].asArray.collect(_.asInteger);
    ~acidNotes = arr;
    ~reload.value;
});
~webBridgeAdd.("/control/acidAccents", { |msg|
    var arr = msg[1..].asArray.collect(_.asInteger);
    ~acidAccents = arr;
    ~reload.value;
});
~webBridgeAdd.("/control/acidSlides", { |msg|
    var arr = msg[1..].asArray.collect(_.asInteger);
    ~acidSlides = arr;
    ~reload.value;
});
~webBridgeAdd.("/control/acidCutoff", { |msg| ~acidCutoff = msg[1].asFloat; ~reload.value });
~webBridgeAdd.("/control/acidRq",     { |msg| ~acidRq     = msg[1].asFloat; ~reload.value });
~webBridgeAdd.("/control/acidDrive",  { |msg| ~acidDrive  = msg[1].asFloat; ~reload.value });
~webBridgeAdd.("/control/acidAmp",    { |msg| ~acidAmp    = msg[1].asFloat; ~reload.value });
~webBridgeAdd.("/control/acidRandom", { |msg|
    // msg[1]/msg[2] optionnels : seuils 0..1 pour densite accents/slides
    var accProb = (msg[1] ? 0.4).asFloat;
    var slidProb = (msg[2] ? 0.3).asFloat;
    if (~genAcidNotes.notNil) { ~acidNotes = ~genAcidNotes.value };
    if (~genAcidAccents.notNil) { ~acidAccents = ~genAcidAccents.(accProb) };
    if (~genAcidSlides.notNil) { ~acidSlides = ~genAcidSlides.(slidProb) };
    ~reload.value;
});

// Harmony : notes + amp + preset (off/third/fifth/octave/power/shell/sus2/sus4)
~webBridgeAdd.("/control/harmonyNotes", { |msg|
    var arr = msg[1..].asArray.collect(_.asInteger);
    ~harmonyNotes = arr;
    ~reload.value;
});
~webBridgeAdd.("/control/harmonyAmp", { |msg| ~harmonyAmp = msg[1].asFloat; ~reload.value });
~webBridgeAdd.("/control/harmonyPreset", { |msg|
    var preset = msg[1].asString.asSymbol;
    currentEnvironment[\enableHarmony] !? { ~enableHarmony.(preset) }
        ?? { ("[web_bridge] ~enableHarmony absent (preset=" ++ preset ++ ")").postln };
});

// ---------- FX par voie ----------------------------------------------
~webBridgeAdd.("/control/fxCut",   { |msg| ~fxCut.(msg[1].asString.asSymbol, msg[2]) });
~webBridgeAdd.("/control/fxDrive", { |msg| ~fxDrive.(msg[1].asString.asSymbol, msg[2]) });
~webBridgeAdd.("/control/fxRq",    { |msg| ~fxRq.(msg[1].asString.asSymbol, msg[2]) });

// ---------- LFO ------------------------------------------------------
~webBridgeAdd.("/control/lfoTo", { |msg|
    ~lfoTo.(msg[1].asString.asSymbol, msg[2], msg[3]);
});
~webBridgeAdd.("/control/lfoStop",    { |msg| ~lfoStopVar.(msg[1].asString.asSymbol) });
~webBridgeAdd.("/control/lfoStopAll", { ~lfoStopAllVars.() });

// ---------- Tricks sceniques -----------------------------------------
~webBridgeAdd.("/control/drop",        { ~drop.() });
~webBridgeAdd.("/control/breakdown",   { |msg| ~breakdown.(msg[1] ? 8) });
~webBridgeAdd.("/control/buildup",     { |msg| ~buildup.(msg[1] ? 8) });
~webBridgeAdd.("/control/glitch",      { |msg| ~glitch.(msg[1] ? 2) });
~webBridgeAdd.("/control/stutter",     { |msg| ~stutter.(msg[1] ? 8, msg[2] ? 1) });
~webBridgeAdd.("/control/freeze",      { ~freeze.() });
~webBridgeAdd.("/control/tapeStop",    { |msg| ~tapeStop.(msg[1] ? 2) });
~webBridgeAdd.("/control/tapeReverse", { |msg| ~tapeReverse.(msg[1] ? 4) });
~webBridgeAdd.("/control/handsUp",     { ~handsUp.() });
~webBridgeAdd.("/control/jumpCut",     { |msg| ~jumpCut.(msg[1] ? 0.5) });
~webBridgeAdd.("/control/bitCrushNow", { |msg|
    ~bitCrushNow.(msg[1] ? 6, msg[2] ? 6000, msg[3] ? 1);
});

// ---------- Navigation sections (jump.scd) ---------------------------
~webBridgeAdd.("/control/jumpTo", { |msg|
    var letter = msg[1].asString.asSymbol;
    var slug   = msg[2].asString.asSymbol;
    ~jumpTo.(letter, slug);
});

// Liste les sections disponibles : envoie /sync/sections (letter, slug1, slug2, ...) par lettre
~webBridgeAdd.("/control/listSections", {
    if (~sections.notNil) {
        var letters = ~sections.keys.asArray.sort;
        letters.do { |k|
            var slugs = ~sections[k].keys.asArray.collect(_.asString);
            ~webBroadcast.value(*(["/sync/sections", k.asString] ++ slugs));
        };
    } {
        "[web_bridge] ~sections n/a".postln;
    };
});

// ---------- Albums (tracks/_index.scd) -------------------------------
// Liste les albums disponibles : envoie /sync/album par lettre triee
// Format : letter, title, trackCount, totalSec, slug1, slug2, ...
~webBridgeAdd.("/control/listAlbums", {
    if (~albums.notNil) {
        var letters = ~albums.keys.asArray.sort;
        letters.do { |k|
            var alb = ~albums[k];
            var title = (alb[\title] ? "").asString;
            var tracks = (alb[\tracks] ? []).asArray;
            var durations = (alb[\durations] ? []).asArray;
            var trackCount = tracks.size;
            var totalSec = durations.sum.asInteger;
            var slugs = tracks.collect(_.asString);
            ~webBroadcast.value(*(["/sync/album", k.asString, title, trackCount, totalSec] ++ slugs));
        };
    } {
        "[web_bridge] albums non charges (load tracks/_index.scd)".postln;
    };
});

// Sync immediate des steps/notes (appele a la connexion WS du client)
~webBridgeAdd.("/control/getSteps", { ~webBroadcastSteps.() });

~webBridgeAdd.("/control/playTrack", { |msg|
    var letter = msg[1].asString.asSymbol;
    var n = msg[2].asInteger;
    currentEnvironment[\playTrack] !? { ~playTrack.(letter, n) }
        ?? { "[web_bridge] ~playTrack n/a".postln };
});

~webBridgeAdd.("/control/playAlbum", { |msg|
    var letter = msg[1].asString.asSymbol;
    var gap = msg[2] ? 8;
    currentEnvironment[\playAlbum] !? { ~playAlbum.(letter, gap) }
        ?? { "[web_bridge] ~playAlbum n/a".postln };
});

~webBridgeAdd.("/control/stopAlbum", {
    currentEnvironment[\stopAlbum] !? { ~stopAlbum.() }
        ?? { "[web_bridge] ~stopAlbum n/a".postln };
});

// === Humanity controls : humanize / rotation / auto-layer ===
// Toggles via 1.0/0.0 ; quand toggle change, on rappelle ~reload pour
// que le moteur applique les nouveaux Pfunc factories.
~webBridgeAdd.("/control/setHumanize", { |msg|
    var on = (msg[1] ? 1).asFloat > 0.5;
    ~humanizeOn = on;
    ("[web_bridge] humanize " ++ if(on) {"ON"} {"OFF"}).postln;
    ~reload !? { ~reload.value };
});
~webBridgeAdd.("/control/setRotation", { |msg|
    var on = (msg[1] ? 1).asFloat > 0.5;
    ~setRotationOn !? { ~setRotationOn.(on) }
        ?? { "[web_bridge] ~setRotationOn n/a".postln };
});
~webBridgeAdd.("/control/setLayer", { |msg|
    var on = (msg[1] ? 1).asFloat > 0.5;
    ~setAutoLayer !? { ~setAutoLayer.(on) }
        ?? { "[web_bridge] ~setAutoLayer n/a".postln };
});
// Tunables fins (en flottants 0..1)
~webBridgeAdd.("/control/humanizeTiming", { |msg|
    ~humanizeTiming = (msg[1] ? 0.0035).asFloat.clip(0.0, 0.05);
    ~reload !? { ~reload.value };
});
~webBridgeAdd.("/control/humanizeVelocity", { |msg|
    ~humanizeVelocity = (msg[1] ? 0.10).asFloat.clip(0.0, 0.5);
    ~reload !? { ~reload.value };
});
~webBridgeAdd.("/control/humanizeDetune", { |msg|
    ~humanizeDetune = (msg[1] ? 0.03).asFloat.clip(0.0, 0.5);
    ~reload !? { ~reload.value };
});
// Layer config par-album (signature)
~webBridgeAdd.("/control/layerSet", { |msg|
    // /control/layerSet <melodyInst> <melodyAmp> <melodyOctave>
    //                   <harmonyInst> <harmonyAmp>
    //                   <acidInst> <acidAmp> <acidOctave>
    msg[1] !? { ~layerMelodyInst   = msg[1].asString.asSymbol };
    msg[2] !? { ~layerMelodyAmp    = msg[2].asFloat };
    msg[3] !? { ~layerMelodyOctave = msg[3].asInteger };
    msg[4] !? { ~layerHarmonyInst  = msg[4].asString.asSymbol };
    msg[5] !? { ~layerHarmonyAmp   = msg[5].asFloat };
    msg[6] !? { ~layerAcidInst     = msg[6].asString.asSymbol };
    msg[7] !? { ~layerAcidAmp      = msg[7].asFloat };
    msg[8] !? { ~layerAcidOctave   = msg[8].asInteger };
    "[web_bridge] layer config updated".postln;
});

// ---------- Chains scenes (control/chain.scd) ------------------------
~webBridgeAdd.("/control/chain", { |msg|
    var name = msg[1].asString.asSymbol;
    var opt  = msg[2];
    switch (name,
        \intro,     { ~chIntro.() },
        \drop,      { ~chDrop.() },
        \breakdown, { ~chBreakdown.() },
        \buildup,   { ~chBuildup.(opt ? 8) },
        \techno,    { ~chTechno.(opt ? 4) },
        \dnb,       { ~chDnb.(opt ? 4) },
        \outroFade, { ~chOutroFade.(opt ? 16) },
        \stop,      { ~chStop.() },
        { ("[web_bridge] chain inconnue: " ++ name).postln }
    );
});

// ---------- Pdef control --------------------------------------------
~webBridgeAdd.("/control/playPdef", { |msg|
    Pdef(msg[1].asString.asSymbol).play(TempoClock.default, quant: 4);
});
~webBridgeAdd.("/control/stopPdef", { |msg|
    Pdef(msg[1].asString.asSymbol).stop;
});
~webBridgeAdd.("/control/playAll", {
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq,
     \acidSeq, \melodySeq, \harmonySeq].do { |n|
        Pdef(n).play(TempoClock.default, quant: 4);
    };
});
~webBridgeAdd.("/control/stopAll", {
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq,
     \acidSeq, \melodySeq, \harmonySeq].do { |n| Pdef(n).stop };
});

// ---------- Melodies API (~m / ~mInst / ...) -------------------------
~webBridgeAdd.("/control/mApply", { |msg|
    var kind = msg[1].asString.asSymbol;
    var n    = msg[2].asInteger;
    ~m[\apply].(kind, n);
});
~webBridgeAdd.("/control/mInst",  { |msg| ~mInst.(msg[1].asString.asSymbol) });
~webBridgeAdd.("/control/mAmp",   { |msg| ~mAmp.(msg[1]) });
~webBridgeAdd.("/control/mCut",   { |msg| ~mCut.(msg[1]) });
~webBridgeAdd.("/control/mDrive", { |msg| ~mDrive.(msg[1]) });
~webBridgeAdd.("/control/mOff",   { ~mOff.() });
~webBridgeAdd.("/control/mGen",   { |msg| ~mGen.(msg[1].asString.asSymbol) });
~webBridgeAdd.("/control/mNx",    { ~mNx.() });
~webBridgeAdd.("/control/mPv",    { ~mPv.() });

// ---------- Sends FX bus (rev/dly/chr/phs/flg/crsh/tape/shim/dist) ----
~webBridgeAdd.("/control/sendFx", { |msg|
    var bus = msg[1].asString.asSymbol;
    var amt = msg[2] ? 0.3;
    switch (bus,
        \rev,  { ~sendReverb.(amt) },
        \dly,  { ~sendDelay.(amt) },
        \chr,  { ~sendChorus.(amt) },
        \phs,  { ~sendPhaser.(amt) },
        \flg,  { ~sendFlanger.(amt) },
        \crsh, { ~sendBitcrush.(amt) },
        \tape, { ~sendTape.(amt) },
        \shim, { ~sendShimmer.(amt) },
        \dist, { ~sendDist.(amt) },
        { ("[web_bridge] sendFx bus inconnu: " ++ bus).postln }
    );
});

// ---------- VCF master (live/fx.scd) --------------------------------
~webBridgeAdd.("/control/vcfOn", { |msg|
    ~fxVcfOn.(msg[1].asString.asSymbol, msg[2] ? 1500, msg[3] ? 0.5);
});
~webBridgeAdd.("/control/vcfOff",    { ~fxVcfOff.() });
~webBridgeAdd.("/control/vcfFreq",   { |msg| ~fxVcfFreq.(msg[1] ? 1500) });
~webBridgeAdd.("/control/vcfQ",      { |msg| ~fxVcfQ.(msg[1] ? 0.5) });
~webBridgeAdd.("/control/vcfSweep",  { |msg|
    ~fxVcfSweep.(msg[1] ? 200, msg[2] ? 5000, msg[3] ? 4);
});
~webBridgeAdd.("/control/vcfPreset", { |msg| ~fxVcfPreset.(msg[1].asString.asSymbol) });

// ---------- Comp / Sat master ---------------------------------------
~webBridgeAdd.("/control/fxComp", { |msg|
    var preset = msg[1] !? { msg[1].asString.asSymbol } ?? \glue;
    ~fxComp.(preset);
});
~webBridgeAdd.("/control/fxSat", { |msg|
    var mode = msg[1].asString.asSymbol;
    var amt  = msg[2] ? 1.5;
    ~fxSat.(mode, amt);
});

// ---------- Scenes (live/scenes.scd) --------------------------------
~webBridgeAdd.("/control/saveScene", { |msg|
    currentEnvironment[\saveScene] !? { ~saveScene.(msg[1].asString.asSymbol) }
        ?? { "[web_bridge] ~saveScene n/a".postln };
});
~webBridgeAdd.("/control/loadScene", { |msg|
    currentEnvironment[\loadScene] !? { ~loadScene.(msg[1].asString.asSymbol) }
        ?? { "[web_bridge] ~loadScene n/a".postln };
});

// ---------- Tap tempo (optionnel) -----------------------------------
~webBridgeAdd.("/control/tap", {
    currentEnvironment[\tap] !? { ~tap.() }
        ?? { "[web_bridge] ~tap n/a".postln };
});

// ---------- Heartbeat ping/pong --------------------------------------
~webBridgeAdd.("/control/ping", {
    ~webBroadcast.value("/sync/pong", Main.elapsedTime);
});

// ---------- Catalogue : SynthDefs et melodies -----------------------
// /control/listSynthdefs : pour chaque categorie, envoie un message
//   /sync/synthdef <category> <name1> <name2> ... (tries alpha).
~webBridgeAdd.("/control/listSynthdefs", {
    var cats = ["drums", "bass", "lead", "pad", "world", "master"];
    cats.do { |cat|
        var dir = ~webBase ++ "synth/" ++ cat;
        var pn  = PathName(dir);
        var files = pn.files.select { |f| f.extension == "scd" };
        var names = files.collect { |f| f.fileNameWithoutExtension }.asArray.sort;
        ~webBroadcast.value(*(["/sync/synthdef", cat] ++ names));
    };
});

// /control/listMelodies : pour chaque genre du ~melodyBank, envoie
//   /sync/melody <genre> <name1> <name2> ...
~webBridgeAdd.("/control/listMelodies", {
    if (~melodyBank.notNil) {
        ~melodyBank.keys.asArray.sort.do { |g|
            var names = ~melodyBank[g].asArray.collect(_.asString);
            ~webBroadcast.value(*(["/sync/melody", g.asString] ++ names));
        };
    } {
        "[web_bridge] ~melodyBank non charge".postln;
    };
});

// /control/setMelody [name:str] : applique une melodie nommee a
//   ~melodyNotes. Utilise ~useMelody si dispo, sinon assigne direct.
~webBridgeAdd.("/control/setMelody", { |msg|
    var name = msg[1].asString.asSymbol;
    currentEnvironment[\useMelody] !? { ~useMelody.(name) } ?? {
        currentEnvironment[name] !? {
            ~melodyNotes = currentEnvironment[name].asArray;
            ~reload.value;
        } ?? { ("[web_bridge] melodie inconnue: " ++ name).postln };
    };
});

// ---------- Hook ~reload : broadcast auto des steps apres reload ----
// Wraper idempotent : si deja installe, on ne wrap pas a nouveau.
if (~webReloadOriginal.isNil and: { ~reload.notNil }) {
    ~webReloadOriginal = ~reload;
    ~reload = {
        ~webReloadOriginal.value;
        // Diffuse 250ms apres pour laisser les mutations se stabiliser
        // (le debounce interne de ~reload tourne sur ~200ms).
        AppClock.sched(0.25, { ~webBroadcastSteps.(); nil });
    };
};

// ---------- SC -> web : envoi du beat (sync visuel) ------------------
// AppClock + (60/bpm).wait : intervalle en secondes, previsible.
~webBeatRoutine !? { ~webBeatRoutine.stop };
~webBeatRoutine = Routine({
    inf.do {
        ~webBroadcast.value("/sync/beat", ~bpm ? 128);
        (60 / (~bpm ? 128)).wait;
    };
}).play(AppClock);

// ---------- SC -> web : amplitude par voie (parametres statiques) ----
//   Les ~xxxAmp sont les volumes du mixer (parametres, pas du signal).
//   Hydra peut les utiliser pour pondérer la réactivité par voie.
//   8 voies envoyees (kick, hat, snare, clap, perc, melody, acid, harmony).
~webAmpRoutine !? { ~webAmpRoutine.stop };
~webAmpRoutine = Routine({
    inf.do {
        ~webBroadcast.value("/sync/amp", "kick",    ~kickAmp ? 0);
        ~webBroadcast.value("/sync/amp", "hat",     ~hatAmp ? 0);
        ~webBroadcast.value("/sync/amp", "snare",   ~snareAmp ? 0);
        ~webBroadcast.value("/sync/amp", "clap",    ~clapAmp ? 0);
        ~webBroadcast.value("/sync/amp", "perc",    ~percAmp ? 0);
        ~webBroadcast.value("/sync/amp", "melody",  ~melodyAmp ? 0);
        ~webBroadcast.value("/sync/amp", "acid",    ~acidAmp ? 0);
        ~webBroadcast.value("/sync/amp", "harmony", ~harmonyAmp ? 0);
        0.1.wait;
    };
}).play(AppClock);

// ---------- SC -> web : VRAI RMS audio sur master (bus 0) ------------
//   Architecture actuelle : tous les Pdef sortent vers le bus 0 (pas de
//   bus dedie par voie). Donc on capture un RMS GLOBAL sur master via
//   SynthDef + SendReply.kr a 20 Hz. Hydra peut combiner ce RMS reel
//   avec les ~xxxAmp parametres pour decoupler par voie.
//
//   Message OSC : /sync/rms  master <valeur 0..1>
SynthDef(\webRmsProbe, { |inBus = 0, rate = 20|
    var sig = Mix.ar(In.ar(inBus, 2)) * 0.5;
    var amp = Amplitude.kr(sig, 0.01, 0.2);
    SendReply.kr(Impulse.kr(rate), '/webRms', [amp]);
}).add;

~webRmsResp !? { ~webRmsResp.free };
~webRmsSynth !? { ~webRmsSynth.free };

// On attend que le SynthDef soit envoye au serveur avant de creer le Synth
Server.default.sync;
~webRmsSynth = Synth.tail(nil, \webRmsProbe, [\inBus, 0, \rate, 20]);

~webRmsResp = OSCFunc({ |msg|
    // msg = ['/webRms', nodeID, replyID, amp]
    ~webBroadcast.value("/sync/rms", "master", msg[3].asFloat);
}, '/webRms', Server.default.addr);

// Annonce initiale
~webBroadcast.value("/sync/bpm", ~bpm ? 128);
~webBroadcastSteps.();

"=== web_bridge ready ===".postln;
("  Listen   : :" ++ ~webBridgeIn).postln;
"  Send to  : 127.0.0.1:57122".postln;
"  Start web: ~webStart.value".postln;
"  Stop SC  : ~webBridgeStop.value".postln;
"  Stop web : ~webServerStop.value".postln;
"  Webapp   : http://localhost:3000/".postln;

// Le serveur Node n'est PAS lance automatiquement -- decommenter si besoin
// ou appeler ~webStart.value depuis l'IDE.
// ~webServerStart.value;
)

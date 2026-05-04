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
//    Cmd+Entree sur le bloc ci-dessous. Le serveur Node demarre
//    automatiquement (si pas deja actif) et les pages /control + /hydra
//    s'ouvrent dans le navigateur par defaut.
//      ~webBridgeStop.value     -- ferme les OSCdef SC
//      ~webServerStop.value     -- tue le serveur Node
//      ~webOpenPages.value      -- ouvre /control + /hydra a la main
// =====================================================================
(
~webBridgeNode = NetAddr("127.0.0.1", 57122);    // <- vers le serveur Node
~webBridgeIn   = 57121;                          // <- ecoute du serveur
thisProcess.openUDPPort(~webBridgeIn);

~webBase = ~base ?? { "/Users/electron/Documents/Projets_Creatifs/sound_algo/" };
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

// ---------- Helpers de dispatch --------------------------------------
~webBridgeDefs = List.new;

~webBridgeAdd = { |path, action|
    var key = ("web_" ++ path.replace("/", "_")).asSymbol;
    var def = OSCdef(key, action, path, recvPort: ~webBridgeIn);
    ~webBridgeDefs.add(def);
    def;
};

~webBridgeStop = {
    ~webBridgeDefs.do(_.free);
    ~webBridgeDefs = List.new;
    ~webBeatRoutine !? { ~webBeatRoutine.stop };
    ~webAmpRoutine !? { ~webAmpRoutine.stop };
    "[web_bridge] OSCdef + Routines stopped (serveur Node toujours actif, ~webServerStop pour tuer)".postln;
};

// ---------- Transport ------------------------------------------------
~webBridgeAdd.("/control/bpm", { |msg|
    ~bpm = msg[1];
    TempoClock.default.tempo = ~bpm / 60;
    ~reload.value;
    ~webBridgeNode.sendMsg("/sync/bpm", ~bpm);
});

~webBridgeAdd.("/control/masterVol", { |msg|
    ~masterVol.(msg[1]);
});

~webBridgeAdd.("/control/masterFadeOut", { |msg|
    ~masterFadeOut.(msg[1] ? 8);
});

~webBridgeAdd.("/control/teardown", { ~teardown.() });

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

// ---------- Step sequencer (5 voies x 16 pas) -----------------------
[\kickSteps, \hatSteps, \snareSteps, \clapSteps, \percSteps].do { |sym|
    ~webBridgeAdd.("/control/" ++ sym.asString, { |msg|
        var steps = msg[1..].asArray.collect(_.asInteger);
        currentEnvironment.put(sym, steps);
        ~reload.value;
    });
};

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

// ---------- Tricks scéniques -----------------------------------------
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

// ---------- SC -> web : envoi du beat (sync visuel) ------------------
~webBeatRoutine !? { ~webBeatRoutine.stop };
~webBeatRoutine = Routine({
    inf.do {
        ~webBridgeNode.sendMsg("/sync/beat", ~bpm ? 128);
        (60 / (~bpm ? 128)).wait;
    };
}).play(TempoClock.default);

// ---------- SC -> web : amplitude RMS par voie -----------------------
//   Approximation simple : utilise les ~xxxAmp variables du moteur.
//   Pour un vrai RMS, il faudrait Bus.audio + SendReply, mais c'est
//   plus lourd. Cette version envoie les amp parameters statiques
//   chaque 10 Hz, suffisant pour l'animation Hydra.
~webAmpRoutine !? { ~webAmpRoutine.stop };
~webAmpRoutine = Routine({
    inf.do {
        ~webBridgeNode.sendMsg("/sync/amp", "kick",   ~kickAmp ? 0);
        ~webBridgeNode.sendMsg("/sync/amp", "hat",    ~hatAmp ? 0);
        ~webBridgeNode.sendMsg("/sync/amp", "snare",  ~snareAmp ? 0);
        ~webBridgeNode.sendMsg("/sync/amp", "melody", ~melodyAmp ? 0);
        ~webBridgeNode.sendMsg("/sync/amp", "acid",   ~acidAmp ? 0);
        0.1.wait;
    };
}).play(TempoClock.default);

// Annonce initiale
~webBridgeNode.sendMsg("/sync/bpm", ~bpm ? 128);

"=== web_bridge ready ===".postln;
("  Listen   : :" ++ ~webBridgeIn).postln;
"  Send to  : 127.0.0.1:57122".postln;
"  Stop SC  : ~webBridgeStop.value".postln;
"  Stop web : ~webServerStop.value".postln;
"  Webapp   : http://localhost:3000/".postln;

// Auto-lancement serveur Node + ouverture pages /control + /hydra
~webServerStart.value;
)

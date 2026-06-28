// =====================================================================
//  control/vdmx_send.scd  --  SC -> VDMX OSC bridge (analyse + horloge)
//  Sibling de hydra_send.scd. Tape le bus master (0) et pousse l'analyse
//  audio + le transport vers VDMX, namespace /av/*.
//
//  Cible reutilisee depuis data_only_viz/pose_bridge.py :
//    VDMX_OSC_HOST (defaut 127.0.0.1) : VDMX_OSC_PORT (defaut 1234)
//  Le body pose (/pose/*) et l'audio (/av/*) arrivent ainsi au meme VDMX.
//
//  SETUP : evaluer ce bloc une fois apres 00_load.scd (serveur booté).
//  Helpers exposes :
//    ~vdmxNote.(60, 100, 0.25)  -> pousse une note vers /av/note
//    ~vdmxScene.(2)             -> /av/scene + hook ~vdmxOnScene
//    ~vdmxStop.()               -> libere synth + routines + OSCdefs
//  Contrat complet : vdmx_visual/docs/osc-namespace.md
// =====================================================================
(
s.waitForBoot {
    var host = "VDMX_OSC_HOST".getenv ? "127.0.0.1";
    var port = ("VDMX_OSC_PORT".getenv ? "1234").asInteger;

    ~vdmxAddr = NetAddr(host, port);
    ~vdmxBeatsPerBar = ~vdmxBeatsPerBar ? 4;   // 4/4 par defaut
    ~vdmxBandGain = ~vdmxBandGain ? 6.0;       // gain de normalisation des bandes

    // --- SynthDef d'analyse : derivation de mesure sur le bus master ---
    SynthDef(\vdmxAnalyse, { |inBus = 0|
        var sig   = In.ar(inBus, 2).sum * 0.5;
        var amp   = Amplitude.kr(sig, 0.01, 0.25);
        var peak  = Peak.kr(sig, Impulse.kr(60));
        var sub   = Amplitude.kr(LPF.ar(sig, 120));
        var low   = Amplitude.kr(BPF.ar(sig, 250,  1.0));
        var mid   = Amplitude.kr(BPF.ar(sig, 1500, 1.0));
        var high  = Amplitude.kr(HPF.ar(sig, 4000));
        var fft   = FFT(LocalBuf(2048), sig);
        var cent  = SpecCentroid.kr(fft).cpsmidi.linlin(20, 127, 0, 1);
        var flat  = SpecFlatness.kr(fft);
        var onset = Onsets.kr(fft, 0.4, \rcomplex);
        SendReply.kr(Impulse.kr(60), '/vdmxFrame',
            [amp, peak, sub, low, mid, high, cent, flat]);
        SendReply.kr(onset, '/vdmxOnset', [1]);
        // pas de Out : on ne perturbe pas le signal master
    }).add;

    s.sync;

    // --- analyse -> forward OSC vers VDMX ---------------------------------
    OSCdef(\vdmxFrame, { |msg|
        // msg = [\vdmxFrame, nodeID, replyID, amp, peak, sub, low, mid, high, cent, flat]
        var d     = msg[3..];
        var amp   = d[0].clip(0, 1);
        var peak  = d[1].clip(0, 1);
        var bands = d[2..5].collect { |x| (x * ~vdmxBandGain).clip(0, 1) };
        var cent  = d[6].clip(0, 1);
        var flat  = d[7].clip(0, 1);
        ~vdmxAddr.sendMsg("/av/amp", amp);
        ~vdmxAddr.sendMsg("/av/peak", peak);
        ~vdmxAddr.sendMsg("/av/band", bands[0], bands[1], bands[2], bands[3]);
        ~vdmxAddr.sendMsg("/av/centroid", cent);
        ~vdmxAddr.sendMsg("/av/flat", flat);
    }, '/vdmxFrame');

    OSCdef(\vdmxOnset, { |msg|
        ~vdmxAddr.sendMsg("/av/onset", 1);
    }, '/vdmxOnset');

    // --- horloge : beat / bar / phase / bpm depuis TempoClock.default -----
    // Echantillonnage a 60 Hz en temps reel (SystemClock), tempo lu en live.
    // Non invasif : ne touche ni aux Pdef ni aux 345 tracks.
    ~vdmxClock.stop;   // si re-SETUP, on stoppe l'ancienne routine
    ~vdmxClock = Routine({
        var lastBeat = -1;
        loop {
            var beats = TempoClock.default.beats;
            var wb    = beats.floor.asInteger;
            var ph    = (beats % ~vdmxBeatsPerBar) / ~vdmxBeatsPerBar;
            ~vdmxAddr.sendMsg("/av/phase", ph);
            if(wb != lastBeat) {
                lastBeat = wb;
                ~vdmxAddr.sendMsg("/av/beat", wb);
                if(wb % ~vdmxBeatsPerBar == 0) {
                    ~vdmxAddr.sendMsg("/av/bar", (wb / ~vdmxBeatsPerBar).asInteger);
                };
                ~vdmxAddr.sendMsg("/av/bpm", (TempoClock.default.tempo * 60));
            };
            (1/60).wait;
        };
    }).play(SystemClock);

    // --- controle entrant TouchOSC -> SC (port langage 57120) -------------
    // Minimal et non intrusif. /ctl/scene appelle un hook surchargeable.
    ~vdmxOnScene = ~vdmxOnScene ? { |i| ("[vdmx] scene % (brancher ~vdmxOnScene)").format(i).postln };
    OSCdef(\vdmxCtlBpm,   { |m| ~setTempo.(m[1]) },        "/ctl/bpm");
    OSCdef(\vdmxCtlScene, { |m| ~vdmxScene.(m[1].asInteger) },                "/ctl/scene");

    // --- helpers ----------------------------------------------------------
    ~vdmxNote  = { |note, vel = 100, dur = 0.25|
        ~vdmxAddr.sendMsg("/av/note", note.asInteger, vel.asInteger, dur.asFloat);
    };
    ~vdmxScene = { |i|
        ~vdmxAddr.sendMsg("/av/scene", i.asInteger);
        ~vdmxOnScene.(i);
    };
    ~vdmxStop = {
        ~vdmxClock.stop;
        ~vdmxAnalyser !? { ~vdmxAnalyser.free };
        [\vdmxFrame, \vdmxOnset, \vdmxCtlBpm, \vdmxCtlScene].do { |k| OSCdef(k).free };
        "[vdmx] bridge libere".postln;
    };

    // --- demarrage de l'analyse (en queue, apres masterLim) ---------------
    ~vdmxAnalyser !? { ~vdmxAnalyser.free };
    ~vdmxAnalyser = Synth.tail(s.defaultGroup, \vdmxAnalyse, [\inBus, 0]);

    "[OK] SETUP VDMX SEND -> % : %  (namespace /av/*)".format(host, port).postln;
};
)

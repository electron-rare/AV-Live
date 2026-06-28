// TouchOSC feedback bridge
// Sends engine state back to the TouchOSC control surface so the iPad
// reflects what the SC engine is doing:
//
//   /armed/<name>       pad armed state (0 or 1), one message per pattern
//   /sync/rms           master amplitude (single float 0..1), 20 Hz
//   /sync/beat          beat pulse (value 1, once per beat on ~lp clock)
//   /seq/rhythm/state   idx k s h name  (echoed when /seq/rhythm received)
//   /seq/melody/state   idx deg0 deg1 ... (echoed when /seq/melody received)
//
// Sender capture strategy: we sniff /launch, /launch/vol, /launch/tempo
// and /launch/clear — messages the surface sends on every connect/pad tap —
// to discover the client IP. The /seq/* sniffers double as echo triggers.
// We intentionally skip /control/* exact paths: the surface sends
// /control/fx/... paths (not bare /control) which OSCdef can't match as a
// prefix, so they add no capture value.
//
// Additive + idempotent: re-loading stops the prior Routine and re-registers
// OSCdefs (same unique keys replace existing ones in OSCdef's registry).
(

// -- Port + address init --
~toscPort    = ~toscPort ? 9000;
~toscClients = ~toscClients ? Dictionary.new;

// Add / refresh a client entry when a control message arrives from the surface.
// Keyed by ip String so the same host always maps to one NetAddr (dedup).
// Logs only when a NEW ip is first seen.
~toscTouch = { |addr|
    var ip = addr.ip;
    ~toscClients[ip].isNil.if({
        ~toscClients[ip] = NetAddr(ip, ~toscPort);
        ("[touchosc] client -> " ++ ip ++ ":" ++ ~toscPort.asString).postln;
    });
};

// Send an OSC message to all known clients; no-op when none connected
~toscSend = { |path ...args|
    ~toscClients.values.do { |dest| dest.sendMsg(path, *args) };
};

// Canonical pad name order (16 pads in grid order, matches the surface layout)
~toscPatterns = [
    \kick, \hats,  \clap,  \perc,
    \sub,  \acid,  \arp,   \lead,
    \stab, \pad,   \ride,  \rim,
    \tom,  \reese, \bells, \sweep
];

// Push 4-state clip value for all pads + sequencers; nil-guarded.
// State: 0=off, 1=playing, 2=queued-launch, 3=queued-stop.
// Prefers fine-grained clipState; falls back to armed membership (0/1)
// for clips driven by concert logic that bypass ~lpArm.
~toscArmedPush = {
    ~lp.notNil.if({
        var list = ~toscPatterns ++ [\melseq, \rhythmseq];
        list.do { |nm|
            var state = (~lp[\clipState] !? { ~lp[\clipState][nm] })
                ? ((~lp[\armed].notNil and: { ~lp[\armed].includes(nm) }).binaryValue);
            ~toscSend.("/armed/" ++ nm.asString, state);
        };
    });
};

// -- Sender-capture sniffers (unique keys prefixed \tosc_sniff_) --
OSCdef(\tosc_sniff_launch,  { |msg, time, addr| ~toscTouch.(addr) }, '/launch');
OSCdef(\tosc_sniff_vol,     { |msg, time, addr| ~toscTouch.(addr) }, '/launch/vol');
OSCdef(\tosc_sniff_tempo,   { |msg, time, addr| ~toscTouch.(addr) }, '/launch/tempo');
OSCdef(\tosc_sniff_clear,   { |msg, time, addr| ~toscTouch.(addr) }, '/launch/clear');

// -- Seq state echo + capture --
// When the surface selects a rhythm preset, we echo the full pattern back.
OSCdef(\tosc_sniff_seqrhythm, { |msg, time, addr|
    var idx, item;
    ~toscTouch.(addr);
    (~lp.notNil and: { ~lp[\rhythms].notNil }).if({
        idx  = msg[1].asInteger;
        item = ~lp[\rhythms][idx];
        item.notNil.if({
            ~toscSend.(
                "/seq/rhythm/state",
                idx,
                item[\k].asString,
                item[\s].asString,
                item[\h].asString,
                item[\name].asString
            );
        });
    });
}, '/seq/rhythm');

// When the surface selects a melody preset, we echo the degree array back.
OSCdef(\tosc_sniff_seqmelody, { |msg, time, addr|
    var idx, degs;
    ~toscTouch.(addr);
    (~lp.notNil and: { ~lp[\melodies].notNil }).if({
        idx  = msg[1].asInteger;
        degs = ~lp[\melodies][idx];
        degs.notNil.if({
            ~toscSend.valueArray(
                ["/seq/melody/state"] ++ [idx] ++ degs
            );
        });
    });
}, '/seq/melody');

// -- Master RMS probe (server-only block; skipped when booting headless) --
// Mirrors the \webRmsProbe recipe from web_bridge.scd, renamed to avoid clash.
// Wrapped in a Routine so Server.default.sync is a real suspension point
// both inside boot.scd's Routine AND on a manual IDE reload (where top-level
// code runs on AppClock and a bare sync would be a no-op, firing Synth.tail
// before the SynthDef finished compiling).
Server.default.serverRunning.if({
    Routine({
        SynthDef(\toscRmsProbe, { |inBus = 0, rate = 20|
            var sig = Mix.ar(In.ar(inBus, 2)) * 0.5;
            var amp = Amplitude.kr(sig, 0.01, 0.2);
            SendReply.kr(Impulse.kr(rate), '/toscRms', [amp]);
        }).add;
        ~toscRmsResp  !? { ~toscRmsResp.free };
        ~toscRmsSynth !? { ~toscRmsSynth.free };
        Server.default.sync;
        ~toscRmsSynth = Synth.tail(nil, \toscRmsProbe, [\inBus, 0, \rate, 20]);
        ~toscRmsResp  = OSCFunc({ |msg|
            ~toscSend.("/sync/rms", msg[3].asFloat);
        }, '/toscRms', Server.default.addr);
    }).play;
});

// -- Beat pulse + armed state push on the launchpad clock --
// Stop any prior Routine before (re)starting so reloads don't stack.
~toscFeedbackRoutine !? { ~toscFeedbackRoutine.stop };
~toscFeedbackRoutine = Routine({
    {
        ~toscArmedPush.();
        ~toscSend.("/sync/beat", 1);
        1.wait;
    }.loop;
}).play(~lp.notNil.if({ ~lp[\clock] ? TempoClock.default }, { TempoClock.default }));

"[touchosc] feedback ready".postln;
)

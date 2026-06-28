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
~toscPort = ~toscPort ? 9000;
~tosc     = ~tosc;  // nil on first load, preserved on reload

// Refresh the target NetAddr when a control message arrives from the surface
~toscTouch = { |addr|
    var ip = addr.ip;
    (~tosc.isNil or: { ~tosc.ip != ip }).if({
        ~tosc = NetAddr(ip, ~toscPort);
        ("[touchosc] client -> " ++ ip ++ ":" ++ ~toscPort.asString).postln;
    });
};

// Send an OSC message to the surface, silently if ~tosc not yet known
~toscSend = { |path ...args|
    ~tosc !? { ~tosc.sendMsg(path, *args) };
};

// Canonical pad name order (16 pads in grid order, matches the surface layout)
~toscPatterns = [
    \kick, \hats,  \clap,  \perc,
    \sub,  \acid,  \arp,   \lead,
    \stab, \pad,   \ride,  \rim,
    \tom,  \reese, \bells, \sweep
];

// Push armed state for all 16 pads; nil-guarded
~toscArmedPush = {
    (~lp.notNil and: { ~lp[\armed].notNil }).if({
        ~toscPatterns.do { |name|
            ~toscSend.(
                "/armed/" ++ name.asString,
                ~lp[\armed].includes(name).binaryValue
            );
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
            ~toscSend.valueWithArguments(
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

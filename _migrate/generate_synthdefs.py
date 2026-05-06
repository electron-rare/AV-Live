#!/usr/bin/env python3
# coding: utf-8
"""
generate_synthdefs.py
=====================

Genere ~19 variants de SynthDef par original sound_algo, repartis dans
synth/{drums,bass,lead,pad,world,master}/. Cible totale : ~1007 nouveaux
fichiers.

Strategie : templates SuperCollider parametres en chaines Python avec
placeholders {nom}. Pour chaque original, on selectionne un ensemble de
templates + grilles de parametres et on genere des variants.

Convention sound_algo (stricte) :
- UN SEUL bloc top-level (...)
- Variables minuscules
- Commentaires francais
- Signature standard : freq/gate/attack/decay/sustain/release/amp/pan/scBus/scAmt
- EnvGen.kr(env, gate, doneAction: 2) obligatoire
- Pan2.ar (ou Balance2.ar) en sortie
- LeakDC.ar apres feedback / oscillateurs lourds
- clip sur freq, tanh saturation pattern
- Validation : balance parens P:0 B:0
"""

import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SYNTH_DIR = ROOT / "synth"

# ---------------------------------------------------------------------------
#  Validation balance (re-implemente le awk du projet)
# ---------------------------------------------------------------------------
def balance_check(text):
    """Retourne (parens, brackets) -- doivent etre 0,0."""
    p = 0
    b = 0
    in_str = False
    in_sym_str = False
    in_line_comment = False
    in_block_comment = 0
    i = 0
    while i < len(text):
        c = text[i]
        n = text[i + 1] if i + 1 < len(text) else ""
        if in_line_comment:
            if c == "\n":
                in_line_comment = False
            i += 1
            continue
        if in_block_comment:
            if c == "*" and n == "/":
                in_block_comment -= 1
                i += 2
                continue
            if c == "/" and n == "*":
                in_block_comment += 1
                i += 2
                continue
            i += 1
            continue
        if in_str:
            if c == "\\":
                i += 2
                continue
            if c == '"':
                in_str = False
            i += 1
            continue
        if c == "/" and n == "/":
            in_line_comment = True
            i += 2
            continue
        if c == "/" and n == "*":
            in_block_comment = 1
            i += 2
            continue
        if c == '"':
            in_str = True
            i += 1
            continue
        if c == "(":
            p += 1
        elif c == ")":
            p -= 1
        elif c == "[":
            b += 1
        elif c == "]":
            b -= 1
        i += 1
    return p, b


# ---------------------------------------------------------------------------
#  Templates SC (chaines avec placeholders {param})
# ---------------------------------------------------------------------------

# --- DRUMS -----------------------------------------------------------------

KICK_BASIC = r"""// {comment}
(
SynthDef(\{name}, {{
    arg freq = {freq}, pitchAmt = {pitch_amt}, pitchTime = {pitch_time},
        decay = {decay}, drive = {drive}, click = {click},
        amp = {amp}, pan = 0,
        scBus = 0, scShape = {sc_shape};
    var pEnv, body, sub, clickSig, ampEnv, sig, scEnv;
    pEnv = EnvGen.kr(Env([freq * pitchAmt, freq], [pitchTime], {curve}));
    body = {body_ugen}.ar(pEnv);
    sub  = SinOsc.ar(freq * {sub_ratio});
    clickSig = HPF.ar(WhiteNoise.ar, {click_hpf}) *
               EnvGen.kr(Env.perc(0.0005, {click_decay}));
    sig = body + (sub * {sub_amp}) + (clickSig * click);
    ampEnv = EnvGen.kr(Env.perc(0.002, decay, curve: {amp_curve}), doneAction: 2);
    sig = (sig * drive).{sat};
    sig = sig * ampEnv;
    sig = LeakDC.ar(sig) * amp;
    scEnv = EnvGen.kr(Env.perc(0.001, scShape, curve: -4));
    Out.kr(scBus, scEnv);
    Out.ar(0, Pan2.ar(sig, pan));
}}).add;
)
"""

KICK_FM = r"""// {comment}
(
SynthDef(\{name}, {{
    arg freq = {freq}, ratio = {ratio}, modIndex = {mod_index},
        decay = {decay}, drive = {drive}, click = {click},
        amp = {amp}, pan = 0,
        scBus = 0, scShape = {sc_shape};
    var pEnv, mod, car, clickSig, ampEnv, sig, scEnv;
    pEnv = EnvGen.kr(Env([freq * {pitch_amt}, freq], [{pitch_time}], -3));
    mod = SinOsc.ar(pEnv * ratio) * pEnv * modIndex;
    car = SinOsc.ar(pEnv + mod);
    clickSig = HPF.ar(WhiteNoise.ar, 2500) *
               EnvGen.kr(Env.perc(0.0005, 0.005));
    sig = car + (clickSig * click);
    ampEnv = EnvGen.kr(Env.perc(0.002, decay, curve: -3), doneAction: 2);
    sig = (sig * drive).{sat};
    sig = LeakDC.ar(sig * ampEnv) * amp;
    scEnv = EnvGen.kr(Env.perc(0.001, scShape, curve: -4));
    Out.kr(scBus, scEnv);
    Out.ar(0, Pan2.ar(sig, pan));
}}).add;
)
"""

KICK_DISTORTED = r"""// {comment}
(
SynthDef(\{name}, {{
    arg freq = {freq}, decay = {decay}, drive = {drive},
        fold = {fold}, amp = {amp}, pan = 0,
        scBus = 0, scShape = {sc_shape};
    var pEnv, body, ampEnv, sig, scEnv;
    pEnv = EnvGen.kr(Env([freq * 4, freq], [0.04], -4));
    body = {body_ugen}.ar(pEnv.clip(20, 800));
    sig = body.fold2(fold);
    sig = (sig * drive).{sat};
    ampEnv = EnvGen.kr(Env.perc(0.002, decay, curve: -3), doneAction: 2);
    sig = LeakDC.ar(sig * ampEnv) * amp;
    scEnv = EnvGen.kr(Env.perc(0.001, scShape, curve: -4));
    Out.kr(scBus, scEnv);
    Out.ar(0, Pan2.ar(sig, pan));
}}).add;
)
"""

SNARE_TPL = r"""// {comment}
(
SynthDef(\{name}, {{
    arg freq = {freq}, decay = {decay}, tone = {tone}, noise = {noise},
        drive = {drive}, amp = {amp}, pan = 0,
        scBus = 0, scAmt = 0;
    var sig, ampEnv, body, n;
    body = SinOsc.ar(freq) + SinOsc.ar(freq * 1.4);
    n = HPF.ar(WhiteNoise.ar, {hpf});
    sig = (body * tone) + (n * noise);
    ampEnv = EnvGen.kr(Env.perc(0.001, decay, curve: {curve}), doneAction: 2);
    sig = (sig * drive).{sat};
    sig = LeakDC.ar(sig * ampEnv) * amp;
    Out.ar(0, Pan2.ar(sig, pan));
}}).add;
)
"""

CLAP_TPL = r"""// {comment}
(
SynthDef(\{name}, {{
    arg decay = {decay}, hpf = {hpf}, drive = {drive},
        amp = {amp}, pan = 0,
        scBus = 0, scAmt = 0;
    var sig, env, n;
    n = HPF.ar(WhiteNoise.ar, hpf);
    env = EnvGen.kr(
        Env([0, 1, 0, 1, 0, 1, 0, 1, 0],
            [0.001, 0.012, 0.001, 0.012, 0.001, 0.012, 0.002, decay],
            [0, -2, 0, -2, 0, -2, 0, {curve}]),
        doneAction: 2);
    sig = (n * env * drive).{sat};
    sig = LeakDC.ar(sig) * amp;
    Out.ar(0, Pan2.ar(sig, pan));
}}).add;
)
"""

HAT_TPL = r"""// {comment}
(
SynthDef(\{name}, {{
    arg decay = {decay}, hpf = {hpf}, bpf = {bpf}, rq = {rq},
        drive = {drive}, amp = {amp}, pan = 0,
        scBus = 0, scAmt = 0;
    var sig, env, n;
    n = WhiteNoise.ar;
    n = HPF.ar(n, hpf);
    n = BPF.ar(n, bpf, rq);
    env = EnvGen.kr(Env.perc(0.001, decay, curve: {curve}), doneAction: 2);
    sig = (n * env * drive).{sat};
    sig = LeakDC.ar(sig) * amp;
    Out.ar(0, Pan2.ar(sig, pan));
}}).add;
)
"""

TOM_TPL = r"""// {comment}
(
SynthDef(\{name}, {{
    arg freq = {freq}, decay = {decay}, drive = {drive},
        amp = {amp}, pan = 0,
        scBus = 0, scAmt = 0;
    var sig, pEnv, ampEnv;
    pEnv = EnvGen.kr(Env([freq * {pitch_amt}, freq], [{pitch_time}], -3));
    sig = {body_ugen}.ar(pEnv.clip(30, 1500));
    ampEnv = EnvGen.kr(Env.perc(0.005, decay, curve: -3), doneAction: 2);
    sig = (sig * drive).{sat};
    sig = LeakDC.ar(sig * ampEnv) * amp;
    Out.ar(0, Pan2.ar(sig, pan));
}}).add;
)
"""

PERC_METALLIC = r"""// {comment}
(
SynthDef(\{name}, {{
    arg freq = {freq}, decay = {decay}, ratio = {ratio},
        amp = {amp}, pan = 0,
        scBus = 0, scAmt = 0;
    var sig, env, m;
    m = Mix.fill(4, {{ |i|
        SinOsc.ar(freq * (1 + (i * ratio))) * (1 / (i + 1))
    }});
    env = EnvGen.kr(Env.perc(0.001, decay, curve: -4), doneAction: 2);
    sig = LeakDC.ar(m * env) * amp;
    Out.ar(0, Pan2.ar(sig, pan));
}}).add;
)
"""

# --- BASS ------------------------------------------------------------------

BASS_ACID_TB303 = r"""// {comment}
(
SynthDef(\{name}, {{
    arg freq = {freq}, gate = 1, accent = 0, slideTime = {slide_time},
        cutoff = {cutoff}, cutoffEnv = {cutoff_env}, rq = {rq},
        envDecay = {env_decay}, ampDecay = {amp_decay},
        drive = {drive}, amp = {amp}, pan = 0,
        scBus = 0, scAmt = 0.7;
    var f, sig, ampEnv, fEnv, fc, duck;
    f = Lag.kr(freq, slideTime);
    sig = {osc_ugen}.ar(f);
    fEnv = EnvGen.kr(Env.perc(0.001, envDecay * (1 - (accent * 0.4))),
                     gate, doneAction: 0);
    fc = (cutoff + (fEnv * cutoffEnv * (1 + accent))).clip(60, 14000);
    sig = RLPF.ar(sig, fc, rq);
    ampEnv = EnvGen.kr(
        Env.adsr(0.003, ampDecay, 0, 0.05, curve: -3),
        gate, doneAction: 2
    );
    sig = (sig * drive * (1 + (accent * 0.6))).{sat} / drive.sqrt;
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    sig = sig * ampEnv * amp * duck;
    Out.ar(0, Pan2.ar(sig, pan));
}}).add;
)
"""

BASS_FM = r"""// {comment}
(
SynthDef(\{name}, {{
    arg freq = {freq}, gate = 1, ratio = {ratio}, modIndex = {mod_index},
        attack = {attack}, decay = {decay}, sustain = {sustain}, release = {release},
        drive = {drive}, amp = {amp}, pan = 0,
        scBus = 0, scAmt = 0.5;
    var sig, env, mod, duck, f;
    f = freq.clip(20, 8000);
    mod = SinOsc.ar(f * ratio) * f * modIndex;
    sig = SinOsc.ar(f + mod);
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    sig = (sig * drive).{sat} / drive.sqrt;
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    Out.ar(0, Pan2.ar(sig * env * amp * duck, pan));
}}).add;
)
"""

BASS_REESE = r"""// {comment}
(
SynthDef(\{name}, {{
    arg freq = {freq}, gate = 1, detune = {detune},
        cutoff = {cutoff}, rq = {rq},
        attack = {attack}, decay = {decay}, sustain = {sustain}, release = {release},
        drive = {drive}, amp = {amp}, pan = 0,
        scBus = 0, scAmt = 0.5;
    var sig, env, voices, duck;
    voices = [
        Saw.ar(freq * (1 - detune)),
        Saw.ar(freq * (1 + detune)),
        Saw.ar(freq * (1 + (detune * {third_factor})))
    ];
    sig = Mix(voices) * 0.33;
    sig = LPF.ar(sig, cutoff);
    sig = RLPF.ar(sig, cutoff, rq);
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    sig = (sig * drive).{sat} / drive.sqrt;
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    Out.ar(0, Pan2.ar(sig * env * amp * duck, pan));
}}).add;
)
"""

BASS_SUB = r"""// {comment}
(
SynthDef(\{name}, {{
    arg freq = {freq}, gate = 1,
        attack = {attack}, decay = {decay}, sustain = {sustain}, release = {release},
        drive = {drive}, amp = {amp}, pan = 0,
        scBus = 0, scAmt = 0.6;
    var sig, env, duck;
    sig = {osc_ugen}.ar(freq.clip(20, 200));
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    sig = (sig * drive).{sat};
    sig = LeakDC.ar(sig);
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    Out.ar(0, Pan2.ar(sig * env * amp * duck, pan));
}}).add;
)
"""

BASS_WOBBLE = r"""// {comment}
(
SynthDef(\{name}, {{
    arg freq = {freq}, gate = 1, lfoRate = {lfo_rate}, lfoDepth = {lfo_depth},
        cutoff = {cutoff}, rq = {rq},
        attack = {attack}, decay = {decay}, sustain = {sustain}, release = {release},
        drive = {drive}, amp = {amp}, pan = 0,
        scBus = 0, scAmt = 0.5;
    var sig, env, lfo, fc, duck;
    sig = Saw.ar(freq.clip(20, 4000));
    lfo = SinOsc.kr(lfoRate).range(1 - lfoDepth, 1);
    fc = (cutoff * lfo).clip(60, 12000);
    sig = RLPF.ar(sig, fc, rq);
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    sig = (sig * drive).{sat} / drive.sqrt;
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    Out.ar(0, Pan2.ar(sig * env * amp * duck, pan));
}}).add;
)
"""

# --- LEAD ------------------------------------------------------------------

LEAD_SUPERSAW = r"""// {comment}
(
SynthDef(\{name}, {{
    arg freq = {freq}, gate = 1, detune = {detune}, mix = {mix},
        cutoff = {cutoff}, rq = {rq},
        attack = {attack}, decay = {decay}, sustain = {sustain}, release = {release},
        drive = {drive}, amp = {amp}, pan = 0,
        scBus = 0, scAmt = 0.4;
    var sig, env, duck, voices, center, sides;
    voices = ({voice_range}).collect {{ |i|
        Saw.ar(freq * (1 + (i * detune)))
    }};
    center = voices[{center_idx}];
    sides = voices.removeAt({center_idx});
    sig = (center * (1 - mix)) + (Mix(voices) * mix * 0.18);
    sig = LPF.ar(sig, cutoff);
    sig = [DelayC.ar(sig, 0.03, SinOsc.kr(0.4, 0).range(0.005, 0.018)),
           DelayC.ar(sig, 0.03, SinOsc.kr(0.5, pi).range(0.005, 0.018))];
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    sig = [(sig[0] * drive).{sat} / drive.sqrt, (sig[1] * drive).{sat} / drive.sqrt];
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    sig = Balance2.ar(sig[0], sig[1], pan);
    Out.ar(0, sig * env * amp * duck);
}}).add;
)
"""

LEAD_FM = r"""// {comment}
(
SynthDef(\{name}, {{
    arg freq = {freq}, gate = 1, ratio = {ratio}, modIndex = {mod_index},
        attack = {attack}, decay = {decay}, sustain = {sustain}, release = {release},
        drive = {drive}, amp = {amp}, pan = 0,
        scBus = 0, scAmt = 0.4;
    var sig, env, mod, duck, f;
    f = freq.clip(20, 8000);
    mod = SinOsc.ar(f * ratio) * f * modIndex *
          EnvGen.kr(Env.perc(0.001, {mod_decay}));
    sig = SinOsc.ar(f + mod);
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    sig = (sig * drive).{sat} / drive.sqrt;
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    Out.ar(0, Pan2.ar(sig * env * amp * duck, pan));
}}).add;
)
"""

LEAD_PLUCK_KS = r"""// {comment}
(
SynthDef(\{name}, {{
    arg freq = {freq}, gate = 1, decayTime = {decay_time},
        cutoff = {cutoff},
        attack = {attack}, decay = {decay}, sustain = {sustain}, release = {release},
        drive = {drive}, amp = {amp}, pan = 0,
        scBus = 0, scAmt = 0.4;
    var sig, env, exciter, ks, duck, f;
    f = freq.clip(30, 6000);
    exciter = WhiteNoise.ar(0.7) * EnvGen.kr(Env.perc(0.0005, {exciter_decay}));
    ks = LeakDC.ar(CombC.ar(exciter, 0.05, f.reciprocal, decayTime));
    sig = LPF.ar(ks, cutoff);
    sig = (sig * drive).{sat};
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    Out.ar(0, Pan2.ar(sig * env * amp * duck, pan));
}}).add;
)
"""

LEAD_PULSE_PWM = r"""// {comment}
(
SynthDef(\{name}, {{
    arg freq = {freq}, gate = 1, pwmRate = {pwm_rate}, pwmDepth = {pwm_depth},
        cutoff = {cutoff}, rq = {rq},
        attack = {attack}, decay = {decay}, sustain = {sustain}, release = {release},
        drive = {drive}, amp = {amp}, pan = 0,
        scBus = 0, scAmt = 0.4;
    var sig, env, pwm, duck;
    pwm = SinOsc.kr(pwmRate).range(0.5 - pwmDepth, 0.5 + pwmDepth);
    sig = Pulse.ar(freq.clip(20, 8000), pwm);
    sig = RLPF.ar(sig, cutoff, rq);
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    sig = (sig * drive).{sat} / drive.sqrt;
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    Out.ar(0, Pan2.ar(sig * env * amp * duck, pan));
}}).add;
)
"""

LEAD_BELL = r"""// {comment}
(
SynthDef(\{name}, {{
    arg freq = {freq}, gate = 1,
        attack = {attack}, decay = {decay}, sustain = {sustain}, release = {release},
        drive = {drive}, amp = {amp}, pan = 0,
        scBus = 0, scAmt = 0.3;
    var sig, env, parts, duck, f;
    f = freq.clip(40, 6000);
    parts = Mix.fill({n_partials}, {{ |i|
        var ratio = [1, 2.01, 2.97, 4.03, 5.21, 6.43, 7.58][i];
        var amp = 1 / (i + 1);
        SinOsc.ar(f * ratio) * amp *
        EnvGen.kr(Env.perc(0.005, {bell_decay} * (1 / (i * 0.3 + 1))))
    }});
    sig = parts * 0.25;
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    sig = (sig * drive).{sat};
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    Out.ar(0, Pan2.ar(sig * env * amp * duck, pan));
}}).add;
)
"""

LEAD_STAB = r"""// {comment}
(
SynthDef(\{name}, {{
    arg freq = {freq}, gate = 1,
        cutoff = {cutoff}, cutoffEnv = {cutoff_env}, rq = {rq},
        attack = {attack}, decay = {decay}, sustain = {sustain}, release = {release},
        drive = {drive}, amp = {amp}, pan = 0,
        scBus = 0, scAmt = 0.4;
    var sig, env, fEnv, fc, duck;
    sig = Mix([{osc_ugen}.ar(freq), {osc_ugen}.ar(freq * 1.005)]);
    fEnv = EnvGen.kr(Env.perc(0.001, {f_env_decay}), gate);
    fc = (cutoff + (fEnv * cutoffEnv)).clip(80, 14000);
    sig = RLPF.ar(sig, fc, rq);
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    sig = (sig * drive).{sat} / drive.sqrt;
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    Out.ar(0, Pan2.ar(sig * env * amp * duck, pan));
}}).add;
)
"""

# --- PAD -------------------------------------------------------------------

PAD_STRING = r"""// {comment}
(
SynthDef(\{name}, {{
    arg freq = {freq}, gate = 1, detune = {detune},
        cutoff = {cutoff}, rq = {rq},
        attack = {attack}, decay = {decay}, sustain = {sustain}, release = {release},
        drive = {drive}, amp = {amp}, pan = 0,
        scBus = 0, scAmt = 0.4;
    var sig, env, duck;
    sig = Mix.fill({n_voices}, {{ |i|
        Saw.ar(freq * (1 + ((i - {center}) * detune)))
    }}) * 0.22;
    sig = RLPF.ar(sig, cutoff, rq);
    sig = sig + DelayC.ar(sig, 0.04,
        SinOsc.kr({chorus_rate}, 0).range(0.01, 0.03));
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    sig = (sig * drive).{sat} / drive.sqrt;
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    Out.ar(0, Pan2.ar(sig * env * amp * duck, pan));
}}).add;
)
"""

PAD_BELL = r"""// {comment}
(
SynthDef(\{name}, {{
    arg freq = {freq}, gate = 1,
        attack = {attack}, decay = {decay}, sustain = {sustain}, release = {release},
        drive = {drive}, amp = {amp}, pan = 0,
        scBus = 0, scAmt = 0.3;
    var sig, env, parts, duck, f;
    f = freq.clip(40, 4000);
    parts = Mix.fill({n_partials}, {{ |i|
        SinOsc.ar(f * (i + 1) * {ratio_step}) * (1 / (i + 1)) *
        SinOsc.kr({lfo_rate} + (i * 0.13), i * 0.5).range(0.4, 1.0)
    }});
    sig = parts * 0.2;
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    sig = (sig * drive).{sat};
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    Out.ar(0, Pan2.ar(sig * env * amp * duck, pan));
}}).add;
)
"""

PAD_DRONE = r"""// {comment}
(
SynthDef(\{name}, {{
    arg freq = {freq}, gate = 1, detune = {detune},
        cutoff = {cutoff}, rq = {rq},
        attack = {attack}, decay = {decay}, sustain = {sustain}, release = {release},
        drive = {drive}, amp = {amp}, pan = 0,
        scBus = 0, scAmt = 0.3;
    var sig, env, duck, lfo;
    lfo = SinOsc.kr({lfo_rate}).range(1 - detune, 1 + detune);
    sig = {osc_ugen}.ar(freq * lfo) +
          {osc_ugen}.ar(freq * 0.501 * lfo) * 0.5;
    sig = LPF.ar(sig, cutoff);
    sig = RLPF.ar(sig, cutoff, rq);
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    sig = (sig * drive).{sat} / drive.sqrt;
    sig = LeakDC.ar(sig);
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    Out.ar(0, Pan2.ar(sig * env * amp * duck, pan));
}}).add;
)
"""

PAD_CHOIR = r"""// {comment}
(
SynthDef(\{name}, {{
    arg freq = {freq}, gate = 1, detune = {detune},
        formant1 = {formant1}, formant2 = {formant2},
        attack = {attack}, decay = {decay}, sustain = {sustain}, release = {release},
        drive = {drive}, amp = {amp}, pan = 0,
        scBus = 0, scAmt = 0.3;
    var sig, env, duck, voices;
    voices = Mix.fill({n_voices}, {{ |i|
        Saw.ar(freq * (1 + ((i - 2) * detune * (i + 1) * 0.5)))
    }}) * 0.18;
    sig = BPF.ar(voices, formant1, 0.4) + BPF.ar(voices, formant2, 0.5);
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    sig = (sig * drive).{sat};
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    Out.ar(0, Pan2.ar(sig * env * amp * duck, pan));
}}).add;
)
"""

# --- WORLD -----------------------------------------------------------------

WORLD_PLUCK = r"""// {comment}
(
SynthDef(\{name}, {{
    arg freq = {freq}, gate = 1, bendAmt = {bend_amt}, bendTime = {bend_time},
        cutoff = {cutoff}, rq = {rq},
        attack = {attack}, decay = {decay}, sustain = {sustain}, release = {release},
        drive = {drive}, amp = {amp}, pan = 0,
        scBus = 0, scAmt = 0.4;
    var sig, env, duck, exciter, ks, bentFreq, f;
    f = freq.clip(40, 6000);
    bentFreq = f * (1 + EnvGen.kr(Env([bendAmt, 0], [bendTime], -3)));
    exciter = WhiteNoise.ar(0.7) * EnvGen.kr(Env.perc(0.0005, {exciter_decay}));
    ks = LeakDC.ar(CombC.ar(exciter, 0.05, bentFreq.reciprocal, {ks_decay}));
    sig = LPF.ar(ks, cutoff);
    sig = (sig * drive).{sat};
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    Out.ar(0, Pan2.ar(sig * env * amp * duck, pan));
}}).add;
)
"""

WORLD_DRUM_PITCHED = r"""// {comment}
(
SynthDef(\{name}, {{
    arg freq = {freq}, gate = 1,
        decayTime = {decay_time}, noiseAmt = {noise_amt},
        attack = 0.001, decay = {decay}, sustain = 0, release = 0.05,
        drive = {drive}, amp = {amp}, pan = 0,
        scBus = 0, scAmt = 0.3;
    var sig, env, duck, body, n, pEnv;
    pEnv = EnvGen.kr(Env([freq * {pitch_amt}, freq], [{pitch_time}], -3));
    body = SinOsc.ar(pEnv.clip(30, 2000));
    n = HPF.ar(WhiteNoise.ar, 800) *
        EnvGen.kr(Env.perc(0.0005, 0.04));
    sig = body + (n * noiseAmt);
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    sig = (sig * drive).{sat};
    sig = LeakDC.ar(sig * env);
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    Out.ar(0, Pan2.ar(sig * amp * duck, pan));
}}).add;
)
"""

WORLD_GONG = r"""// {comment}
(
SynthDef(\{name}, {{
    arg freq = {freq}, gate = 1,
        attack = 0.005, decay = {decay}, sustain = 0.3, release = {release},
        drive = {drive}, amp = {amp}, pan = 0,
        scBus = 0, scAmt = 0.3;
    var sig, env, duck, parts, f;
    f = freq.clip(40, 2000);
    parts = Mix.fill({n_partials}, {{ |i|
        var r = [1.0, 1.34, 1.81, 2.13, 2.65, 3.17, 3.91, 4.43][i];
        SinOsc.ar(f * r) * (1 / (i + 1)) *
        EnvGen.kr(Env.perc(0.005, {partial_decay} * (1 + (i * 0.4))))
    }});
    sig = parts * 0.22;
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    sig = (sig * drive).{sat};
    sig = LeakDC.ar(sig);
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    Out.ar(0, Pan2.ar(sig * env * amp * duck, pan));
}}).add;
)
"""

WORLD_FLUTE = r"""// {comment}
(
SynthDef(\{name}, {{
    arg freq = {freq}, gate = 1, breath = {breath},
        cutoff = {cutoff}, rq = {rq},
        attack = {attack}, decay = {decay}, sustain = {sustain}, release = {release},
        drive = {drive}, amp = {amp}, pan = 0,
        scBus = 0, scAmt = 0.3;
    var sig, env, duck, body, n, vib, f;
    f = freq.clip(80, 4000);
    vib = SinOsc.kr({vib_rate}, 0, {vib_depth}, 1);
    body = SinOsc.ar(f * vib) + (SinOsc.ar(f * 2 * vib) * 0.3);
    n = WhiteNoise.ar * breath;
    n = BPF.ar(n, f, 0.5);
    sig = body + n;
    sig = LPF.ar(sig, cutoff);
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    sig = (sig * drive).{sat};
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    Out.ar(0, Pan2.ar(sig * env * amp * duck, pan));
}}).add;
)
"""

WORLD_DRONE = r"""// {comment}
(
SynthDef(\{name}, {{
    arg freq = {freq}, gate = 1, formantFreq = {formant_freq},
        attack = {attack}, decay = {decay}, sustain = {sustain}, release = {release},
        drive = {drive}, amp = {amp}, pan = 0,
        scBus = 0, scAmt = 0.3;
    var sig, env, duck, body, lfo, f;
    f = freq.clip(40, 400);
    lfo = SinOsc.kr({lfo_rate}).range(0.95, 1.05);
    body = Saw.ar(f * lfo) + (Pulse.ar(f * 2 * lfo, 0.4) * 0.3);
    sig = BPF.ar(body, formantFreq, 0.3);
    sig = LPF.ar(sig, {lpf_cutoff});
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    sig = (sig * drive).{sat};
    sig = LeakDC.ar(sig);
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    Out.ar(0, Pan2.ar(sig * env * amp * duck, pan));
}}).add;
)
"""

# --- MASTER ----------------------------------------------------------------

MASTER_COMP = r"""// {comment}
(
SynthDef(\{name}, {{
    arg threshold = {threshold}, ratio = {ratio}, attack = {attack}, release = {release},
        makeup = {makeup};
    var sig = In.ar(0, 2);
    sig = Compander.ar(sig, sig, threshold, 1.0, ratio, attack, release);
    sig = sig * makeup;
    ReplaceOut.ar(0, sig);
}}).add;
)
"""

MASTER_LIM = r"""// {comment}
(
SynthDef(\{name}, {{
    arg threshold = {threshold}, lookAhead = {look_ahead}, makeup = {makeup};
    var sig = In.ar(0, 2);
    sig = Limiter.ar(sig, threshold, lookAhead);
    sig = sig * makeup;
    ReplaceOut.ar(0, sig);
}}).add;
)
"""

MASTER_SAT = r"""// {comment}
(
SynthDef(\{name}, {{
    arg drive = {drive}, mix = {mix}, makeup = {makeup};
    var sig, dry;
    sig = In.ar(0, 2);
    dry = sig;
    sig = (sig * drive).{sat} / drive.sqrt;
    sig = (dry * (1 - mix)) + (sig * mix);
    sig = sig * makeup;
    ReplaceOut.ar(0, sig);
}}).add;
)
"""

MASTER_EQ = r"""// {comment}
(
SynthDef(\{name}, {{
    arg lowCut = {low_cut}, highShelfFreq = {high_shelf_freq},
        highShelfGain = {high_shelf_gain}, makeup = {makeup};
    var sig = In.ar(0, 2);
    sig = HPF.ar(sig, lowCut);
    sig = BHiShelf.ar(sig, highShelfFreq, 1, highShelfGain);
    sig = sig * makeup;
    ReplaceOut.ar(0, sig);
}}).add;
)
"""

MASTER_WIDEN = r"""// {comment}
(
SynthDef(\{name}, {{
    arg width = {width}, delay = {delay}, makeup = {makeup};
    var sig, l, r, mid, side;
    sig = In.ar(0, 2);
    mid = (sig[0] + sig[1]) * 0.5;
    side = (sig[0] - sig[1]) * 0.5 * width;
    side = DelayC.ar(side, 0.01, delay);
    l = mid + side;
    r = mid - side;
    sig = [l, r] * makeup;
    ReplaceOut.ar(0, sig);
}}).add;
)
"""


# ---------------------------------------------------------------------------
#  Recettes par categorie -- dictionnaires (template, base_params, comment)
# ---------------------------------------------------------------------------

# Helper pour generer N variants d'un original via grille de parametres.
def grid(params_list):
    """params_list: liste de dicts. Retourne la liste telle quelle, max N=19."""
    return params_list[:19]


# Helper saturation choices
SAT_CHOICES = ["tanh", "softclip", "tanh", "tanh", "softclip"]

def sat_for(i):
    return SAT_CHOICES[i % len(SAT_CHOICES)]


# ============================================================================
# DRUMS  (11 originaux)
# ============================================================================

def drums_recipes():
    """Pour chaque original drum, 19 variants."""
    out = {}

    # --- kick ------------------------------------------------------------
    kick_variants = []
    freqs = [40, 45, 50, 55, 60, 65, 70, 80]
    for i in range(7):
        kick_variants.append((KICK_BASIC, {
            "freq": freqs[i % len(freqs)],
            "pitch_amt": [2.5, 3.0, 3.5, 4.0, 5.0, 2.0, 6.0][i],
            "pitch_time": [0.025, 0.035, 0.045, 0.055, 0.02, 0.04, 0.06][i],
            "decay": [0.25, 0.3, 0.35, 0.4, 0.5, 0.6, 0.28][i],
            "drive": [1.1, 1.3, 1.5, 1.8, 2.0, 1.2, 1.6][i],
            "click": [0.15, 0.2, 0.25, 0.3, 0.1, 0.4, 0.18][i],
            "amp": 0.5,
            "sc_shape": [0.15, 0.18, 0.22, 0.2, 0.16, 0.25, 0.18][i],
            "curve": [-2, -3, -4, -3, -2, -5, -3][i],
            "body_ugen": ["SinOsc", "SinOsc", "LFTri", "SinOsc", "SinOsc", "LFTri", "SinOsc"][i],
            "sub_ratio": [0.5, 0.5, 0.5, 0.25, 0.5, 0.5, 0.33][i],
            "sub_amp": [0.3, 0.3, 0.4, 0.5, 0.2, 0.3, 0.35][i],
            "click_hpf": [3000, 3500, 4000, 2500, 5000, 2000, 3000][i],
            "click_decay": 0.004,
            "amp_curve": -3,
            "sat": sat_for(i),
        }, "variation kick basique"))
    fm_drives = [1.0, 1.5, 2.0, 2.5, 1.2, 3.0]
    fm_ratios = [0.5, 1.0, 1.5, 2.0, 2.5, 3.0]
    fm_indices = [200, 400, 800, 1200, 600, 300]
    for i in range(6):
        kick_variants.append((KICK_FM, {
            "freq": [55, 60, 50, 45, 65, 70][i],
            "ratio": fm_ratios[i],
            "mod_index": fm_indices[i],
            "decay": [0.3, 0.4, 0.35, 0.5, 0.25, 0.6][i],
            "drive": fm_drives[i],
            "click": [0.2, 0.3, 0.15, 0.25, 0.1, 0.35][i],
            "amp": 0.5,
            "sc_shape": 0.18,
            "pitch_amt": [3.0, 4.0, 2.5, 5.0, 3.5, 6.0][i],
            "pitch_time": [0.04, 0.05, 0.03, 0.045, 0.06, 0.035][i],
            "sat": sat_for(i),
        }, "variation kick FM 2-op"))
    for i in range(6):
        kick_variants.append((KICK_DISTORTED, {
            "freq": [55, 60, 50, 45, 65, 70][i],
            "decay": [0.3, 0.35, 0.4, 0.5, 0.25, 0.45][i],
            "drive": [3.0, 5.0, 8.0, 12.0, 4.0, 6.0][i],
            "fold": [0.6, 0.7, 0.8, 0.9, 0.5, 0.85][i],
            "amp": 0.45,
            "sc_shape": 0.18,
            "body_ugen": ["SinOsc", "LFTri", "Saw", "Pulse", "SinOsc", "LFTri"][i],
            "sat": ["tanh", "tanh", "softclip", "tanh", "tanh", "softclip"][i],
        }, "variation kick distordu / gabber"))
    out["kick"] = kick_variants[:19]

    # --- kick808 ---------------------------------------------------------
    k808 = []
    for i in range(19):
        k808.append((KICK_BASIC, {
            "freq": [35, 40, 45, 50, 55, 60, 38, 42, 48, 52, 36, 44, 46, 54, 58, 62, 39, 41, 43][i],
            "pitch_amt": [1.5, 2.0, 2.5, 3.0][i % 4],
            "pitch_time": [0.04, 0.05, 0.06, 0.07, 0.08][i % 5],
            "decay": [0.4, 0.5, 0.6, 0.8, 1.0, 0.7, 0.9][i % 7],
            "drive": [1.0, 1.2, 1.4, 1.6][i % 4],
            "click": [0.05, 0.1, 0.15, 0.2][i % 4],
            "amp": 0.5,
            "sc_shape": 0.22,
            "curve": -3,
            "body_ugen": "SinOsc",
            "sub_ratio": [0.5, 0.5, 0.25, 0.5][i % 4],
            "sub_amp": [0.5, 0.6, 0.4, 0.7][i % 4],
            "click_hpf": [2500, 3000, 3500][i % 3],
            "click_decay": 0.003,
            "amp_curve": -4,
            "sat": sat_for(i),
        }, "variation kick 808 sub deep"))
    out["kick808"] = k808

    # --- kick_gabber -----------------------------------------------------
    kg = []
    for i in range(19):
        kg.append((KICK_DISTORTED, {
            "freq": [50, 55, 60, 65, 70, 75, 80, 45, 85, 90][i % 10],
            "decay": [0.2, 0.25, 0.3, 0.35][i % 4],
            "drive": [4, 6, 8, 10, 12, 16, 20][i % 7],
            "fold": [0.7, 0.8, 0.9, 0.95][i % 4],
            "amp": 0.4,
            "sc_shape": 0.16,
            "body_ugen": ["LFTri", "Saw", "Pulse", "SinOsc"][i % 4],
            "sat": ["tanh", "softclip"][i % 2],
        }, "variation gabber stomp distordu"))
    out["kick_gabber"] = kg

    # --- snare -----------------------------------------------------------
    sn = []
    for i in range(19):
        sn.append((SNARE_TPL, {
            "freq": [180, 200, 220, 240, 260, 160, 280, 300][i % 8],
            "decay": [0.1, 0.15, 0.2, 0.25, 0.3][i % 5],
            "tone": [0.3, 0.4, 0.5, 0.6, 0.2][i % 5],
            "noise": [0.5, 0.6, 0.7, 0.8, 0.4][i % 5],
            "drive": [1.2, 1.5, 2.0, 2.5][i % 4],
            "amp": 0.35,
            "hpf": [800, 1000, 1500, 2000, 600][i % 5],
            "curve": [-3, -4, -5, -2][i % 4],
            "sat": sat_for(i),
        }, "variation snare standard"))
    out["snare"] = sn

    # --- snare_gated -----------------------------------------------------
    sg = []
    for i in range(19):
        sg.append((SNARE_TPL, {
            "freq": [200, 220, 240][i % 3],
            "decay": [0.05, 0.07, 0.09, 0.11][i % 4],
            "tone": [0.4, 0.5][i % 2],
            "noise": [0.7, 0.8, 0.9][i % 3],
            "drive": [2.0, 3.0, 4.0, 5.0][i % 4],
            "amp": 0.4,
            "hpf": [1500, 2000, 2500][i % 3],
            "curve": [-6, -8, -10][i % 3],
            "sat": "tanh",
        }, "variation snare gated punchy"))
    out["snare_gated"] = sg

    # --- clap ------------------------------------------------------------
    cl = []
    for i in range(19):
        cl.append((CLAP_TPL, {
            "decay": [0.1, 0.15, 0.2, 0.25, 0.3][i % 5],
            "hpf": [800, 1000, 1500, 2000, 1200][i % 5],
            "drive": [1.0, 1.3, 1.6, 2.0][i % 4],
            "amp": 0.3,
            "curve": [-3, -4, -5, -6][i % 4],
            "sat": sat_for(i),
        }, "variation clap multi-transient"))
    out["clap"] = cl

    # --- hat -------------------------------------------------------------
    ht = []
    for i in range(19):
        ht.append((HAT_TPL, {
            "decay": [0.04, 0.05, 0.06, 0.08, 0.1, 0.07][i % 6],
            "hpf": [6000, 7000, 8000, 9000, 10000, 5000][i % 6],
            "bpf": [10000, 11000, 12000, 9000, 8000, 13000][i % 6],
            "rq": [0.4, 0.5, 0.6, 0.3][i % 4],
            "drive": [1.0, 1.2, 1.4][i % 3],
            "amp": 0.2,
            "curve": [-3, -4, -5, -6][i % 4],
            "sat": sat_for(i),
        }, "variation hat closed"))
    out["hat"] = ht

    # --- open_hat --------------------------------------------------------
    oh = []
    for i in range(19):
        oh.append((HAT_TPL, {
            "decay": [0.2, 0.3, 0.4, 0.5, 0.25, 0.35][i % 6],
            "hpf": [5000, 6000, 7000, 8000][i % 4],
            "bpf": [8000, 9000, 10000, 11000][i % 4],
            "rq": [0.5, 0.6, 0.7][i % 3],
            "drive": [1.0, 1.2][i % 2],
            "amp": 0.18,
            "curve": [-2, -3, -4][i % 3],
            "sat": sat_for(i),
        }, "variation open hat plus long"))
    out["open_hat"] = oh

    # --- rim -------------------------------------------------------------
    rm = []
    for i in range(19):
        rm.append((PERC_METALLIC, {
            "freq": [800, 1000, 1200, 1500, 2000, 900, 1100][i % 7],
            "decay": [0.03, 0.05, 0.07, 0.04, 0.06][i % 5],
            "ratio": [0.4, 0.5, 0.6, 0.7, 0.3][i % 5],
            "amp": 0.25,
        }, "variation rim shot metallique"))
    out["rim"] = rm

    # --- tom -------------------------------------------------------------
    tm = []
    for i in range(19):
        tm.append((TOM_TPL, {
            "freq": [80, 100, 120, 140, 160, 180, 200, 220, 70, 90][i % 10],
            "decay": [0.2, 0.3, 0.4, 0.5][i % 4],
            "drive": [1.0, 1.3, 1.6, 2.0][i % 4],
            "amp": 0.4,
            "pitch_amt": [2.0, 2.5, 3.0, 3.5, 4.0][i % 5],
            "pitch_time": [0.03, 0.04, 0.05, 0.06][i % 4],
            "body_ugen": ["SinOsc", "LFTri"][i % 2],
            "sat": sat_for(i),
        }, "variation tom pitched"))
    out["tom"] = tm

    # --- cowbell ---------------------------------------------------------
    cb = []
    for i in range(19):
        cb.append((PERC_METALLIC, {
            "freq": [540, 560, 580, 600, 620, 640, 660, 500, 700][i % 9],
            "decay": [0.1, 0.15, 0.2, 0.25, 0.3][i % 5],
            "ratio": [0.485, 0.5, 0.515, 0.47, 0.53][i % 5],
            "amp": 0.25,
        }, "variation cowbell partials"))
    out["cowbell"] = cb

    return out


# ============================================================================
# BASS  (9 originaux)
# ============================================================================

def bass_recipes():
    out = {}

    # --- acid ------------------------------------------------------------
    ac = []
    for i in range(19):
        ac.append((BASS_ACID_TB303, {
            "freq": 110,
            "slide_time": [0.005, 0.01, 0.02, 0.04][i % 4],
            "cutoff": [400, 600, 800, 1000, 1200, 1500, 500, 700][i % 8],
            "cutoff_env": [2000, 2500, 3000, 3500, 4000, 5000, 6000][i % 7],
            "rq": [0.1, 0.15, 0.2, 0.25, 0.3, 0.08][i % 6],
            "env_decay": [0.2, 0.3, 0.4, 0.5, 0.25, 0.35][i % 6],
            "amp_decay": [0.2, 0.25, 0.3, 0.35, 0.4][i % 5],
            "drive": [1.5, 2.0, 2.5, 3.0, 3.5, 4.0][i % 6],
            "amp": 0.32,
            "osc_ugen": ["Saw", "Pulse", "Saw", "Saw"][i % 4],
            "sat": sat_for(i),
        }, "variation acid TB-303"))
    out["acid"] = ac

    # --- bass808 ---------------------------------------------------------
    b8 = []
    for i in range(19):
        b8.append((BASS_SUB, {
            "freq": [40, 45, 50, 55, 60][i % 5],
            "attack": [0.001, 0.002, 0.005][i % 3],
            "decay": [0.5, 0.8, 1.0, 1.5, 2.0][i % 5],
            "sustain": [0.0, 0.1, 0.2][i % 3],
            "release": [0.1, 0.3, 0.5, 1.0][i % 4],
            "drive": [1.0, 1.2, 1.5, 2.0][i % 4],
            "amp": 0.4,
            "osc_ugen": ["SinOsc", "LFTri", "SinOsc"][i % 3],
            "sat": sat_for(i),
        }, "variation 808 bass sub long"))
    out["bass808"] = b8

    # --- fm_bass ---------------------------------------------------------
    fmb = []
    for i in range(19):
        fmb.append((BASS_FM, {
            "freq": 110,
            "ratio": [0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 0.25][i % 7],
            "mod_index": [50, 100, 200, 400, 600, 800, 1000][i % 7],
            "attack": 0.003,
            "decay": [0.2, 0.3, 0.4, 0.5][i % 4],
            "sustain": [0.4, 0.5, 0.6][i % 3],
            "release": [0.1, 0.2, 0.3][i % 3],
            "drive": [1.2, 1.5, 2.0, 2.5][i % 4],
            "amp": 0.3,
            "sat": sat_for(i),
        }, "variation FM bass 2-op"))
    out["fm_bass"] = fmb

    # --- reese -----------------------------------------------------------
    rs = []
    for i in range(19):
        rs.append((BASS_REESE, {
            "freq": 80,
            "detune": [0.005, 0.01, 0.015, 0.02, 0.025, 0.03][i % 6],
            "cutoff": [600, 800, 1000, 1200, 1500, 2000][i % 6],
            "rq": [0.5, 0.6, 0.7, 0.8][i % 4],
            "attack": 0.01,
            "decay": [0.2, 0.3, 0.4][i % 3],
            "sustain": [0.6, 0.7, 0.8][i % 3],
            "release": [0.3, 0.5, 0.8][i % 3],
            "drive": [1.5, 2.0, 2.5][i % 3],
            "amp": 0.3,
            "third_factor": [2.0, 1.5, 2.5, 3.0][i % 4],
            "sat": sat_for(i),
        }, "variation reese 3 saws detunees"))
    out["reese"] = rs

    # --- reese_dn_b ------------------------------------------------------
    rdb = []
    for i in range(19):
        rdb.append((BASS_REESE, {
            "freq": [55, 60, 65, 70, 75][i % 5],
            "detune": [0.015, 0.02, 0.025, 0.03][i % 4],
            "cutoff": [400, 500, 600, 800, 1000][i % 5],
            "rq": [0.4, 0.5, 0.6][i % 3],
            "attack": 0.005,
            "decay": [0.15, 0.2, 0.25][i % 3],
            "sustain": [0.7, 0.8, 0.9][i % 3],
            "release": [0.2, 0.3][i % 2],
            "drive": [2.0, 2.5, 3.0, 3.5][i % 4],
            "amp": 0.32,
            "third_factor": 2.0,
            "sat": "tanh",
        }, "variation reese DnB neuro"))
    out["reese_dn_b"] = rdb

    # --- reese_hard -----------------------------------------------------
    rh = []
    for i in range(19):
        rh.append((BASS_REESE, {
            "freq": [50, 55, 60, 65][i % 4],
            "detune": [0.02, 0.025, 0.03, 0.035][i % 4],
            "cutoff": [350, 450, 600, 800][i % 4],
            "rq": [0.3, 0.4, 0.5][i % 3],
            "attack": 0.003,
            "decay": [0.1, 0.15, 0.2][i % 3],
            "sustain": [0.8, 0.9][i % 2],
            "release": 0.15,
            "drive": [3.0, 4.0, 5.0, 6.0][i % 4],
            "amp": 0.35,
            "third_factor": 2.5,
            "sat": "tanh",
        }, "variation reese hard distordu"))
    out["reese_hard"] = rh

    # --- hooverbass -----------------------------------------------------
    hv = []
    for i in range(19):
        hv.append((BASS_REESE, {
            "freq": [80, 90, 100, 110][i % 4],
            "detune": [0.015, 0.02, 0.025][i % 3],
            "cutoff": [800, 1200, 1600, 2000][i % 4],
            "rq": [0.5, 0.6, 0.7, 0.8][i % 4],
            "attack": 0.005,
            "decay": [0.2, 0.3, 0.4][i % 3],
            "sustain": [0.7, 0.8, 0.9][i % 3],
            "release": [0.3, 0.5][i % 2],
            "drive": [1.5, 2.0, 2.5][i % 3],
            "amp": 0.28,
            "third_factor": [1.5, 2.0, 2.5, 3.0][i % 4],
            "sat": sat_for(i),
        }, "variation hoover bass"))
    out["hooverbass"] = hv

    # --- sub_boom -------------------------------------------------------
    sb = []
    for i in range(19):
        sb.append((BASS_SUB, {
            "freq": [30, 35, 40, 45, 50][i % 5],
            "attack": [0.005, 0.01, 0.02][i % 3],
            "decay": [1.0, 1.5, 2.0, 3.0][i % 4],
            "sustain": [0.0, 0.1][i % 2],
            "release": [0.5, 1.0, 2.0][i % 3],
            "drive": [1.0, 1.2, 1.5][i % 3],
            "amp": 0.4,
            "osc_ugen": ["SinOsc", "LFTri"][i % 2],
            "sat": sat_for(i),
        }, "variation sub boom long"))
    out["sub_boom"] = sb

    # --- didgeridoo -----------------------------------------------------
    dd = []
    for i in range(19):
        dd.append((BASS_WOBBLE, {
            "freq": [55, 60, 65, 70, 75, 80][i % 6],
            "lfo_rate": [3, 4, 5, 6, 8, 10, 12][i % 7],
            "lfo_depth": [0.4, 0.5, 0.6, 0.7][i % 4],
            "cutoff": [600, 800, 1000, 1200][i % 4],
            "rq": [0.4, 0.5, 0.6][i % 3],
            "attack": 0.05,
            "decay": [0.3, 0.5, 0.8][i % 3],
            "sustain": [0.7, 0.8, 0.9][i % 3],
            "release": [0.5, 0.8, 1.2][i % 3],
            "drive": [1.5, 2.0, 2.5][i % 3],
            "amp": 0.3,
            "sat": sat_for(i),
        }, "variation didgeridoo wobble"))
    out["didgeridoo"] = dd

    return out


# ============================================================================
# LEAD  (12 originaux)
# ============================================================================

def lead_recipes():
    out = {}

    def supersaw_set(label, base_freq=220):
        v = []
        ranges = ["(-2..2)", "(-3..3)", "(-4..4)"]
        centers = [2, 3, 4]
        for i in range(19):
            ridx = i % 3
            v.append((LEAD_SUPERSAW, {
                "freq": base_freq,
                "detune": [0.008, 0.012, 0.016, 0.02, 0.024, 0.028][i % 6],
                "mix": [0.3, 0.4, 0.5, 0.6, 0.7][i % 5],
                "cutoff": [3000, 4000, 5000, 6000, 7000, 8000][i % 6],
                "rq": [0.4, 0.5, 0.6, 0.7][i % 4],
                "attack": [0.005, 0.01, 0.02][i % 3],
                "decay": [0.1, 0.15, 0.2][i % 3],
                "sustain": [0.5, 0.6, 0.7][i % 3],
                "release": [0.3, 0.4, 0.5][i % 3],
                "drive": [1.0, 1.2, 1.4, 1.6][i % 4],
                "amp": 0.16,
                "voice_range": ranges[ridx],
                "center_idx": centers[ridx],
                "sat": sat_for(i),
            }, f"variation {label} supersaw"))
        return v

    def fm_set(label, base_freq=220):
        v = []
        for i in range(19):
            v.append((LEAD_FM, {
                "freq": base_freq,
                "ratio": [0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 4.0, 0.25][i % 8],
                "mod_index": [50, 100, 200, 300, 500, 700, 1000][i % 7],
                "mod_decay": [0.05, 0.1, 0.2, 0.5, 1.0][i % 5],
                "attack": [0.005, 0.01, 0.02][i % 3],
                "decay": [0.1, 0.2, 0.3][i % 3],
                "sustain": [0.4, 0.5, 0.6][i % 3],
                "release": [0.2, 0.3, 0.5][i % 3],
                "drive": [1.0, 1.2, 1.5][i % 3],
                "amp": 0.18,
                "sat": sat_for(i),
            }, f"variation {label} FM 2-op"))
        return v

    def pluck_set(label, base_freq=220):
        v = []
        for i in range(19):
            v.append((LEAD_PLUCK_KS, {
                "freq": base_freq,
                "decay_time": [0.5, 1.0, 1.5, 2.0, 2.5, 3.0][i % 6],
                "exciter_decay": [0.003, 0.005, 0.008, 0.01][i % 4],
                "cutoff": [3000, 4000, 5000, 6000][i % 4],
                "attack": 0.001,
                "decay": [0.1, 0.2, 0.3][i % 3],
                "sustain": [0.0, 0.1][i % 2],
                "release": [0.3, 0.5, 0.8][i % 3],
                "drive": [1.0, 1.2, 1.5, 2.0][i % 4],
                "amp": 0.22,
                "sat": sat_for(i),
            }, f"variation {label} pluck Karplus-Strong"))
        return v

    def pulse_set(label, base_freq=220):
        v = []
        for i in range(19):
            v.append((LEAD_PULSE_PWM, {
                "freq": base_freq,
                "pwm_rate": [0.5, 1.0, 2.0, 3.0, 4.0, 6.0][i % 6],
                "pwm_depth": [0.1, 0.2, 0.3, 0.4][i % 4],
                "cutoff": [3000, 4000, 5000, 6000][i % 4],
                "rq": [0.4, 0.5, 0.6][i % 3],
                "attack": [0.005, 0.01][i % 2],
                "decay": [0.1, 0.2, 0.3][i % 3],
                "sustain": [0.5, 0.6, 0.7][i % 3],
                "release": [0.3, 0.5][i % 2],
                "drive": [1.0, 1.2, 1.5][i % 3],
                "amp": 0.18,
                "sat": sat_for(i),
            }, f"variation {label} pulse PWM"))
        return v

    def bell_set(label, base_freq=220):
        v = []
        for i in range(19):
            v.append((LEAD_BELL, {
                "freq": base_freq,
                "n_partials": [3, 4, 5, 6, 7][i % 5],
                "bell_decay": [0.5, 1.0, 1.5, 2.0, 2.5][i % 5],
                "attack": [0.005, 0.01][i % 2],
                "decay": [0.2, 0.3, 0.5][i % 3],
                "sustain": [0.0, 0.2][i % 2],
                "release": [0.5, 1.0, 1.5][i % 3],
                "drive": [1.0, 1.2][i % 2],
                "amp": 0.2,
                "sat": sat_for(i),
            }, f"variation {label} bell-like modal"))
        return v

    def stab_set(label, base_freq=220):
        v = []
        for i in range(19):
            v.append((LEAD_STAB, {
                "freq": base_freq,
                "cutoff": [400, 600, 800, 1000][i % 4],
                "cutoff_env": [2000, 3000, 4000, 5000][i % 4],
                "f_env_decay": [0.05, 0.1, 0.15, 0.2][i % 4],
                "rq": [0.3, 0.4, 0.5][i % 3],
                "attack": 0.001,
                "decay": [0.05, 0.1, 0.15][i % 3],
                "sustain": [0.0, 0.1][i % 2],
                "release": [0.1, 0.2][i % 2],
                "drive": [1.5, 2.0, 2.5, 3.0][i % 4],
                "amp": 0.22,
                "osc_ugen": ["Saw", "Pulse"][i % 2],
                "sat": sat_for(i),
            }, f"variation {label} stab court"))
        return v

    out["supersaw"] = supersaw_set("supersaw")
    out["saw3"] = supersaw_set("saw3", base_freq=200)
    out["lead"] = supersaw_set("lead", base_freq=440)
    out["hard_lead"] = supersaw_set("hard_lead", base_freq=330)
    out["fm_lead"] = fm_set("fm_lead")
    out["fm_bell"] = bell_set("fm_bell", base_freq=440)
    out["pluck"] = pluck_set("pluck")
    out["square_lead"] = pulse_set("square_lead")
    out["organ_lead"] = bell_set("organ_lead", base_freq=220)
    out["rhodes"] = bell_set("rhodes", base_freq=330)
    out["flute"] = pluck_set("flute_lead", base_freq=440)
    out["stab"] = stab_set("stab")

    return out


# ============================================================================
# PAD  (6 originaux)
# ============================================================================

def pad_recipes():
    out = {}

    def string_set(label, base_freq=220):
        v = []
        for i in range(19):
            n = [3, 5, 7][i % 3]
            v.append((PAD_STRING, {
                "freq": base_freq,
                "detune": [0.006, 0.01, 0.014, 0.018, 0.022][i % 5],
                "cutoff": [1200, 1800, 2400, 3000, 3600][i % 5],
                "rq": [0.4, 0.5, 0.6, 0.7][i % 4],
                "attack": [0.2, 0.4, 0.6, 0.8, 1.0][i % 5],
                "decay": [0.2, 0.3, 0.4][i % 3],
                "sustain": [0.6, 0.7, 0.8][i % 3],
                "release": [1.0, 1.5, 2.0, 2.5][i % 4],
                "drive": [1.0, 1.1, 1.2][i % 3],
                "amp": 0.15,
                "n_voices": n,
                "center": n // 2,
                "chorus_rate": [0.2, 0.3, 0.4, 0.5][i % 4],
                "sat": sat_for(i),
            }, f"variation {label} string saws"))
        return v

    def bell_set(label, base_freq=220):
        v = []
        for i in range(19):
            v.append((PAD_BELL, {
                "freq": base_freq,
                "n_partials": [4, 5, 6, 7, 8][i % 5],
                "ratio_step": [0.97, 0.99, 1.0, 1.01, 1.03][i % 5],
                "lfo_rate": [0.1, 0.2, 0.3, 0.5][i % 4],
                "attack": [0.3, 0.5, 0.8][i % 3],
                "decay": [0.5, 0.8, 1.0][i % 3],
                "sustain": [0.6, 0.7][i % 2],
                "release": [1.5, 2.0, 3.0][i % 3],
                "drive": [1.0, 1.1][i % 2],
                "amp": 0.16,
                "sat": sat_for(i),
            }, f"variation {label} bell pad"))
        return v

    def drone_set(label, base_freq=110):
        v = []
        for i in range(19):
            v.append((PAD_DRONE, {
                "freq": base_freq,
                "detune": [0.005, 0.01, 0.015, 0.02][i % 4],
                "cutoff": [800, 1200, 1600, 2000, 2500][i % 5],
                "rq": [0.4, 0.5, 0.6, 0.7, 0.8][i % 5],
                "attack": [0.5, 1.0, 1.5, 2.0][i % 4],
                "decay": [0.5, 1.0, 1.5][i % 3],
                "sustain": [0.7, 0.8, 0.9][i % 3],
                "release": [2.0, 3.0, 4.0, 5.0][i % 4],
                "drive": [1.0, 1.2, 1.4][i % 3],
                "amp": 0.18,
                "lfo_rate": [0.1, 0.15, 0.2, 0.25][i % 4],
                "osc_ugen": ["Saw", "Pulse", "LFTri"][i % 3],
                "sat": sat_for(i),
            }, f"variation {label} drone slow"))
        return v

    def choir_set(label, base_freq=220):
        v = []
        for i in range(19):
            v.append((PAD_CHOIR, {
                "freq": base_freq,
                "detune": [0.01, 0.014, 0.018, 0.022][i % 4],
                "formant1": [600, 700, 800, 900, 1000][i % 5],
                "formant2": [1800, 2000, 2200, 2400, 2600][i % 5],
                "attack": [0.4, 0.6, 0.8, 1.0][i % 4],
                "decay": [0.3, 0.5, 0.7][i % 3],
                "sustain": [0.6, 0.7, 0.8][i % 3],
                "release": [1.5, 2.0, 2.5, 3.0][i % 4],
                "drive": [1.0, 1.1, 1.2][i % 3],
                "amp": 0.15,
                "n_voices": [3, 4, 5][i % 3],
                "sat": sat_for(i),
            }, f"variation {label} choir formant"))
        return v

    out["pad"] = string_set("pad")
    out["strings"] = string_set("strings", base_freq=330)
    out["warm_pad"] = string_set("warm_pad", base_freq=220)
    out["choir"] = choir_set("choir")
    out["vocal_pad"] = choir_set("vocal_pad", base_freq=330)
    out["drone"] = drone_set("drone")

    return out


# ============================================================================
# WORLD  (10 originaux)
# ============================================================================

def world_recipes():
    out = {}

    def pluck_world(label, base_freq=330):
        v = []
        for i in range(19):
            v.append((WORLD_PLUCK, {
                "freq": base_freq,
                "bend_amt": [0.02, 0.03, 0.04, 0.05, 0.06][i % 5],
                "bend_time": [0.05, 0.08, 0.1, 0.12][i % 4],
                "cutoff": [3000, 4000, 5000, 6000][i % 4],
                "rq": [0.3, 0.4, 0.5][i % 3],
                "attack": 0.001,
                "decay": [0.05, 0.08, 0.1][i % 3],
                "sustain": [0.0, 0.1][i % 2],
                "release": [0.3, 0.5, 0.8][i % 3],
                "drive": [1.0, 1.3, 1.6, 2.0][i % 4],
                "amp": 0.22,
                "exciter_decay": [0.003, 0.005, 0.007][i % 3],
                "ks_decay": [1.5, 1.8, 2.0, 2.5, 3.0][i % 5],
                "sat": sat_for(i),
            }, f"variation {label} pluck Karplus"))
        return v

    def drum_world(label, base_freq=120):
        v = []
        for i in range(19):
            v.append((WORLD_DRUM_PITCHED, {
                "freq": base_freq,
                "decay_time": [0.2, 0.3, 0.4][i % 3],
                "noise_amt": [0.2, 0.3, 0.4, 0.5][i % 4],
                "decay": [0.2, 0.3, 0.4, 0.5][i % 4],
                "drive": [1.0, 1.3, 1.6][i % 3],
                "amp": 0.32,
                "pitch_amt": [2.0, 3.0, 4.0, 5.0][i % 4],
                "pitch_time": [0.03, 0.05, 0.07, 0.1][i % 4],
                "sat": sat_for(i),
            }, f"variation {label} drum pitched"))
        return v

    def gong_world(label, base_freq=80):
        v = []
        for i in range(19):
            v.append((WORLD_GONG, {
                "freq": base_freq,
                "n_partials": [4, 5, 6, 7, 8][i % 5],
                "partial_decay": [0.5, 1.0, 1.5, 2.0, 3.0][i % 5],
                "decay": [0.5, 1.0, 1.5][i % 3],
                "release": [2.0, 3.0, 4.0][i % 3],
                "drive": [1.0, 1.2, 1.4][i % 3],
                "amp": 0.25,
                "sat": sat_for(i),
            }, f"variation {label} gong modal"))
        return v

    def flute_world(label, base_freq=440):
        v = []
        for i in range(19):
            v.append((WORLD_FLUTE, {
                "freq": base_freq,
                "breath": [0.05, 0.1, 0.15, 0.2][i % 4],
                "cutoff": [3000, 4000, 5000][i % 3],
                "rq": [0.3, 0.5, 0.7][i % 3],
                "attack": [0.05, 0.1, 0.2][i % 3],
                "decay": [0.1, 0.2, 0.3][i % 3],
                "sustain": [0.6, 0.7, 0.8][i % 3],
                "release": [0.3, 0.5, 0.8][i % 3],
                "drive": [1.0, 1.2][i % 2],
                "amp": 0.2,
                "vib_rate": [4, 5, 6, 7][i % 4],
                "vib_depth": [0.005, 0.01, 0.015][i % 3],
                "sat": sat_for(i),
            }, f"variation {label} flute"))
        return v

    def drone_world(label, base_freq=80):
        v = []
        for i in range(19):
            v.append((WORLD_DRONE, {
                "freq": base_freq,
                "formant_freq": [200, 300, 400, 500, 600][i % 5],
                "lpf_cutoff": [800, 1200, 1600, 2000][i % 4],
                "lfo_rate": [3, 5, 7, 9, 12][i % 5],
                "attack": [0.05, 0.1, 0.2][i % 3],
                "decay": [0.3, 0.5][i % 2],
                "sustain": [0.7, 0.8, 0.9][i % 3],
                "release": [0.5, 1.0, 1.5][i % 3],
                "drive": [1.5, 2.0, 2.5][i % 3],
                "amp": 0.28,
                "sat": sat_for(i),
            }, f"variation {label} drone formant"))
        return v

    out["pipa"] = pluck_world("pipa", base_freq=330)
    out["koto"] = pluck_world("koto", base_freq=330)
    out["guzheng"] = pluck_world("guzheng", base_freq=330)
    out["handpan"] = pluck_world("handpan", base_freq=220)
    out["tabla"] = drum_world("tabla", base_freq=180)
    out["taiko"] = drum_world("taiko", base_freq=80)
    out["gong"] = gong_world("gong", base_freq=80)
    out["growl"] = drone_world("growl", base_freq=60)
    out["shakuhachi"] = flute_world("shakuhachi", base_freq=440)
    out["erhu"] = flute_world("erhu", base_freq=440)
    out["didgeridoo_world"] = drone_world("didgeridoo_world", base_freq=70)  # not duplicated

    return out


# ============================================================================
# MASTER  (4 originaux)
# ============================================================================

def master_recipes():
    out = {}

    mc = []
    for i in range(19):
        mc.append((MASTER_COMP, {
            "threshold": [0.2, 0.3, 0.4, 0.5, 0.6][i % 5],
            "ratio": [0.3, 0.4, 0.5, 0.6, 0.7][i % 5],
            "attack": [0.005, 0.01, 0.02][i % 3],
            "release": [0.05, 0.1, 0.2, 0.3][i % 4],
            "makeup": [1.1, 1.2, 1.4, 1.6, 1.8][i % 5],
        }, "variation master compressor"))
    out["master_comp"] = mc

    ml = []
    for i in range(19):
        ml.append((MASTER_LIM, {
            "threshold": [0.7, 0.8, 0.9, 0.95, 0.99][i % 5],
            "look_ahead": [0.005, 0.01, 0.02][i % 3],
            "makeup": [1.0, 1.1, 1.2, 1.4][i % 4],
        }, "variation master limiter"))
    out["master_lim"] = ml

    ms = []
    for i in range(19):
        # alterne saturator vs EQ vs widen
        cat = i % 3
        if cat == 0:
            ms.append((MASTER_SAT, {
                "drive": [1.2, 1.5, 2.0, 3.0, 4.0][i % 5],
                "mix": [0.3, 0.5, 0.7, 0.9][i % 4],
                "makeup": [0.8, 0.9, 1.0][i % 3],
                "sat": ["tanh", "softclip"][i % 2],
            }, "variation master saturation"))
        elif cat == 1:
            ms.append((MASTER_EQ, {
                "low_cut": [20, 30, 40, 50, 60][i % 5],
                "high_shelf_freq": [4000, 6000, 8000, 10000][i % 4],
                "high_shelf_gain": [0.5, 1.0, 1.5, 2.0][i % 4],
                "makeup": [1.0, 1.1, 1.2][i % 3],
            }, "variation master EQ"))
        else:
            ms.append((MASTER_WIDEN, {
                "width": [0.8, 1.0, 1.2, 1.5, 2.0][i % 5],
                "delay": [0.001, 0.003, 0.005, 0.008][i % 4],
                "makeup": [0.95, 1.0, 1.05][i % 3],
            }, "variation master stereo widener"))
    out["master_sat"] = ms

    vn = []
    for i in range(19):
        cat = i % 2
        if cat == 0:
            vn.append((MASTER_SAT, {
                "drive": [1.5, 2.0, 3.0][i % 3],
                "mix": [0.4, 0.6, 0.8][i % 3],
                "makeup": [0.85, 0.9, 0.95][i % 3],
                "sat": "tanh",
            }, "variation vinyl warmth saturation"))
        else:
            vn.append((MASTER_EQ, {
                "low_cut": [60, 80, 100][i % 3],
                "high_shelf_freq": [3000, 4000, 5000][i % 3],
                "high_shelf_gain": [-2.0, -1.0, -0.5, 0.5][i % 4],
                "makeup": [1.0, 1.05, 1.1][i % 3],
            }, "variation vinyl tone shape"))
    out["vinyl"] = vn

    return out


# ---------------------------------------------------------------------------
#  Generation
# ---------------------------------------------------------------------------

CATEGORIES = {
    "drums": drums_recipes,
    "bass": bass_recipes,
    "lead": lead_recipes,
    "pad": pad_recipes,
    "world": world_recipes,
    "master": master_recipes,
}


def render(template, params, name, comment):
    p = dict(params)
    p["name"] = name
    p["comment"] = comment
    return template.format(**p)


def main():
    written = 0
    failures = []
    seen_names = set()
    duplicates = []
    counts = {}

    for cat, recipe_fn in CATEGORIES.items():
        recipes = recipe_fn()
        cat_dir = SYNTH_DIR / cat
        cat_dir.mkdir(parents=True, exist_ok=True)
        cat_count = 0

        for original_name, variants in recipes.items():
            for idx, (tpl, params, comment_base) in enumerate(variants, start=1):
                vname = f"{original_name}_v{idx}"
                fname = cat_dir / f"{vname}.scd"
                full_comment = (
                    f"synth/{cat}/{vname}.scd  --  SynthDef \\{vname}  "
                    f"// {comment_base}"
                )
                content = render(tpl, params, vname, full_comment)
                p, b = balance_check(content)
                if (p, b) != (0, 0):
                    failures.append((str(fname), p, b))
                    continue
                if vname in seen_names:
                    duplicates.append(vname)
                    continue
                seen_names.add(vname)
                fname.write_text(content, encoding="utf-8")
                written += 1
                cat_count += 1

        counts[cat] = cat_count

    print("=" * 60)
    print(f"Total nouveaux fichiers ecrits : {written}")
    print("Repartition par categorie :")
    for cat, n in counts.items():
        print(f"  {cat:8s} : {n}")
    print(f"Failures balance : {len(failures)}")
    for f in failures[:10]:
        print(f"  KO {f}")
    print(f"Duplicate names skipped : {len(duplicates)}")
    if duplicates[:10]:
        print(f"  ex : {duplicates[:10]}")
    return 0 if not failures else 1


if __name__ == "__main__":
    sys.exit(main())

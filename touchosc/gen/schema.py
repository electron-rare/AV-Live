"""TouchOSC v3 (.tosc) layout schema and serializer.

A ``.tosc`` file is a gzip-compressed XML document whose root is
``<lexml version="3">`` containing a single root ``<node>``.  This module
emits that format with ``xml.etree.ElementTree``.  The exact byte-shape
(partials as child elements, frame ``r`` / color ``c`` value shapes, the
``connections`` bit-string) was pinned against a file that the desktop
TouchOSC app actually loads and re-saves on GrosMac.  See
``docs/superpowers/specs/2026-06-28-tosc-schema-reference.md``.
"""

import gzip
import uuid
import xml.etree.ElementTree as ET

# connections bit-string: one '0'/'1' flag per available OSC connection,
# left-to-right = connection 1..N.  TouchOSC writes 5 flags; a fresh
# message targets connection 1 only.  Confirmed from a TouchOSC re-save.
CONN_DEFAULT = "00001"


def tosc_id():
    """Fresh UUID string for a node ID."""
    return str(uuid.uuid4())


def _set_text(parent, tag, text):
    e = ET.SubElement(parent, tag)
    e.text = str(text)
    return e


def prop(key, value, typ):
    """One ``<property type="..">`` with ``<key>``/``<value>`` children."""
    p = ET.Element("property", {"type": typ})
    _set_text(p, "key", key)
    _set_text(p, "value", value)
    return p


def frame(x, y, w, h):
    """The ``frame`` property (type ``r``) — value holds x/y/w/h children."""
    p = ET.Element("property", {"type": "r"})
    _set_text(p, "key", "frame")
    v = ET.SubElement(p, "value")
    for tag, n in (("x", x), ("y", y), ("w", w), ("h", h)):
        _set_text(v, tag, n)
    return p


def color(r, g, b, a=1.0):
    """The ``color`` property (type ``c``) — value holds r/g/b/a children."""
    p = ET.Element("property", {"type": "c"})
    _set_text(p, "key", "color")
    v = ET.SubElement(p, "value")
    for tag, n in (("r", r), ("g", g), ("b", b), ("a", a)):
        _set_text(v, tag, n)
    return p


class Partial:
    """One ``<partial>`` of an OSC path or argument list.

    Fields are emitted as *child elements* (not attributes), matching the
    format TouchOSC writes.
    """

    def __init__(self, kind, conversion, value, scale_min=0, scale_max=1):
        self.kind = kind
        self.conversion = conversion
        self.value = value
        self.scale_min = scale_min
        self.scale_max = scale_max

    def to_el(self):
        p = ET.Element("partial")
        _set_text(p, "type", self.kind)
        _set_text(p, "conversion", self.conversion)
        _set_text(p, "value", self.value)
        _set_text(p, "scaleMin", self.scale_min)
        _set_text(p, "scaleMax", self.scale_max)
        return p


def const(s):
    """A CONSTANT/STRING partial — a fixed address segment or argument."""
    return Partial("CONSTANT", "STRING", s)


def consti(n):
    """A CONSTANT/INTEGER partial — a fixed integer arg."""
    return Partial("CONSTANT", "INTEGER", str(n))


def constf(x):
    """A CONSTANT/FLOAT partial — a fixed float arg."""
    return Partial("CONSTANT", "FLOAT", str(x))


def val():
    """A VALUE/FLOAT partial bound to the control's ``x`` value (scale 0..1)."""
    return Partial("VALUE", "FLOAT", "x")


def vali():
    """A VALUE/INTEGER partial — control value as int (button 0/1)."""
    return Partial("VALUE", "INTEGER", "x")


def valf(scale_min=0, scale_max=1):
    """A VALUE/FLOAT partial with a custom scale range (e.g. tempo 60..200)."""
    return Partial("VALUE", "FLOAT", "x", scale_min, scale_max)


def _trigger(var="x", condition="ANY"):
    t = ET.Element("trigger")
    _set_text(t, "var", var)
    _set_text(t, "condition", condition)
    return t


def osc(address, args, connections=CONN_DEFAULT, send=1, receive=0, feedback=0):
    """One ``<osc>`` message: triggers + path + arguments."""
    m = ET.Element("osc", {
        "enabled": "1",
        "send": str(send),
        "receive": str(receive),
        "feedback": str(feedback),
        "connections": connections,
    })
    triggers = ET.SubElement(m, "triggers")
    triggers.append(_trigger())
    path = ET.SubElement(m, "path")
    path.append(const(address).to_el())
    arguments = ET.SubElement(m, "arguments")
    for p in args:
        arguments.append(p.to_el())
    return m


def script(lua):
    """The ``script`` string property (Lua source, type ``s``)."""
    return prop("script", lua, "s")


def node(ntype, props, children=None, messages=None, values=None):
    """A ``<node>`` with properties/values/messages/children sub-blocks."""
    n = ET.Element("node", {"ID": tosc_id(), "type": ntype})
    ps = ET.SubElement(n, "properties")
    for p in props:
        ps.append(p)
    vs = ET.SubElement(n, "values")
    for v in (values or []):
        vs.append(v)
    ms = ET.SubElement(n, "messages")
    for m in (messages or []):
        ms.append(m)
    cs = ET.SubElement(n, "children")
    for c in (children or []):
        cs.append(c)
    return n


def write_tosc(root, path):
    """Serialize ``root`` under ``<lexml version="3">`` and gzip to ``path``."""
    lexml = ET.Element("lexml", {"version": "3"})
    lexml.append(root)
    xml = ET.tostring(lexml, encoding="UTF-8", xml_declaration=True)
    with gzip.open(path, "wb") as f:
        f.write(xml)


def read_tosc(path):
    """Gunzip + parse a ``.tosc``; return its root ``<node>`` element."""
    with gzip.open(path, "rb") as f:
        lexml = ET.fromstring(f.read())
    return lexml.find("node")

#!/usr/bin/env python3
"""Floating concert control panel.

A small always-on-top panel with a big "Morceau suivant" button that advances
the concert by sending OSC /control/concertNext (-> ~concert[\\next], random).

It is a NON-ACTIVATING NSPanel: clicking the button does NOT steal keyboard
focus from the viz window, so Space keeps working there too; and the click works
regardless of which window is key (so it is the reliable, focus-independent way
to change morceau). Launched by AV-Live Concert.app alongside the stack.

Run: <venv>/bin/python launcher/concert/concert_control.py
"""
from Foundation import NSObject, NSMakeRect
from AppKit import (
    NSApplication, NSPanel, NSButton, NSFont, NSScreen,
    NSBackingStoreBuffered, NSFloatingWindowLevel,
    NSApplicationActivationPolicyAccessory,
    NSWindowStyleMaskTitled, NSWindowStyleMaskClosable,
    NSWindowStyleMaskUtilityWindow, NSWindowStyleMaskNonactivatingPanel,
    NSBezelStyleRegularSquare,
)
from pythonosc.udp_client import SimpleUDPClient

SC = SimpleUDPClient("127.0.0.1", 57121)


class FirstClickButton(NSButton):
    """Trigger on the first click even when the panel is not the key window."""
    def acceptsFirstMouse_(self, event):  # noqa: N802
        return True


class Ctl(NSObject):
    def nextMorceau_(self, sender):  # noqa: N802
        SC.send_message("/control/concertNext", [1])


def main():
    app = NSApplication.sharedApplication()
    app.setActivationPolicy_(NSApplicationActivationPolicyAccessory)
    ctl = Ctl.alloc().init()

    style = (NSWindowStyleMaskTitled | NSWindowStyleMaskClosable
             | NSWindowStyleMaskUtilityWindow | NSWindowStyleMaskNonactivatingPanel)
    panel = NSPanel.alloc().initWithContentRect_styleMask_backing_defer_(
        NSMakeRect(0, 0, 300, 140), style, NSBackingStoreBuffered, False)
    panel.setTitle_("Concert")
    panel.setFloatingPanel_(True)
    panel.setBecomesKeyOnlyIfNeeded_(True)
    panel.setHidesOnDeactivate_(False)
    panel.setLevel_(NSFloatingWindowLevel)
    panel.setReleasedWhenClosed_(False)

    btn = FirstClickButton.alloc().initWithFrame_(NSMakeRect(16, 18, 268, 96))
    btn.setTitle_("Morceau suivant ▶")
    btn.setBezelStyle_(NSBezelStyleRegularSquare)
    btn.setFont_(NSFont.boldSystemFontOfSize_(22))
    btn.setTarget_(ctl)
    btn.setAction_("nextMorceau:")
    panel.contentView().addSubview_(btn)

    scr = NSScreen.mainScreen().frame()
    panel.setFrameOrigin_((scr.size.width - 320, scr.size.height - 190))
    panel.orderFrontRegardless()

    # keep strong refs so they survive the run loop
    globals()["_keep"] = (panel, btn, ctl)
    app.run()


if __name__ == "__main__":
    main()

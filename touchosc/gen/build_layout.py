"""Entrypoint: build the full AV-Live TouchOSC layout and write to dist/."""
import os

from gen import layout, schema

OUT = os.path.join(os.path.dirname(__file__), "..", "dist", "av-live-control.tosc")


def main():
    out_path = os.path.normpath(OUT)
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    schema.write_tosc(layout.build(), out_path)
    print(f"wrote {out_path}")


if __name__ == "__main__":
    main()

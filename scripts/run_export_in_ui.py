# -*- coding: utf-8 -*-
"""
RenderDoc UI entrypoint: wait for capture load, then export Colour Pass #1 meshes.

Run from already-open capture (Python Shell):
  exec(open(r'F:\\13_MCP_AI\\RenderDocMCP\\scripts\\run_export_in_ui.py', encoding='utf-8').read())

Or:
  qrenderdoc.exe capture.rdc --ui-python run_export_in_ui.py
"""
from __future__ import print_function

import os
import sys
import time
import traceback

OUT_DIR = os.environ.get(
    "RD_EXPORT_OUT",
    r"F:\13_MCP_AI\RenderDocMCP\exports\handSSSS_meshes",
)
DONE_FILE = os.path.join(OUT_DIR, "_export_done.txt")
ERR_FILE = os.path.join(OUT_DIR, "_export_error.txt")

os.environ.setdefault("RD_EXPORT_MARKER", "Colour Pass #1 (")
os.environ.setdefault("RD_EXPORT_MIN_INDICES", "12")
os.environ.setdefault("RD_EXPORT_MAX_DRAWS", "0")
os.environ.setdefault("RD_EXPORT_INSTANCES", "first")

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
if SCRIPT_DIR not in sys.path:
    sys.path.insert(0, SCRIPT_DIR)


def _write(path, text):
    d = os.path.dirname(path)
    if not os.path.isdir(d):
        os.makedirs(d)
    with open(path, "w") as f:
        f.write(text)


def _wait_capture_loaded(timeout_sec=900):
    """ui-python often runs before the capture finishes opening."""
    try:
        from PySide2.QtWidgets import QApplication
    except Exception:
        QApplication = None

    t0 = time.time()
    while True:
        loaded = False
        try:
            loaded = bool(pyrenderdoc.IsCaptureLoaded())
        except Exception:
            loaded = False
        if loaded:
            # Give replay a moment to become ready
            time.sleep(1.0)
            if QApplication is not None:
                QApplication.processEvents()
            return
        if time.time() - t0 > timeout_sec:
            raise RuntimeError("Timed out waiting for IsCaptureLoaded()")
        if QApplication is not None:
            QApplication.processEvents()
        time.sleep(0.5)


def _do_export():
    import export_scene_meshes as exp

    exp.MARKER_FILTER = os.environ.get("RD_EXPORT_MARKER", "Colour Pass #1 (")
    exp.MIN_INDICES = int(os.environ.get("RD_EXPORT_MIN_INDICES", "12"))
    exp.MAX_DRAWS = int(os.environ.get("RD_EXPORT_MAX_DRAWS", "0"))
    exp.INSTANCE_MODE = os.environ.get("RD_EXPORT_INSTANCES", "first")
    exp.FLIP_YZ = os.environ.get("RD_EXPORT_FLIP_YZ", "1") == "1"

    result = {"manifest": None}

    def cb(controller):
        result["manifest"] = exp.export_scene(controller, OUT_DIR)

    print("[export] BlockInvoke export ->", OUT_DIR)
    pyrenderdoc.Replay().BlockInvoke(cb)
    return result["manifest"] or {}


def main():
    if "pyrenderdoc" not in globals() or pyrenderdoc is None:
        raise RuntimeError("This script must run inside RenderDoc UI (pyrenderdoc missing)")

    for p in (DONE_FILE, ERR_FILE):
        try:
            if os.path.exists(p):
                os.remove(p)
        except Exception:
            pass

    print("[export] waiting for capture load...")
    _wait_capture_loaded()
    print("[export] capture loaded:", pyrenderdoc.GetCaptureFilename())

    man = _do_export()
    _write(
        DONE_FILE,
        "count=%s\nelapsed=%s\nout=%s\n"
        % (man.get("count"), man.get("elapsed_sec"), OUT_DIR),
    )
    print("[export] done:", DONE_FILE)


try:
    main()
except Exception:
    tb = traceback.format_exc()
    print(tb)
    try:
        _write(ERR_FILE, tb)
    except Exception:
        pass
    raise

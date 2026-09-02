"""
File-based IPC Server for RenderDoc MCP Bridge
Uses file polling since RenderDoc's Python doesn't have socket/QtNetwork modules.
"""

import json
import os
import tempfile
import threading
import traceback


# RenderDoc normally initialises PySide2 before loading extensions. Some 1.46
# installations ship a PySide2/shiboken2 combination that instead raises a
# NameError while importing QtCore. Keep the UI-thread QTimer path when it is
# available, but do not make Qt a hard dependency of this headless bridge.
try:
    from PySide2.QtCore import QObject, QTimer

    _QT_IMPORT_ERROR = None
except Exception as exc:
    QObject = object
    QTimer = None
    _QT_IMPORT_ERROR = str(exc)


# IPC directory
IPC_DIR = os.path.join(tempfile.gettempdir(), "renderdoc_mcp")
REQUEST_FILE = os.path.join(IPC_DIR, "request.json")
RESPONSE_FILE = os.path.join(IPC_DIR, "response.json")
LOCK_FILE = os.path.join(IPC_DIR, "lock")
POLL_INTERVAL_SECONDS = 0.1


class MCPBridgeServer(QObject):
    """File-based IPC server for MCP bridge communication"""

    def __init__(self, host, port, handler, parent=None):
        if QTimer is not None:
            super(MCPBridgeServer, self).__init__(parent)
        else:
            super(MCPBridgeServer, self).__init__()
        self.handler = handler
        self._timer = None
        self._thread = None
        self._stop_event = threading.Event()
        self._running = False

        # Create IPC directory
        os.makedirs(IPC_DIR, exist_ok=True)

    def start(self):
        """Start the server with polling"""
        if self._running:
            return True

        self._running = True

        # Clean up old files
        self._cleanup_files()

        if QTimer is not None:
            # Prefer the Qt timer because its callback runs on RenderDoc's UI
            # thread, matching the behaviour of earlier plugin versions.
            self._timer = QTimer(self)
            self._timer.timeout.connect(self._poll_request)
            self._timer.start(int(POLL_INTERVAL_SECONDS * 1000))
        else:
            # The bridge itself has no UI. A daemon worker keeps it usable when
            # RenderDoc's optional PySide2 binding cannot be imported.
            self._stop_event.clear()
            self._thread = threading.Thread(
                target=self._poll_loop, name="RenderDocMCPBridge"
            )
            self._thread.daemon = True
            self._thread.start()
            print(
                "[MCP Bridge] PySide2 unavailable; using thread polling: %s"
                % _QT_IMPORT_ERROR
            )

        print("[MCP Bridge] File-based IPC server started")
        print("[MCP Bridge] IPC directory: %s" % IPC_DIR)
        return True

    def stop(self):
        """Stop the server"""
        self._running = False
        if self._timer:
            self._timer.stop()
            self._timer = None
        if self._thread:
            self._stop_event.set()
            if threading.current_thread() is not self._thread:
                self._thread.join(timeout=1.0)
            self._thread = None
        self._cleanup_files()
        print("[MCP Bridge] Server stopped")

    def is_running(self):
        """Check if server is running"""
        return self._running

    def _poll_loop(self):
        """Poll IPC files without requiring RenderDoc's optional Qt binding."""
        while not self._stop_event.is_set():
            self._poll_request()
            self._stop_event.wait(POLL_INTERVAL_SECONDS)

    def _cleanup_files(self):
        """Remove IPC files"""
        for f in [REQUEST_FILE, RESPONSE_FILE, LOCK_FILE]:
            try:
                if os.path.exists(f):
                    os.remove(f)
            except Exception:
                pass

    def _poll_request(self):
        """Check for incoming request"""
        if not self._running:
            return

        # Check if request file exists
        if not os.path.exists(REQUEST_FILE):
            return

        # Check if lock file exists (client is still writing)
        if os.path.exists(LOCK_FILE):
            return

        try:
            # Read request
            with open(REQUEST_FILE, "r", encoding="utf-8") as f:
                request = json.load(f)

            # Remove request file
            os.remove(REQUEST_FILE)

            # Process request
            try:
                response = self.handler.handle(request)
            except Exception as e:
                traceback.print_exc()
                response = {
                    "id": request.get("id"),
                    "error": {"code": -32603, "message": str(e)}
                }

            # Write response
            with open(RESPONSE_FILE, "w", encoding="utf-8") as f:
                json.dump(response, f)

        except Exception as e:
            print("[MCP Bridge] Error processing request: %s" % str(e))
            traceback.print_exc()

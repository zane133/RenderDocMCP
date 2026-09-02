import importlib.util
import json
import sys
import tempfile
import time
import types
import unittest
from pathlib import Path
from unittest import mock


SOCKET_SERVER_PATH = (
    Path(__file__).resolve().parents[1] / "renderdoc_extension" / "socket_server.py"
)


def load_socket_server():
    spec = importlib.util.spec_from_file_location(
        "renderdoc_mcp_socket_server_under_test", SOCKET_SERVER_PATH
    )
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class SocketServerCompatibilityTests(unittest.TestCase):
    def test_import_succeeds_when_pyside2_is_unavailable(self):
        with mock.patch.dict(sys.modules, {"PySide2": None, "PySide2.QtCore": None}):
            module = load_socket_server()

        self.assertIsNone(module.QTimer)

    def test_thread_fallback_processes_a_request(self):
        with mock.patch.dict(sys.modules, {"PySide2": None, "PySide2.QtCore": None}):
            module = load_socket_server()

        class Handler:
            def handle(self, request):
                return {"id": request["id"], "result": {"status": "ok"}}

        with tempfile.TemporaryDirectory() as temp_dir:
            ipc_dir = Path(temp_dir)
            module.IPC_DIR = str(ipc_dir)
            module.REQUEST_FILE = str(ipc_dir / "request.json")
            module.RESPONSE_FILE = str(ipc_dir / "response.json")
            module.LOCK_FILE = str(ipc_dir / "lock")

            server = module.MCPBridgeServer("127.0.0.1", 19876, Handler())
            try:
                self.assertTrue(server.start())
                Path(module.REQUEST_FILE).write_text(
                    json.dumps({"id": "request-1", "method": "ping", "params": {}}),
                    encoding="utf-8",
                )

                deadline = time.monotonic() + 2.0
                while not Path(module.RESPONSE_FILE).exists():
                    if time.monotonic() >= deadline:
                        self.fail("thread fallback did not produce a response")
                    time.sleep(0.01)

                response = json.loads(
                    Path(module.RESPONSE_FILE).read_text(encoding="utf-8")
                )
                self.assertEqual(
                    response, {"id": "request-1", "result": {"status": "ok"}}
                )
            finally:
                server.stop()

            self.assertFalse(server.is_running())

    def test_extension_package_registers_without_pyside2(self):
        fake_renderdoc = types.ModuleType("renderdoc")
        old_modules = {
            name: module
            for name, module in sys.modules.items()
            if name == "renderdoc_extension" or name.startswith("renderdoc_extension.")
        }
        for name in old_modules:
            del sys.modules[name]

        try:
            with mock.patch.dict(
                sys.modules,
                {
                    "renderdoc": fake_renderdoc,
                    "qrenderdoc": None,
                    "PySide2": None,
                    "PySide2.QtCore": None,
                },
            ):
                import renderdoc_extension

                with tempfile.TemporaryDirectory() as temp_dir:
                    ipc_dir = Path(temp_dir)
                    socket_server = renderdoc_extension.socket_server
                    socket_server.IPC_DIR = str(ipc_dir)
                    socket_server.REQUEST_FILE = str(ipc_dir / "request.json")
                    socket_server.RESPONSE_FILE = str(ipc_dir / "response.json")
                    socket_server.LOCK_FILE = str(ipc_dir / "lock")

                    renderdoc_extension.register("1.46", object())
                    self.assertTrue(renderdoc_extension._server.is_running())
                    renderdoc_extension.unregister()
                    self.assertIsNone(renderdoc_extension._server)
        finally:
            for name in list(sys.modules):
                if name == "renderdoc_extension" or name.startswith(
                    "renderdoc_extension."
                ):
                    del sys.modules[name]
            sys.modules.update(old_modules)


if __name__ == "__main__":
    unittest.main()

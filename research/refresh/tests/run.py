"""Run the refresh tests without pytest.

The box has no pip and no pytest, so this gives the same tests a runner: every
`test_*` function is called with a fresh temporary directory for its `tmp_path`
parameter. The files stay pytest-compatible for a machine that has it.

    python3 research/refresh/tests/run.py            # all cases
    python3 research/refresh/tests/run.py compare    # one file
"""
import importlib.util
import inspect
import pathlib
import shutil
import sys
import tempfile
import traceback

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
sys.path.insert(0, str(HERE.parent / "tools"))


def load(path):
    spec = importlib.util.spec_from_file_location(path.stem, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main(argv):
    wanted = argv[1] if len(argv) > 1 else ""
    files = sorted(HERE.glob("test_*.py"))
    if wanted:
        files = [f for f in files if wanted in f.name]
    passed, failed = 0, []
    for path in files:
        module = load(path)
        for name, fn in inspect.getmembers(module, inspect.isfunction):
            if not name.startswith("test_"):
                continue
            if inspect.signature(fn).parameters:
                tmp = pathlib.Path(tempfile.mkdtemp(prefix="refresh-"))
                try:
                    fn(tmp)
                    passed += 1
                    print("pass  %s::%s" % (path.stem, name))
                except Exception as exc:
                    failed.append((path.stem, name, exc, traceback.format_exc()))
                    print("FAIL  %s::%s\n      %s" % (path.stem, name, exc))
                finally:
                    shutil.rmtree(tmp, ignore_errors=True)
            else:
                try:
                    fn()
                    passed += 1
                    print("pass  %s::%s" % (path.stem, name))
                except Exception as exc:
                    failed.append((path.stem, name, exc, traceback.format_exc()))
                    print("FAIL  %s::%s\n      %s" % (path.stem, name, exc))
    print("\n%d passed, %d failed" % (passed, len(failed)))
    if failed:
        print("\n--- first failure detail ---")
        print(failed[0][3])
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))

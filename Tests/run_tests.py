"""Run each Wolfram suite in its own kernel, strictly sequentially."""
from pathlib import Path
import json
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
LOGS = Path(tempfile.mkdtemp(prefix="csockets-tests-"))
files = sorted((ROOT / "Tests").glob("*.wlt")) + sorted(
    p for p in (ROOT / "Tests").glob("*.wls") if p.name != "RunTest.wls"
)
if len(sys.argv) > 1:
    files = [ROOT / "Tests" / name for name in sys.argv[1:]]
results = []
print(f"Logs: {LOGS}", flush=True)
for file in files:
    command = ["wolframscript", "-f"]
    command += [str(ROOT / "Tests" / "RunTest.wls"), str(file)] if file.suffix == ".wlt" else [str(file)]
    for attempt in range(1, 3):
        print(f"RUN {file.name} (attempt {attempt})", flush=True)
        result = subprocess.run(command, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        log = LOGS / f"{file.name}.{attempt}.log"
        log.write_bytes(result.stdout)
        output = result.stdout.decode("utf-8", errors="replace")
        if result.returncode == 0:
            break
        print(f"RETRY/FAIL {file.name}: exit {result.returncode}; {log}", flush=True)
    results.append({"file": file.name, "exit": result.returncode, "log": str(log)})
    summaries = [line for line in output.splitlines() if line.startswith("RESULT:") or line.startswith("Passed:")]
    print(f"{'PASS' if result.returncode == 0 else 'FAIL'} {file.name}: {' | '.join(summaries[-2:])}", flush=True)
(LOGS / "results.json").write_text(json.dumps(results, indent=4))
failed = [item for item in results if item["exit"] != 0]
print(f"TOTAL: {len(results) - len(failed)} passed; {len(failed)} failed; logs: {LOGS}", flush=True)
sys.exit(bool(failed))

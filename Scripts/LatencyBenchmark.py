"""Measure full echo RTT against CSocketHandle + CSocketHandler on loopback.

One Wolfram kernel serves TCP and UDP; this Python process is the client.
Connection setup, payload construction, warmup, and response validation are
outside the timed interval. There is one outstanding request at a time.
"""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
import math
import os
from pathlib import Path
import platform
import random
import signal
import socket
import statistics
import subprocess
import tempfile
import time
from urllib.parse import urlsplit


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SIZES = (1, 64, 1024, 8192, 65500)


class BenchmarkError(RuntimeError):
    pass


def endpoint(address: str) -> tuple[str, int]:
    parsed = urlsplit(address)
    if parsed.hostname != "127.0.0.1" or parsed.port is None:
        raise BenchmarkError(f"Expected a loopback endpoint, got {address!r}")
    return parsed.hostname, parsed.port


def percentile(ordered: list[int], probability: float) -> float:
    position = (len(ordered) - 1) * probability
    lower = math.floor(position)
    upper = math.ceil(position)
    return ordered[lower] + (ordered[upper] - ordered[lower]) * (position - lower)


def summarize(samples: list[int]) -> dict[str, float | int]:
    ordered = sorted(samples)
    return {
        "samples": len(samples),
        "min_ms": ordered[0] / 1e6,
        "median_ms": statistics.median(ordered) / 1e6,
        "mean_ms": statistics.fmean(ordered) / 1e6,
        "p95_ms": percentile(ordered, 0.95) / 1e6,
        "p99_ms": percentile(ordered, 0.99) / 1e6,
        "max_ms": ordered[-1] / 1e6,
    }


def cpu_name() -> str:
    if os.name == "nt":
        import winreg

        with winreg.OpenKey(
            winreg.HKEY_LOCAL_MACHINE,
            r"HARDWARE\DESCRIPTION\System\CentralProcessor\0",
        ) as key:
            return winreg.QueryValueEx(key, "ProcessorNameString")[0].strip()
    return platform.processor()


def exchange(sock: socket.socket, protocol: str, payload: bytes,
             buffer: bytearray, view: memoryview) -> int:
    start = time.perf_counter_ns()
    if protocol == "TCP":
        sock.sendall(payload)
        received = 0
        while received < len(payload):
            count = sock.recv_into(view[received:len(payload)])
            if count == 0:
                raise BenchmarkError("TCP server closed before the full echo arrived")
            received += count
    else:
        sent = sock.send(payload)
        if sent != len(payload):
            raise BenchmarkError(f"Short UDP send: {sent} bytes")
        received = sock.recv_into(buffer)
    elapsed = time.perf_counter_ns() - start

    # Validation is deliberately outside the measured interval.
    if received != len(payload) or view[:received] != payload:
        raise BenchmarkError(f"Incorrect {protocol} echo for {len(payload)} bytes")
    return elapsed


def stop_server(process: subprocess.Popen, ready: dict, token: str) -> None:
    if process.poll() is not None:
        return
    if ready:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as control:
            control.sendto(token.encode("ascii"), endpoint(ready["Control"]))
    try:
        process.wait(timeout=10)
    except subprocess.TimeoutExpired:
        if os.name == "nt":
            subprocess.run(
                ["taskkill", "/PID", str(process.pid), "/T", "/F"],
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False,
            )
        else:
            os.killpg(process.pid, signal.SIGTERM)
        process.wait(timeout=10)
        raise BenchmarkError("Server did not exit after the shutdown request")


def run_once(args: argparse.Namespace, directory: Path) -> tuple[dict, str, int]:
    ready_file = directory / "ready.json"
    config_file = directory / "config.json"
    log_file = directory / "server.log"
    token = os.urandom(24).hex()
    config_file.write_text(json.dumps({
        "ReadyFile": str(ready_file), "StopToken": token,
    }), encoding="utf-8")
    ready = {}
    results = []
    with log_file.open("wb") as log:
        options = {"creationflags": subprocess.CREATE_NO_WINDOW} if os.name == "nt" else {"start_new_session": True}
        environment = os.environ.copy()
        environment["CSOCKETS_LATENCY_CONFIG"] = str(config_file)
        server_file = str(ROOT / "Scripts" / "LatencyBenchmarkServer.wls")
        command = [str(args.kernel), "-noinit", "-script", server_file] if args.kernel else ["wolframscript", "-f", server_file, str(config_file)]
        process = subprocess.Popen(
            command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, env=environment, **options,
        )
        try:
            deadline = time.monotonic() + args.startup_timeout
            while not ready_file.exists():
                if process.poll() is not None:
                    raise BenchmarkError(f"Server exited before becoming ready (exit {process.returncode})")
                if time.monotonic() >= deadline:
                    raise BenchmarkError("Server startup timed out")
                time.sleep(0.05)
            ready = json.loads(ready_file.read_text(encoding="utf-8"))
            print(f"READY: {ready['WolframVersion']}", flush=True)

            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as tcp, socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as udp:
                tcp.settimeout(args.timeout)
                udp.settimeout(args.timeout)
                tcp.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
                tcp.connect(endpoint(ready["TCP"]))
                udp.connect(endpoint(ready["UDP"]))
                connections = {"TCP": tcp, "UDP": udp}
                payloads = {size: bytes(index % 251 for index in range(size)) for size in args.sizes}
                buffers = {size: bytearray(size + 1) for size in args.sizes}
                views = {size: memoryview(buffer) for size, buffer in buffers.items()}
                cases = [(protocol, size) for protocol in ("TCP", "UDP") for size in args.sizes]
                schedule = random.Random(args.seed)
                for round_number in range(1, args.rounds + 1):
                    order = cases.copy()
                    schedule.shuffle(order)
                    for protocol, size in order:
                        sock = connections[protocol]
                        payload, buffer, view = payloads[size], buffers[size], views[size]
                        print(f"ROUND {round_number}/{args.rounds}: {protocol} {size} B", flush=True)
                        for _ in range(args.warmup):
                            exchange(sock, protocol, payload, buffer, view)
                        samples = [exchange(sock, protocol, payload, buffer, view) for _ in range(args.samples)]
                        summary = summarize(samples)
                        results.append({
                            "protocol": protocol, "payload_bytes": size,
                            "round": round_number, "summary": summary, "rtt_ns": samples,
                        })
                        # Keep fully validated batches even if the kernel later crashes.
                        # Writing is outside the timed interval and before the next warmup.
                        args.checkpoint.write_text(json.dumps({
                            "status": "incomplete run; completed batches only",
                            "server": ready, "rounds_requested": args.rounds,
                            "samples_per_round": args.samples, "warmup_per_batch": args.warmup,
                            "sizes_bytes": args.sizes, "seed": args.seed, "rounds": results,
                        }, indent=2), encoding="utf-8")
                        print(f"  median={summary['median_ms']:.3f} ms; p99={summary['p99_ms']:.3f} ms", flush=True)
        except (BenchmarkError, OSError) as error:
            raise BenchmarkError(f"{error}; server exit at failure: {process.poll()}") from error
        finally:
            stop_server(process, ready, token)
    log_text = log_file.read_text(encoding="utf-8", errors="replace")
    if process.returncode != 0 or "BENCHMARK_STOPPED" not in log_text:
        raise BenchmarkError(f"Server did not finish cleanly (exit {process.returncode}): {log_text}")
    return {"server": ready, "rounds": results}, log_text, process.returncode


def markdown_table(rows: list[dict]) -> str:
    lines = [
        "| Protocol | Request/response bytes | Samples | Min ms | Median ms | Mean ms | p95 ms | p99 ms | Max ms |",
        "| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |",
    ]
    for row in rows:
        lines.append(
            f"| {row['protocol']} | {row['payload_bytes']} | {row['samples']} | "
            + " | ".join(f"{row[key]:.3f}" for key in ("min_ms", "median_ms", "mean_ms", "p95_ms", "p99_ms", "max_ms"))
            + " |"
        )
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--samples", type=int, default=1000, help="Measured RTTs per case per round")
    parser.add_argument("--rounds", type=int, default=3)
    parser.add_argument("--warmup", type=int, default=100, help="Untimed exchanges before each measured batch")
    parser.add_argument("--sizes", type=int, nargs="+", default=list(DEFAULT_SIZES))
    parser.add_argument("--seed", type=int, default=20261126)
    parser.add_argument("--timeout", type=float, default=5)
    parser.add_argument("--startup-timeout", type=float, default=60)
    parser.add_argument("--kernel", type=Path, help="Run this wolfram executable directly with -noinit instead of wolframscript")
    parser.add_argument("--output", type=Path, default=ROOT / "benchmarks" / "SynchronousLatency.json")
    args = parser.parse_args()
    if args.samples < 1 or args.rounds < 1 or args.warmup < 0 or args.timeout <= 0 or args.startup_timeout <= 0:
        parser.error("Samples, rounds, and timeouts must be positive; warmup must be nonnegative")
    if not args.sizes or any(size < 1 or size > 65507 for size in args.sizes) or len(set(args.sizes)) != len(args.sizes):
        parser.error("Sizes must be distinct integers between 1 and 65507 (IPv4 UDP payload limit)")
    if args.kernel and not args.kernel.is_file():
        parser.error("The specified kernel executable does not exist")

    started = datetime.now(timezone.utc).isoformat()
    startup_failures = []
    args.output.parent.mkdir(parents=True, exist_ok=True)
    for attempt in (1, 2):
        args.checkpoint = args.output.with_name(f"{args.output.stem}.attempt{attempt}.partial.json")
        with tempfile.TemporaryDirectory(prefix="csockets-latency-") as temporary:
            directory = Path(temporary)
            print(f"SERVER ATTEMPT {attempt}", flush=True)
            try:
                measurements, log, exit_code = run_once(args, directory)
                break
            except (BenchmarkError, OSError) as error:
                log_file = directory / "server.log"
                log_text = log_file.read_text(encoding="utf-8", errors="replace") if log_file.exists() else ""
                print(f"ATTEMPT FAILED: {error}\n{log_text}", flush=True)
                startup_failures.append({"attempt": attempt, "error": str(error), "server_log": log_text})
                if args.checkpoint.exists():
                    print(f"Completed batches preserved: {args.checkpoint}", flush=True)
                if attempt == 2:
                    return 1
    summary = []
    for protocol in ("TCP", "UDP"):
        for size in args.sizes:
            matching = [row for row in measurements["rounds"] if row["protocol"] == protocol and row["payload_bytes"] == size]
            samples = [sample for row in matching for sample in row["rtt_ns"]]
            summary.append({
                "protocol": protocol, "payload_bytes": size, **summarize(samples),
                "round_medians_ms": [row["summary"]["median_ms"] for row in matching],
            })
    report = {
        "started_utc": started, "finished_utc": datetime.now(timezone.utc).isoformat(),
        "environment": {
            "os": platform.platform(), "cpu": cpu_name(), "logical_processors": os.cpu_count(),
            "python": platform.python_version(), "timer_resolution_seconds": time.get_clock_info("perf_counter").resolution,
            "kernel_sha256": hashlib.sha256((ROOT / "Kernel" / "CSockets.wl").read_bytes()).hexdigest(),
        },
        "method": {
            "host": "127.0.0.1", "server": "CSocketHandle with CSocketHandler byte echo",
            "launcher": str(args.kernel) if args.kernel else "wolframscript",
            "user_initialization": "disabled (-noinit)" if args.kernel else "default",
            "outstanding_requests": 1, "tcp_connection": "persistent, TCP_NODELAY on both ends",
            "tcp_framing": "Each read is echoed; the client waits for exactly the full request length",
            "rounds": args.rounds, "samples_per_round": args.samples, "warmup_per_batch": args.warmup,
            "sizes_bytes": args.sizes, "order": "shuffled each round", "seed": args.seed,
            "timed_interval": "Immediately before send to immediately after receiving the complete echo",
            "excluded": ["server startup", "connection setup", "warmup", "payload creation", "response validation"],
            "percentiles": "Linear interpolation on sorted pooled samples (R7)",
        },
        "failed_attempts": startup_failures, "server_exit_code": exit_code,
        "server_log": log, "summary": summary, **measurements,
    }
    args.output.write_text(json.dumps(report, indent=2), encoding="utf-8")
    args.checkpoint.unlink()
    print("\n" + markdown_table(summary), flush=True)
    print(f"\nSaved raw samples and metadata: {args.output}", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

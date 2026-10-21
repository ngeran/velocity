from __future__ import annotations

from contextlib import suppress
from dataclasses import dataclass, field
import os
import re
import shutil
import time

from xray.system.commands import CommandRunner
from xray.system.procfs import ProcFs
from xray.system.descriptors import (
    DescriptorInventory,
    collect_descriptors,
    read_stable_fdinfo,
)


_ENGINE = re.compile(r"^drm-engine-([^:]+):\s*(\d+)\s*ns$", re.MULTILINE)
_CAPACITY = re.compile(r"^drm-engine-capacity-([^:]+):\s*(\d+)$", re.MULTILINE)
_MEMORY = re.compile(
    r"^drm-(memory|resident|total)-([^:]+):\s*(\d+)\s*([KMGT]?i?B)?$",
    re.MULTILINE | re.IGNORECASE,
)


def _bytes(value: str, unit: str) -> int:
    factors = {
        "": 1,
        "b": 1,
        "kb": 1000,
        "kib": 1024,
        "mb": 1_000_000,
        "mib": 1_048_576,
        "gb": 1_000_000_000,
        "gib": 1_073_741_824,
        "tb": 1_000_000_000_000,
        "tib": 1_099_511_627_776,
    }
    return int(value) * factors.get(unit.lower(), 1)


def parse_drm_fdinfo(text: str) -> dict[str, object] | None:
    match = re.search(r"^drm-client-id:\s*(\S+)$", text, re.MULTILINE)
    if not match:
        return None
    engines = {name: int(value) for name, value in _ENGINE.findall(text)}
    capacity = {name: max(1, int(value)) for name, value in _CAPACITY.findall(text)}
    memory_groups: dict[str, dict[str, int]] = {
        "memory": {},
        "resident": {},
        "total": {},
    }
    for category, name, value, unit in _MEMORY.findall(text):
        memory_groups[category.lower()][name] = _bytes(value, unit or "")
    memory = (
        memory_groups["resident"] or memory_groups["total"] or memory_groups["memory"]
    )
    return {
        "clientId": match.group(1),
        "engines": engines,
        "capacity": capacity,
        "memory": memory,
        "memoryKind": (
            "resident"
            if memory_groups["resident"]
            else "total"
            if memory_groups["total"]
            else "legacy"
        ),
    }


def collect_gpu_clients(
    proc: ProcFs,
    pids: list[int],
    inventory: DescriptorInventory | None = None,
) -> tuple[list[dict[str, object]], list[str]]:
    rows: list[dict[str, object]] = []
    limited: list[str] = []
    seen: set[tuple[int, str, str]] = set()
    descriptors = inventory or collect_descriptors(proc, pids)
    limited.extend(descriptors.limited)
    for record in descriptors.records:
        if not record.target.startswith("/dev/dri/"):
            continue
        info = read_stable_fdinfo(proc, record, limit=131_072)
        if not info.available:
            limited.append(
                f"GPU fdinfo for process {record.pid} is unavailable: {info.error}"
            )
            continue
        parsed = parse_drm_fdinfo(info.value)
        if not parsed:
            limited.append(
                f"GPU fdinfo for process {record.pid} has no DRM client identity"
            )
            continue
        key = (record.pid, record.target, str(parsed["clientId"]))
        if key in seen:
            continue
        seen.add(key)
        rows.append({"pid": record.pid, "device": record.target, **parsed})
    return rows, list(dict.fromkeys(limited))


@dataclass
class GpuSampler:
    previous_at: float = 0.0
    previous_engines: dict[str, dict[str, int]] = field(default_factory=dict)

    def sample(
        self, clients: list[dict[str, object]], now: float | None = None
    ) -> float | None:
        sampled_at = now if now is not None else time.monotonic()
        elapsed_ns = (
            max(1.0, (sampled_at - self.previous_at) * 1_000_000_000)
            if self.previous_at
            else 0.0
        )
        current: dict[str, dict[str, int]] = {}
        total_delta = 0
        missing_baseline = False
        device_capacity: dict[tuple[str, str], int] = {}
        for client in clients:
            key = f"{client['pid']}:{client['device']}:{client['clientId']}"
            engines = {
                str(name): int(value)
                for name, value in dict(client.get("engines", {})).items()
            }
            current[key] = engines
            previous = self.previous_engines.get(key)
            if self.previous_at and previous is None:
                missing_baseline = True
            capacities = {
                str(name): max(1, int(value))
                for name, value in dict(client.get("capacity", {})).items()
            }
            deltas = (
                {
                    name: max(0, value - previous.get(name, value))
                    for name, value in engines.items()
                }
                if previous is not None
                else {}
            )
            utilization: float | None = None
            if elapsed_ns > 0 and previous is not None:
                denominator = elapsed_ns * sum(
                    capacities.get(name, 1) for name in engines
                )
                if denominator:
                    utilization = min(100.0, sum(deltas.values()) / denominator * 100)
            client["utilizationPercent"] = (
                round(utilization, 1) if utilization is not None else None
            )
            # NVIDIA fallback rows carry no memory group when the driver
            # reports nothing for the client — omit rather than show 0 B.
            if client.get("memory"):
                client["memoryBytes"] = sum(
                    int(value) for value in dict(client["memory"]).values()
                )
            total_delta += sum(deltas.values())
            for name in engines:
                capacity_key = (str(client["device"]), name)
                device_capacity[capacity_key] = max(
                    device_capacity.get(capacity_key, 0), capacities.get(name, 1)
                )
        self.previous_at = sampled_at
        self.previous_engines = current
        if elapsed_ns <= 0 or not device_capacity or missing_baseline:
            return None
        denominator = elapsed_ns * sum(device_capacity.values())
        return round(min(100.0, total_delta / denominator * 100), 1)


_NVIDIA_DEVICE = re.compile(r"^/dev/nvidia\d+$")
_NVIDIA_SMI_FALLBACKS = (
    "/run/current-system/sw/bin/nvidia-smi",  # NixOS
    "/usr/bin/nvidia-smi",
)


def _resolve_nvidia_smi() -> str | None:
    found = shutil.which("nvidia-smi")
    if found:
        return found
    for candidate in _NVIDIA_SMI_FALLBACKS:
        if os.path.isfile(candidate) and os.access(candidate, os.X_OK):
            return candidate
    return None


def nvidia_client_pids(descriptors: DescriptorInventory) -> dict[int, str]:
    """Pids holding an NVIDIA device node open, mapped to that node.

    The proprietary driver publishes no DRM fdinfo, but every real client
    keeps /dev/nvidia<N> open alongside nvidiactl/uvm — so device fds are
    the client evidence.
    """
    clients: dict[int, str] = {}
    for record in descriptors.records:
        if _NVIDIA_DEVICE.match(record.target):
            clients.setdefault(record.pid, record.target)
    return clients


def _nvidia_process_memory(
    runner: CommandRunner, executable: str
) -> dict[int, int]:
    result = runner.run(
        [
            executable,
            "--query-compute-apps=pid,used_memory",
            "--format=csv,noheader,nounits",
        ]
    )
    memory: dict[int, int] = {}
    for line in result.stdout.splitlines():
        fields = [field.strip() for field in line.split(",")]
        if len(fields) != 2 or not fields[0].isdigit():
            continue
        with suppress(ValueError):
            memory[int(fields[0])] = int(float(fields[1]) * 1024 * 1024)
    return memory


def collect_nvidia_clients(
    runner: CommandRunner, descriptors: DescriptorInventory
) -> tuple[list[dict[str, object]], list[str]]:
    """Fallback client rows for drivers without DRM fdinfo (NVIDIA).

    Rows carry the same shape as fdinfo clients so the dashboard renders
    them unchanged; per-process VRAM arrives from nvidia-smi where it is
    reported (compute clients) and stays absent otherwise. Engine-level
    attribution simply does not exist on this driver.
    """
    clients = nvidia_client_pids(descriptors)
    limited = [
        "GPU engine utilization and per-client memory are not attributed "
        "per process on this driver"
    ]
    rows: list[dict[str, object]] = [
        {
            "pid": pid,
            "device": device,
            "clientId": str(pid),
            "engines": {},
            "capacity": {},
            "memory": {},
            "memoryKind": "unknown",
        }
        for pid, device in sorted(clients.items())
    ]
    executable = _resolve_nvidia_smi()
    if executable is None:
        limited.append("nvidia-smi was not found for NVIDIA GPU metrics")
        return rows, limited
    memory_by_pid = _nvidia_process_memory(runner, executable)
    for row in rows:
        memory = memory_by_pid.get(int(str(row["pid"])))
        if memory is not None:
            row["memory"] = {"vram": memory}
            row["memoryKind"] = "resident"
    return rows, limited


def collect_gpu_clients_with_fallback(
    proc: ProcFs,
    runner: CommandRunner,
    pids: list[int],
    inventory: DescriptorInventory | None = None,
) -> tuple[list[dict[str, object]], list[str]]:
    """fdinfo clients first (amdgpu/i915/xe); on drivers that publish no
    fdinfo, identify NVIDIA clients by device fds instead. The permission
    notes from the fdinfo pass are dropped when the fallback fires — they
    describe the scan that found nothing, not the NVIDIA result.
    """
    descriptors = inventory or collect_descriptors(proc, pids)
    rows, limited = collect_gpu_clients(proc, pids, descriptors)
    if rows or not nvidia_client_pids(descriptors):
        return rows, limited
    return collect_nvidia_clients(runner, descriptors)

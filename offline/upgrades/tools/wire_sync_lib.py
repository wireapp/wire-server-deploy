#!/usr/bin/env python3
import datetime as dt
import hashlib
import json
import socket
import subprocess
import tarfile
from pathlib import Path

def now_ts():
    return dt.datetime.utcnow().replace(microsecond=0).isoformat() + "Z"

def host_name():
    return socket.gethostname()

def ensure_dir(path: Path):
    path.mkdir(parents=True, exist_ok=True)

def run_cmd(cmd, env=None, verbose=False):
    start = dt.datetime.utcnow()
    if verbose:
        proc = subprocess.Popen(
            cmd,
            env=env,
        )
        rc = proc.wait()
        return rc, "", "", 0
    proc = subprocess.Popen(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        env=env,
    )
    out, err = proc.communicate()
    end = dt.datetime.utcnow()
    return proc.returncode, out, err, int((end - start).total_seconds() * 1000)

def write_audit(log_dir: Path, base_name: str, audit: dict, summary_lines: list, ts_override: str = None):
    ensure_dir(log_dir)
    ts = ts_override or dt.datetime.utcnow().strftime("%Y%m%dT%H%M%SZ")
    json_path = log_dir / f"{ts}_{base_name}.json"
    txt_path = log_dir / f"{ts}_{base_name}.txt"
    json_path.write_text(json.dumps(audit, indent=2, sort_keys=False))
    txt_path.write_text("\n".join(summary_lines) + "\n")
    return str(json_path), str(txt_path)

def sha256_stream(fh, chunk_size=1024 * 1024):
    h = hashlib.sha256()
    while True:
        chunk = fh.read(chunk_size)
        if not chunk:
            break
        h.update(chunk)
    return h.hexdigest()

def tar_manifest(tar_path: Path, errors: list, warnings: list):
    manifest = []
    if not tar_path.exists():
        errors.append(f"Missing tar file: {tar_path}")
        return manifest
    try:
        with tarfile.open(tar_path, mode="r:*") as tf:
            for member in tf.getmembers():
                if not member.isreg():
                    continue
                try:
                    fh = tf.extractfile(member)
                    if fh is None:
                        warnings.append(f"Could not read entry: {member.name} in {tar_path.name}")
                        continue
                    digest = sha256_stream(fh)
                    manifest.append({
                        "path": member.name,
                        "size": member.size,
                        "sha256": digest,
                    })
                except Exception as exc:
                    warnings.append(f"Failed to hash {member.name} in {tar_path.name}: {exc}")
    except Exception as exc:
        errors.append(f"Failed to read tar {tar_path}: {exc}")
    return manifest

def detect_duplicates(manifest):
    by_hash = {}
    for entry in manifest:
        by_hash.setdefault(entry["sha256"], []).append(entry["path"])
    duplicates = []
    for digest, paths in by_hash.items():
        if len(paths) > 1:
            duplicates.append({"sha256": digest, "paths": paths})
    return duplicates

def parse_hosts_ini(path: Path):
    section = None
    all_hosts = []
    all_vars = []
    groups = {}
    if not path.exists():
        raise FileNotFoundError(path)

    for raw in path.read_text().splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or line.startswith(";"):
            continue
        if line.startswith("[") and line.endswith("]"):
            section = line[1:-1]
            continue
        if section == "all":
            parts = line.split()
            host = parts[0]
            vars_map = {}
            for token in parts[1:]:
                if "=" in token:
                    k, v = token.split("=", 1)
                    vars_map[k] = v
            all_hosts.append({"host": host, "vars": vars_map})
        elif section == "all:vars":
            all_vars.append(raw)
        else:
            groups.setdefault(section, []).append(raw)
    return all_hosts, all_vars, groups

def extract_section_order(template_path: Path):
    order = []
    header_lines = []
    in_header = True
    for raw in template_path.read_text().splitlines():
        line = raw.strip()
        if line.startswith("[") and line.endswith("]"):
            in_header = False
            order.append(line[1:-1])
        elif in_header:
            header_lines.append(raw)
    return order, header_lines

def generate_hosts_ini(template_path: Path, source_hosts_path: Path, output_path: Path, errors: list, warnings: list):
    if not template_path.exists():
        errors.append(f"Missing template: {template_path}")
        return False
    try:
        all_hosts, all_vars, groups = parse_hosts_ini(source_hosts_path)
    except FileNotFoundError:
        errors.append(f"Missing source hosts.ini: {source_hosts_path}")
        return False

    order, header = extract_section_order(template_path)

    lines = []
    lines.append("# Generated from 99-static")
    lines.append(f"# Template: {template_path}")
    lines.append(f"# Source: {source_hosts_path}")
    lines.append("")
    lines.extend(header)

    def emit_section(name, body_lines):
        lines.append(f"[{name}]")
        if body_lines:
            lines.extend(body_lines)
        lines.append("")

    all_lines = []
    for entry in all_hosts:
        host = entry["host"]
        vars_map = dict(entry["vars"])
        ansible_host = vars_map.get("ansible_host")
        if not ansible_host:
            warnings.append(f"Host {host} has no ansible_host in source inventory")
            continue
        if "ip" not in vars_map:
            vars_map["ip"] = ansible_host
        ordered = []
        ordered.append("ansible_host=" + vars_map.pop("ansible_host"))
        ordered.append("ip=" + vars_map.pop("ip"))
        for k in sorted(vars_map.keys()):
            ordered.append(f"{k}={vars_map[k]}")
        all_lines.append(" ".join([host] + ordered))

    for section in order:
        if section == "all":
            emit_section(section, all_lines)
        elif section == "all:vars":
            emit_section(section, all_vars)
        else:
            emit_section(section, groups.get(section, []))

    output_path.write_text("\n".join(lines).rstrip() + "\n")
    return True

def print_errors_warnings(errors, warnings):
    if errors:
        print("Errors:")
        for e in errors:
            print(f"  - {e}")
    if warnings:
        print("Warnings:")
        for w in warnings:
            print(f"  - {w}")

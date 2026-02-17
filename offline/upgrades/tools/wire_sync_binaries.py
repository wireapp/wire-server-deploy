#!/usr/bin/env python3
import argparse
import os
from pathlib import Path
import sys
import datetime as dt

from wire_sync_lib import (
    now_ts,
    host_name,
    run_cmd,
    tar_manifest,
    detect_duplicates,
    write_audit,
    print_errors_warnings,
    generate_hosts_ini,
)

def parse_args():
    p = argparse.ArgumentParser(
        description="Sync offline binaries and assets to assethost with audit trail.",
    )
    p.add_argument("--bundle", default=os.environ.get("WIRE_SYNC_BUNDLE", "/home/demo/new"))
    p.add_argument("--inventory", default=os.environ.get("WIRE_SYNC_INVENTORY", "/home/demo/new/ansible/inventory/offline/hosts.ini"))
    p.add_argument("--playbook", default=os.environ.get("WIRE_SYNC_PLAYBOOK", "/home/demo/new/ansible/setup-offline-sources.yml"))
    p.add_argument("--log-dir", default=os.environ.get("WIRE_SYNC_LOG_DIR", "/var/log/audit_log"))
    p.add_argument("--dry-run", action="store_true")
    p.add_argument("--tags", default="")
    p.add_argument("--extra-vars", default="src_path=/home/demo/new")
    p.add_argument("--assethost", default=os.environ.get("WIRE_SYNC_ASSETHOST", "assethost"))
    p.add_argument("--ssh-user", default=os.environ.get("WIRE_SYNC_SSH_USER", "demo"))
    p.add_argument("--generate-hosts", action="store_true")
    p.add_argument("--template", default=os.environ.get("WIRE_SYNC_TEMPLATE", "/home/demo/new/ansible/inventory/offline/99-static"))
    p.add_argument("--source-hosts", default=os.environ.get("WIRE_SYNC_SOURCE_HOSTS", "/home/demo/wire-server-deploy/ansible/inventory/offline/hosts.ini"))
    p.add_argument("--output-hosts", default=os.environ.get("WIRE_SYNC_INVENTORY", "/home/demo/new/ansible/inventory/offline/hosts.ini"))
    p.add_argument("--pause-after-generate", action="store_true")
    p.add_argument("--fail-on-duplicates", action="store_true")
    p.add_argument("--ansible-cmd", default="ansible-playbook")
    p.add_argument("--use-d", action="store_true")
    p.add_argument("--offline-env", default=os.environ.get("WIRE_SYNC_OFFLINE_ENV", "/home/demo/new/bin/offline-env.sh"))
    p.add_argument("--kubeconfig", default=os.environ.get("WIRE_SYNC_KUBECONFIG", "/home/demo/new/ansible/inventory/kubeconfig.dec"))
    p.add_argument("--host-root", default=os.environ.get("WIRE_SYNC_BUNDLE", "/home/demo/new"))
    p.add_argument("--container-root", default=os.environ.get("WIRE_SYNC_CONTAINER_ROOT", "/wire-server-deploy"))
    p.add_argument("--verbose", action="store_true", help="Show ansible playbook output in real-time")
    return p.parse_args()

def ssh_check(user, host):
    cmd = [
        "ssh",
        "-o", "BatchMode=yes",
        "-o", "StrictHostKeyChecking=no",
        f"{user}@{host}",
        "true",
    ]
    rc, out, err, _ = run_cmd(cmd)
    return rc == 0, out, err

def to_container_path(path_str, host_root, container_root):
    if path_str.startswith(host_root):
        return container_root + path_str[len(host_root):]
    return path_str

def check_k8s_access(args):
    kubeconfig = args.kubeconfig
    if args.use_d:
        kubeconfig_c = to_container_path(kubeconfig, args.host_root, args.container_root)
        cmd = f"source {args.offline_env} && d kubectl --kubeconfig {kubeconfig_c} cluster-info"
        return run_cmd(["bash", "-lc", cmd])
    return run_cmd(["kubectl", "--kubeconfig", kubeconfig, "cluster-info"])

def build_ansible_cmd(args, inventory, playbook):
    if args.use_d:
        inventory_c = to_container_path(str(inventory), args.host_root, args.container_root)
        playbook_c = to_container_path(str(playbook), args.host_root, args.container_root)
        offline_env_c = args.offline_env
        extra_vars = args.extra_vars
        if extra_vars.startswith("src_path="):
            src_path = extra_vars.split("=", 1)[1]
            src_path_c = to_container_path(src_path, args.host_root, args.container_root)
            extra_vars = f"src_path={src_path_c}"

        cmd = f"source {offline_env_c} && d ansible-playbook -i {inventory_c} {playbook_c}"
        if extra_vars:
            cmd += f" -e {extra_vars}"
        if args.tags:
            cmd += f" --tags {args.tags}"
        return ["bash", "-lc", cmd]

    base_cmd = [args.ansible_cmd, "-i", str(inventory), str(playbook)]
    if args.extra_vars:
        base_cmd.extend(["-e", args.extra_vars])
    if args.tags:
        base_cmd.extend(["--tags", args.tags])
    return base_cmd

def main():
    args = parse_args()
    errors = []
    warnings = []

    if args.generate_hosts:
        ok = generate_hosts_ini(
            Path(args.template),
            Path(args.source_hosts),
            Path(args.output_hosts),
            errors,
            warnings,
        )
        if ok:
            print(f"Generated hosts.ini at: {args.output_hosts}")
            if args.pause_after_generate:
                input("Review the file, then press Enter to continue...")

    bundle = Path(args.bundle)
    inventory = Path(args.inventory)
    playbook = Path(args.playbook)
    log_dir = Path(args.log_dir)

    tar_files = [
        bundle / "binaries.tar",
        bundle / "debs-jammy.tar",
        bundle / "containers-system.tar",
        bundle / "containers-helm.tar",
    ]

    manifests = {}
    duplicates = {}
    for tar_path in tar_files:
        manifest = tar_manifest(tar_path, errors, warnings)
        manifests[tar_path.name] = {
            "entries": len(manifest),
        }
        dup = detect_duplicates(manifest)
        if dup:
            if args.fail_on_duplicates:
                errors.append(f"Duplicates detected in {tar_path.name}: {len(dup)} groups")
            duplicates[tar_path.name] = dup
            warnings.append(f"Duplicates detected in {tar_path.name}: {len(dup)} groups (skipping duplicates in report)")

    if not inventory.exists():
        errors.append(f"Missing inventory: {inventory}")
    if not playbook.exists():
        errors.append(f"Missing playbook: {playbook}")

    ssh_ok, _, ssh_err = ssh_check(args.ssh_user, args.assethost)
    if not ssh_ok:
        errors.append(f"SSH to {args.ssh_user}@{args.assethost} failed: {ssh_err.strip()}")

    k8s_rc, k8s_out, k8s_err, _ = check_k8s_access(args)
    if k8s_rc != 0:
        errors.append(f"Kubernetes access check failed: {k8s_err.strip() or k8s_out.strip()}")

    summary = []
    summary.append("wire_sync_binaries summary")
    summary.append(f"timestamp: {now_ts()}")
    summary.append(f"host: {host_name()}")
    summary.append(f"bundle: {bundle}")
    summary.append(f"inventory: {inventory}")
    summary.append(f"playbook: {playbook}")
    if duplicates:
        summary.append(f"duplicates: {sum(len(v) for v in duplicates.values())} groups")
    else:
        summary.append("duplicates: none")

    print_errors_warnings(errors, warnings)

    audit = {
        "timestamp": now_ts(),
        "host": host_name(),
        "bundle": str(bundle),
        "inventory": str(inventory),
        "playbook": str(playbook),
        "dry_run": args.dry_run,
        "manifests": manifests,
        "duplicates": duplicates,
        "errors": errors,
        "warnings": warnings,
    }

    ts = dt.datetime.utcnow().strftime("%Y%m%dT%H%M%SZ")

    if args.dry_run:
        summary.append("result: dry-run (no ansible execution)")
        json_path, txt_path = write_audit(log_dir, "binaries", audit, summary, ts_override=ts)
        print(f"Audit written: {json_path}")
        print(f"Summary written: {txt_path}")
        return 0

    cmd = build_ansible_cmd(args, inventory, playbook)
    rc, out, err, duration = run_cmd(cmd, verbose=args.verbose)
    stdout_path = Path(log_dir) / f"{ts}_binaries_ansible_stdout.txt"
    stderr_path = Path(log_dir) / f"{ts}_binaries_ansible_stderr.txt"
    if args.verbose:
        stdout_path.write_text("(output streamed to terminal)")
        stderr_path.write_text("(output streamed to terminal)")
    else:
        stdout_path.write_text(out)
        stderr_path.write_text(err)

    audit["ansible"] = {
        "command": " ".join(cmd),
        "exit_code": rc,
        "duration_ms": duration,
        "stdout_path": str(stdout_path),
        "stderr_path": str(stderr_path),
    }

    summary.append(f"ansible_exit_code: {rc}")
    summary.append(f"duration_ms: {duration}")

    json_path, txt_path = write_audit(log_dir, "binaries", audit, summary, ts_override=ts)
    print(f"Audit written: {json_path}")
    print(f"Summary written: {txt_path}")

    if rc != 0:
        print("Ansible failed. See audit logs for details.")
        sys.exit(rc)

    return 0

if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
import argparse
import os
from pathlib import Path
import sys
import datetime as dt

from wire_sync_lib import (
    BUNDLE_ROOT,
    now_ts,
    host_name,
    run_cmd,
    write_audit,
    print_errors_warnings,
)

# sonar-cpd:off
def parse_args():
    p = argparse.ArgumentParser(
        description="Sync container images to containerd via Ansible with audit trail.",
    )
    p.add_argument("--inventory", default=os.environ.get("WIRE_SYNC_INVENTORY", f"{BUNDLE_ROOT}/ansible/inventory/offline/hosts.ini"))
    p.add_argument("--playbook", default=os.environ.get("WIRE_SYNC_PLAYBOOK", f"{BUNDLE_ROOT}/ansible/seed-offline-containerd.yml"))
    p.add_argument("--log-dir", default=os.environ.get("WIRE_SYNC_LOG_DIR", "/var/log/audit_log"))
    p.add_argument("--dry-run", action="store_true")
    p.add_argument("--tags", default="")
    p.add_argument("--skip-tags", default="")
    p.add_argument("--assethost", default=os.environ.get("WIRE_SYNC_ASSETHOST", "assethost"))
    p.add_argument("--ssh-user", default=os.environ.get("WIRE_SYNC_SSH_USER", "demo"))
    p.add_argument("--precheck-assets", action="store_true", default=True)
    p.add_argument("--ansible-cmd", default="ansible-playbook")
    p.add_argument("--use-d", action="store_true")
    p.add_argument("--offline-env", default=os.environ.get("WIRE_SYNC_OFFLINE_ENV", f"{BUNDLE_ROOT}/bin/offline-env.sh"))
    p.add_argument("--kubeconfig", default=os.environ.get("WIRE_SYNC_KUBECONFIG", f"{BUNDLE_ROOT}/ansible/inventory/kubeconfig.dec"))
    p.add_argument("--host-root", default=os.environ.get("WIRE_SYNC_HOST_ROOT", BUNDLE_ROOT))
    p.add_argument("--container-root", default=os.environ.get("WIRE_SYNC_CONTAINER_ROOT", "/wire-server-deploy"))
    p.add_argument("--verbose", action="store_true", help="Show ansible playbook output in real-time")
    return p.parse_args()

def ssh_check(user, host, command):
    cmd = [
        "ssh",
        "-o", "BatchMode=yes",
        "-o", "StrictHostKeyChecking=no",
        f"{user}@{host}",
        command,
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
        cmd = f"source {offline_env_c} && d ansible-playbook -i {inventory_c} {playbook_c}"
        if args.tags:
            cmd += f" --tags {args.tags}"
        if args.skip_tags:
            cmd += f" --skip-tags {args.skip_tags}"
        return ["bash", "-lc", cmd]

    base_cmd = [args.ansible_cmd, "-i", str(inventory), str(playbook)]
    if args.tags:
        base_cmd.extend(["--tags", args.tags])
    if args.skip_tags:
        base_cmd.extend(["--skip-tags", args.skip_tags])
    return base_cmd
# sonar-cpd:on

def main():
    args = parse_args()
    errors = []
    warnings = []

    inventory = Path(args.inventory)
    playbook = Path(args.playbook)
    log_dir = Path(args.log_dir)

    if not inventory.exists():
        errors.append(f"Missing inventory: {inventory}")
    if not playbook.exists():
        errors.append(f"Missing playbook: {playbook}")

    ssh_ok, _, ssh_err = ssh_check(args.ssh_user, args.assethost, "true")
    if not ssh_ok:
        errors.append(f"SSH to {args.ssh_user}@{args.assethost} failed: {ssh_err.strip()}")

    k8s_rc, k8s_out, k8s_err, _ = check_k8s_access(args)
    if k8s_rc != 0:
        errors.append(f"Kubernetes access check failed: {k8s_err.strip() or k8s_out.strip()}")

    asset_checks = {}
    if args.precheck_assets and ssh_ok:
        for rel in [
            "/opt/assets/containers-helm/index.txt",
            "/opt/assets/containers-system/index.txt",
        ]:
            ok, out, err = ssh_check(args.ssh_user, args.assethost, f"test -s {rel} && echo OK")
            asset_checks[rel] = {
                "ok": ok,
                "stdout": out.strip(),
                "stderr": err.strip(),
            }
            if not ok:
                errors.append(f"Missing or empty asset index: {rel}")

    summary = []
    summary.append("wire_sync_images summary")
    summary.append(f"timestamp: {now_ts()}")
    summary.append(f"host: {host_name()}")
    summary.append(f"inventory: {inventory}")
    summary.append(f"playbook: {playbook}")

    print_errors_warnings(errors, warnings)

    audit = {
        "timestamp": now_ts(),
        "host": host_name(),
        "inventory": str(inventory),
        "playbook": str(playbook),
        "dry_run": args.dry_run,
        "asset_checks": asset_checks,
        "errors": errors,
        "warnings": warnings,
    }

    ts = dt.datetime.utcnow().strftime("%Y%m%dT%H%M%SZ")

    if args.dry_run:
        summary.append("result: dry-run (no ansible execution)")
        json_path, txt_path = write_audit(log_dir, "images", audit, summary, ts_override=ts)
        print(f"Audit written: {json_path}")
        print(f"Summary written: {txt_path}")
        return 0

    cmd = build_ansible_cmd(args, inventory, playbook)
    rc, out, err, duration = run_cmd(cmd, verbose=args.verbose)
    stdout_path = Path(log_dir) / f"{ts}_images_ansible_stdout.txt"
    stderr_path = Path(log_dir) / f"{ts}_images_ansible_stderr.txt"
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

    json_path, txt_path = write_audit(log_dir, "images", audit, summary, ts_override=ts)
    print(f"Audit written: {json_path}")
    print(f"Summary written: {txt_path}")

    if rc != 0:
        print("Ansible failed. See audit logs for details.")
        sys.exit(rc)

    return 0

if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""
Cassandra Backup Tool

Creates snapshots of Cassandra keyspaces for backup purposes.
Can run on any node that has Cassandra installed and nodetool available.

Usage:
    # Backup
    python3 cassandra_backup.py --keyspaces brig,galley,gundeck,spar --snapshot-name pre-migration-5.25
    python3 cassandra_backup.py --keyspaces all --snapshot-name pre-migration-5.25 --hosts <cassandra-hosts>
    
    # List snapshots
    python3 cassandra_backup.py --list-snapshots --snapshot-name pre-migration-5.25
    
    # List keyspaces
    python3 cassandra_backup.py --list-keyspaces
    
    # Restore from snapshot
    python3 cassandra_backup.py --restore --snapshot-name pre-migration-5.25 --keyspaces brig
"""

import argparse
import datetime as dt
import json
import os
import subprocess
import sys
from pathlib import Path


def now_ts():
    return dt.datetime.utcnow().replace(microsecond=0).isoformat() + "Z"


def ensure_dir(path: Path):
    path.mkdir(parents=True, exist_ok=True)


def run_cmd(cmd, env=None):
    proc = subprocess.Popen(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        env=env,
    )
    out, err = proc.communicate()
    return proc.returncode, out, err


def run_ssh(host, cmd, key_check=False):
    ssh_cmd = [
        "ssh",
        "-o", "StrictHostKeyChecking=yes" if key_check else "StrictHostKeyChecking=no",
        "-o", "ConnectTimeout=10",
        host
    ] + cmd.split()
    return run_cmd(ssh_cmd)


def get_cassandra_hosts(inventory_path):
    """Parse hosts.ini to get Cassandra node hosts."""
    hosts = []
    inventory = Path(inventory_path)
    if not inventory.exists():
        print(f"Error: Inventory file not found: {inventory_path}")
        return []

    section = ""
    for raw_line in inventory.read_text().splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("[") and line.endswith("]"):
            section = line[1:-1].strip()
            continue
        section_lower = section.lower()
        if "cassandra" not in section_lower or section_lower.endswith(":vars"):
            continue
        parts = line.split()
        if "=" in parts[0]:
            continue
        host = parts[0]
        for part in parts[1:]:
            if part.startswith("ansible_host="):
                host = part.split("=", 1)[1]
                break
        hosts.append(host)

    return sorted(set(hosts))


def create_snapshot(host, keyspace, snapshot_name, verbose=False):
    """Create a Cassandra snapshot on a specific node."""
    cmd = f"nodetool snapshot -t {snapshot_name} {keyspace}"
    
    if verbose:
        print(f"[{host}] Creating snapshot '{snapshot_name}' for keyspace '{keyspace}'...")
    
    rc, out, err = run_ssh(host, cmd)
    
    if rc != 0:
        print(f"Error creating snapshot on {host}: {err}")
        return False, err
    
    return True, out


def list_snapshots(host, keyspace="", snapshot_name="", verbose=False):
    """List snapshots for a keyspace or all keyspaces."""
    if snapshot_name:
        cmd = f"nodetool listsnapshots | grep {snapshot_name}"
    else:
        cmd = "nodetool listsnapshots"
    
    rc, out, err = run_ssh(host, cmd)
    
    if rc != 0:
        return False, err
    
    return True, out


def clear_snapshot(host, snapshot_name, verbose=False):
    """Clear a specific snapshot."""
    cmd = f"nodetool clearsnapshot -t {snapshot_name}"
    
    if verbose:
        print(f"[{host}] Clearing snapshot '{snapshot_name}'...")
    
    rc, out, err = run_ssh(host, cmd)
    
    if rc != 0:
        print(f"Warning: Could not clear snapshot on {host}: {err}")
        return False, err
    
    return True, out


def get_snapshot_size(host, snapshot_name, verbose=False):
    """Get total size of snapshot files."""
    cmd = f"du -sh /var/lib/cassandra/data/*/snapshots/{snapshot_name} 2>/dev/null | tail -1"
    
    rc, out, err = run_ssh(host, cmd)
    
    if rc != 0 or not out.strip():
        return "0"
    
    return out.strip().split()[0] if out.strip() else "0"


def restore_snapshot(host, keyspace, snapshot_name, verbose=False):
    """Restore a Cassandra keyspace from snapshot."""
    cmd = f"""
        SNAPSHOT_DIR=$(find /var/lib/cassandra/data/{keyspace}/ -path "*/snapshots/{snapshot_name}" -type d 2>/dev/null | head -1)
        if [ -z "$SNAPSHOT_DIR" ]; then
            echo "Snapshot not found: {snapshot_name}"
            exit 1
        fi
        systemctl stop cassandra 2>/dev/null || true
        rm -rf /var/lib/cassandra/data/{keyspace}/*
        cp -a $SNAPSHOT_DIR/* /var/lib/cassandra/data/{keyspace}/
        chown -R cassandra:cassandra /var/lib/cassandra/data/{keyspace}/
        systemctl start cassandra 2>/dev/null || true
        echo "Restore completed for {keyspace}"
    """
    
    if verbose:
        print(f"[{host}] Restoring snapshot '{snapshot_name}' for keyspace '{keyspace}'...")
    
    rc, out, err = run_ssh(host, cmd)
    
    if rc != 0:
        print(f"Error restoring snapshot on {host}: {err}")
        return False, err
    
    return True, out


def list_keyspaces(host, verbose=False):
    """List available keyspaces on a Cassandra node."""
    cmd = "cqlsh -e 'SELECT keyspace_name FROM system_schema.keyspaces;' localhost"
    
    rc, out, err = run_ssh(host, cmd)
    
    if rc != 0:
        return False, err
    
    return True, out


def main():
    parser = argparse.ArgumentParser(
        description="Cassandra Backup Tool - Create snapshots for backup"
    )
    parser.add_argument(
        "--keyspaces",
        type=str,
        default="brig,galley,gundeck,spar",
        help="Comma-separated list of keyspaces to backup (or 'all')"
    )
    parser.add_argument(
        "--snapshot-name",
        type=str,
        default=f"backup-{dt.datetime.utcnow().strftime('%Y%m%dT%H%M%SZ')}",
        help="Name for the snapshot"
    )
    parser.add_argument(
        "--hosts",
        type=str,
        help="Comma-separated list of Cassandra hosts (overrides inventory)"
    )
    parser.add_argument(
        "--inventory",
        type=str,
        default="/home/demo/new/ansible/inventory/offline/hosts.ini",
        help="Path to Ansible inventory file"
    )
    parser.add_argument(
        "--backup-dir",
        type=str,
        default="/tmp/cassandra-backups",
        help="Directory to store backup archives"
    )
    parser.add_argument(
        "--clear-snapshots",
        action="store_true",
        help="Clear snapshots after backup"
    )
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Enable verbose output"
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Show what would be done without executing"
    )
    parser.add_argument(
        "--restore",
        action="store_true",
        help="Restore from snapshot instead of backing up"
    )
    parser.add_argument(
        "--list-snapshots",
        action="store_true",
        help="List existing snapshots"
    )
    parser.add_argument(
        "--list-keyspaces",
        action="store_true",
        help="List available keyspaces"
    )
    
    args = parser.parse_args()
    
    # Determine keyspaces
    if args.keyspaces.lower() == "all":
        keyspaces = ["brig", "galley", "gundeck", "spar"]
    else:
        keyspaces = [k.strip() for k in args.keyspaces.split(",")]
    
    # Determine hosts
    if args.hosts:
        hosts = [h.strip() for h in args.hosts.split(",")]
    else:
        hosts = get_cassandra_hosts(args.inventory)
        if not hosts:
            print("Error: No Cassandra hosts found. Provide --hosts or fix inventory.")
            return 1
    
    print(f"Cassandra Backup Tool")
    print(f"=====================")
    print(f"Snapshot name: {args.snapshot_name}")
    print(f"Keyspaces: {', '.join(keyspaces)}")
    print(f"Hosts: {', '.join(hosts)}")
    print(f"Backup directory: {args.backup_dir}")
    print()
    
    # Handle list-keyspaces
    if args.list_keyspaces:
        print("Listing keyspaces on Cassandra nodes...")
        for host in hosts:
            print(f"\n--- Host: {host} ---")
            success, output = list_keyspaces(host, args.verbose)
            if success:
                print(output)
            else:
                print(f"Error: {output}")
        return 0
    
    # Handle list-snapshots
    if args.list_snapshots:
        print("Listing snapshots on Cassandra nodes...")
        for host in hosts:
            print(f"\n--- Host: {host} ---")
            success, output = list_snapshots(host, "", args.snapshot_name, args.verbose)
            if success:
                print(output)
            else:
                print(f"Error: {output}")
        return 0
    
    # Handle restore
    if args.restore:
        print("Restoring from snapshot...")
        print(f"Snapshot name: {args.snapshot_name}")
        print(f"Keyspaces: {', '.join(keyspaces)}")
        print(f"Hosts: {', '.join(hosts)}")
        
        if args.dry_run:
            print("\n[DRY RUN] Would restore:")
            for host in hosts:
                for ks in keyspaces:
                    print(f"  - Restore {ks} from {args.snapshot_name} on {host}")
            return 0
        
        print("\nWARNING: This will overwrite existing data!")
        confirm = input("Type 'yes' to confirm restore: ")
        if confirm.lower() != 'yes':
            print("Restore cancelled.")
            return 1
        
        for host in hosts:
            print(f"\n--- Host: {host} ---")
            for ks in keyspaces:
                success, output = restore_snapshot(host, ks, args.snapshot_name, args.verbose)
                if success:
                    print(f"  OK {ks}: restored from snapshot")
                else:
                    print(f"  FAIL {ks}: {output}")
        
        print("\nWARNING: Cassandra service was restarted. Please wait for the node to come up.")
        return 0
    
    # Handle backup
    if args.dry_run:
        print("[DRY RUN] Would perform the following actions:")
        for host in hosts:
            for ks in keyspaces:
                print(f"  - Create snapshot '{args.snapshot_name}' on {host} for keyspace {ks}")
        return 0
    
    # Create backup directory
    ensure_dir(Path(args.backup_dir))
    
    # Track results
    results = {
        "timestamp": now_ts(),
        "snapshot_name": args.snapshot_name,
        "keyspaces": keyspaces,
        "hosts": hosts,
        "backups": [],
        "errors": [],
    }
    
    # Create snapshots on all hosts
    print("Creating snapshots...")
    for host in hosts:
        print(f"\n--- Host: {host} ---")
        for ks in keyspaces:
            success, output = create_snapshot(host, ks, args.snapshot_name, args.verbose)
            
            if success:
                size = get_snapshot_size(host, args.snapshot_name, args.verbose)
                print(f"  OK {ks}: snapshot created (size: {size})")
                results["backups"].append({
                    "host": host,
                    "keyspace": ks,
                    "status": "success",
                    "size": size
                })
            else:
                print(f"  FAIL {ks}: {output}")
                results["errors"].append({
                    "host": host,
                    "keyspace": ks,
                    "error": output
                })
    
    # Clear snapshots if requested
    if args.clear_snapshots:
        print("\nClearing snapshots...")
        for host in hosts:
            success, output = clear_snapshot(host, args.snapshot_name, args.verbose)
            if success:
                print(f"  OK {host}: snapshots cleared")
            else:
                print(f"  FAIL {host}: {output}")
    
    # Summary
    print("\n" + "=" * 50)
    print("Backup Summary")
    print("=" * 50)
    
    success_count = len([b for b in results["backups"] if b["status"] == "success"])
    error_count = len(results["errors"])
    
    print(f"Successful snapshots: {success_count}")
    print(f"Errors: {error_count}")
    print(f"Backup location: {args.backup_dir}")
    print(f"Snapshot name: {args.snapshot_name}")
    
    # Save audit log
    audit_path = Path(args.backup_dir) / f"audit_{args.snapshot_name}.json"
    audit_path.write_text(json.dumps(results, indent=2))
    print(f"Audit log: {audit_path}")
    
    if error_count > 0:
        print("\nErrors encountered:")
        for err in results["errors"]:
            print(f"  - {err['host']}/{err['keyspace']}: {err['error']}")
        return 1
    
    return 0


if __name__ == "__main__":
    sys.exit(main())

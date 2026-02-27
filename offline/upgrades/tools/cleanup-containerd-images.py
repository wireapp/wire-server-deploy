#!/usr/bin/env python3
import argparse
import json
import subprocess
import sys
import shutil
import datetime as dt
import re
from pathlib import Path

def run(cmd, use_shell=False):
    if use_shell:
        result = subprocess.run(cmd, shell=True, check=False, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    else:
        result = subprocess.run(cmd, check=False, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if result.returncode != 0:
        raise RuntimeError("Command failed code=%s: %s\n%s" % (result.returncode, cmd, result.stderr))
    return result.stdout

def get_pod_images(kubectl_cmd, use_shell=False):
    if use_shell:
        data = run("bash -lc '%s get pods -A -o json'" % kubectl_cmd, use_shell=True)
    else:
        data = run([*kubectl_cmd, 'get', 'pods', '-A', '-o', 'json'])
    payload = json.loads(data)
    image_names = set()
    image_digests = set()
    for item in payload.get('items', []):
        statuses = item.get('status', {}).get('containerStatuses', [])
        for st in statuses:
            image = st.get('image')
            image_id = st.get('imageID')
            if image:
                image_names.add(image)
            if image_id and '@' in image_id:
                image_digests.add(image_id.split('://')[-1])
    return image_names, image_digests

def is_executable(cmd):
    if not cmd:
        return False
    first = cmd[0]
    if first == 'sudo' and len(cmd) > 1:
        first = cmd[1]
    return shutil.which(first) is not None

def get_local_images_crictl(crictl_cmd):
    data = run([*crictl_cmd, 'images', '-o', 'json'])
    payload = json.loads(data)
    images = payload.get('images', [])
    return images

def parse_size_to_bytes(size_str):
    units = {
        'B': 1,
        'KB': 1000,
        'MB': 1000 ** 2,
        'GB': 1000 ** 3,
        'TB': 1000 ** 4,
        'KIB': 1024,
        'MIB': 1024 ** 2,
        'GIB': 1024 ** 3,
        'TIB': 1024 ** 4,
    }
    match = re.match(r'^(\d+(?:\.\d+)?)\s*([A-Za-z]+)$', size_str)
    if not match:
        return 0
    value = float(match.group(1))
    unit = match.group(2).upper()
    return int(value * units.get(unit, 1))

def get_local_images_ctr(use_sudo=False):
    cmd = ['ctr', '-n', 'k8s.io', 'images', 'ls', '-q']
    if use_sudo:
        cmd = ['sudo', *cmd]
    data = run(cmd)
    refs = [line.strip() for line in data.splitlines() if line.strip()]
    return refs

def get_ctr_image_sizes(use_sudo=False):
    cmd = ['ctr', '-n', 'k8s.io', 'images', 'ls']
    if use_sudo:
        cmd = ['sudo', *cmd]
    data = run(cmd)
    sizes = {}
    lines = data.splitlines()
    if not lines:
        return sizes
    for line in lines[1:]:
        if not line.strip():
            continue
        tokens = line.split()
        ref = tokens[0]
        size = 0
        for i in range(1, len(tokens) - 1):
            if re.match(r'^\d', tokens[i]) and re.match(r'^[A-Za-z]+$', tokens[i + 1]):
                size = parse_size_to_bytes(tokens[i] + tokens[i + 1])
                break
        if size == 0:
            for token in tokens:
                if re.match(r'^\d', token):
                    size = parse_size_to_bytes(token)
                    if size:
                        break
        sizes[ref] = size
    return sizes

def main():
    parser = argparse.ArgumentParser(description='Prune unused containerd images (k8s.io namespace)')
    parser.add_argument('--apply', action='store_true', help='Actually remove images (default: dry-run)')
    parser.add_argument('--sudo', action='store_true', help='Run crictl with sudo')
    parser.add_argument('--kubectl-cmd', default='d kubectl', help='Kubectl command wrapper (default: d kubectl)')
    parser.add_argument('--kubectl-shell', action='store_true', help='Run kubectl command via shell')
    parser.add_argument('--crictl-cmd', default='crictl', help='crictl command (default: crictl)')
    parser.add_argument('--log-dir', default='', help='Write audit logs to this directory')
    parser.add_argument('--audit-tag', default='', help='Optional tag to include in audit filenames')
    args = parser.parse_args()

    kubectl_cmd = args.kubectl_cmd if args.kubectl_shell else args.kubectl_cmd.split()
    crictl_cmd = args.crictl_cmd.split()
    if args.sudo:
        crictl_cmd = ['sudo', *crictl_cmd]

    image_names, image_digests = get_pod_images(kubectl_cmd, use_shell=args.kubectl_shell)

    use_crictl = is_executable(crictl_cmd)
    use_ctr = not use_crictl

    ctr_sizes = {}
    if use_ctr:
        images = get_local_images_ctr(use_sudo=args.sudo)
        ctr_sizes = get_ctr_image_sizes(use_sudo=args.sudo)
    else:
        images = get_local_images_crictl(crictl_cmd)

    keep = []
    remove = []
    total_remove_bytes = 0
    if use_ctr:
        for ref in images:
            in_use = ref in image_names or ref in image_digests
            if in_use:
                keep.append((ref, [ref], []))
            else:
                remove.append((ref, [ref], []))
                total_remove_bytes += ctr_sizes.get(ref, 0)
    else:
        for img in images:
            img_id = img.get('id')
            repo_tags = img.get('repoTags') or []
            repo_digests = img.get('repoDigests') or []
            size = img.get('size', 0)

            in_use = False
            for tag in repo_tags:
                if tag in image_names:
                    in_use = True
                    break
            if not in_use:
                for digest in repo_digests:
                    if digest in image_digests:
                        in_use = True
                        break

            if in_use:
                keep.append((img_id, repo_tags, repo_digests))
            else:
                remove.append((img_id, repo_tags, repo_digests))
                if isinstance(size, int):
                    total_remove_bytes += size

    print("Running images found: %d" % len(image_names))
    print("Local images found: %d" % len(images))
    print("Keep: %d" % len(keep))
    print("Remove: %d" % len(remove))
    if total_remove_bytes:
        print("Estimated remove bytes: %d" % total_remove_bytes)

    for img_id, repo_tags, repo_digests in remove:
        label = repo_tags[0] if repo_tags else (repo_digests[0] if repo_digests else '<none>')
        print("REMOVE %s %s" % (img_id, label))

    if not args.apply:
        print('Dry-run only. Re-run with --apply to remove images.')
        write_audit(args, keep, remove, total_remove_bytes)
        return 0

    if use_ctr:
        for img_id, _, _ in remove:
            cmd = ['ctr', '-n', 'k8s.io', 'images', 'rm', img_id]
            if args.sudo:
                cmd = ['sudo', *cmd]
            run(cmd)
    else:
        for img_id, _, _ in remove:
            run([*crictl_cmd, 'rmi', img_id])
    print('Image removal complete.')
    write_audit(args, keep, remove, total_remove_bytes)
    return 0

def write_audit(args, keep, remove, total_remove_bytes):
    if not args.log_dir:
        return
    Path(args.log_dir).mkdir(parents=True, exist_ok=True)
    ts = dt.datetime.utcnow().strftime("%Y%m%dT%H%M%SZ")
    tag = ("_" + args.audit_tag) if args.audit_tag else ""
    base = f"cleanup{tag}_{ts}"
    json_path = Path(args.log_dir) / f"{base}.json"
    txt_path = Path(args.log_dir) / f"{base}.txt"
    payload = {
        "timestamp": ts,
        "remove_count": len(remove),
        "keep_count": len(keep),
        "estimated_remove_bytes": total_remove_bytes,
        "remove": [{"id": r[0], "tags": r[1], "digests": r[2]} for r in remove],
    }
    json_path.write_text(json.dumps(payload, indent=2))
    txt_path.write_text(
        "\n".join([
            f"timestamp: {ts}",
            f"remove_count: {len(remove)}",
            f"keep_count: {len(keep)}",
            f"estimated_remove_bytes: {total_remove_bytes}",
        ]) + "\n"
    )

if __name__ == '__main__':
    try:
        sys.exit(main())
    except Exception as exc:
        print(str(exc), file=sys.stderr)
        sys.exit(1)

---
layout: guide-revisions.liquid

guide_component: revisions
guide_id: migrating-k3s-to-rke2
repo_file_path: guides/migrating-k3s-to-rke2/revisions.md
---

## Revision History

This page tracks all changes and updates to this guide.

## Changes

- 2026-05-17 - Added "Booting into the Hetzner Rescue System" section to Lesson 2
- 2026-05-17 - Added "Configuring Pod Security Admission" section to Lesson 5 with the `rke2-pss.yaml` file and per-namespace tightening guidance
- 2026-05-17 - Added "Rollout Sequence" to the PSA section in Lesson 5 covering safe migration from `privileged` to a tighter cluster default
- 2026-05-17 - Removed the incorrect first-install `systemctl restart` from the runc patching section in Lesson 5
- 2026-05-17 - Added SHA256 checksum verification note for the runc download in Lesson 5
- 2026-05-17 - Removed duplicated `openssl x509` line in Lesson 5 troubleshooting
- 2026-05-17 - Replaced explicit `sha256sum --check` steps with a note for the `longhornctl` download in Lesson 7
- 2026-05-17 - Fixed Tailscale repository URL in Lesson 11 (`stable/fedora//` → `stable/centos/10/`)
- 2026-05-17 - Added `rke2-pss.yaml` copy step to Lesson 11 and to the identical-files list in Lesson 12 so joining control plane nodes carry the same PSA configuration as Node 4
- 2026-05-17 - Renamed vSwitch NetworkManager connection from `vswitch0` to `vswitch` in Lesson 11 for consistency with Lesson 3
- 2026-05-17 - Fixed broken cross-references in Lessons 11, 12, and 15 from `lesson-6#isolating-host-dns-from-pod-dns` to `lesson-5#create-configuration`
- 2026-05-17 - Added missing secondary IPv6 nameserver `2606:4700:4700::1001` to `resolv.conf` in Lessons 11, 12, and 15 to match Lesson 5
- 2026-05-17 - Fixed `kube-scheduler` lease holder identity typo in Lesson 13
- 2026-05-17 - Changed worker node label value from `=true` to `=""` in Lesson 15

## Contributing

If you find errors or have suggestions for improvements:

1. Open an issue on the [GitHub repository](https://github.com/philprime/philprime.dev)
2. Submit a pull request with your proposed changes
3. Contact the author through the website

## Acknowledgments

Thanks to all contributors and reviewers who helped improve this guide.

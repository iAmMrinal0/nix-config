# NixOS setup for Homer (Garmin Connect IQ)

This document captures the research-backed install plan for running Garmin's Connect IQ SDK on NixOS, and ends with a hand-off prompt that can be pasted into a fresh agent session pointed at the user's `nix-config` directory.

## Why this is non-trivial on NixOS

Garmin ships the Connect IQ SDK Manager as an unpatched Linux binary that links against `libwebkit2gtk-4.0` — a library that is being removed from modern distros (and from nixpkgs). The official tarball will not run on a stock NixOS system even with `nix-ld` because tracking down every missing `.so` is brittle and `webkit2gtk_4_0` is on the way out of nixpkgs.

**Decision:** use the community AppImage from `pcolby/connectiq-sdk-manager`, which bundles its own copy of the missing libraries. Run it via `appimage-run`. This is the lowest-risk, most-maintained option in 2026.

Alternatives considered and rejected:
- `nix-ld` — brittle, needs constant maintenance as Garmin's link list shifts
- `steam-run` / `buildFHSUserEnv` — doesn't solve the missing `libwebkit2gtk-4.0`
- `distrobox`/podman with Ubuntu 22.04 — works but heavier than needed
- `samueldr/nix-connectiq` overlay — abandoned since 2019, pins an ancient SDK
- Official Garmin Linux tarball — won't run on modern NixOS

## What needs to land in nix-config

### System-level packages
- `appimage-run` — to launch the SDK Manager AppImage
- `vscode-fhs` (NOT plain `vscode`) — the FHS-wrapped variant so the Monkey C extension's native helpers work
- `jdk17` — Connect IQ tooling expects JDK 17 on PATH with `JAVA_HOME` set
- `git` — for the project repo (already likely installed)

### Other system options
- `programs.appimage.binfmt = true;` — makes AppImages directly executable, avoids having to prefix every invocation with `appimage-run`
- Udev rule for Garmin's USB vendor ID `091e` — required so the watch is sideload-writable when plugged in over USB

### Snippet to add (legacy `configuration.nix` form)

```nix
{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    appimage-run
    vscode-fhs
    jdk17
    git
  ];

  programs.appimage.binfmt = true;

  services.udev.extraRules = ''
    SUBSYSTEM=="usb", ATTRS{idVendor}=="091e", MODE="0666", TAG+="uaccess"
  '';
}
```

If the user is on home-manager + flakes, the equivalent pieces go in their respective modules — packages in `home.packages` or `environment.systemPackages` (system vs. user), udev rules at the system level only.

## What happens after the config lands

1. `sudo nixos-rebuild switch` (and reboot once for udev to apply on first run)
2. Download the AppImage from https://github.com/pcolby/connectiq-sdk-manager/releases (latest is 0.6.9 as of March 2026)
3. `chmod +x` and run it; the GUI opens
4. In the GUI: install latest Connect IQ SDK (9.x), add device profiles for `epix2` and `epix2pro`
5. The SDK writes to `~/.Garmin/ConnectIQ/` (mutable, outside the Nix store — correct)
6. Open VS Code, install the official `garmin.monkey-c` extension; it auto-detects the SDK
7. Plug in the watch, run `lsusb | grep -i 091e` to confirm and capture the product ID for a future tightening of the udev rule

## Verification commands

After `nixos-rebuild switch`:

```sh
appimage-run --version
java -version                    # should report 17.x
which code                       # should be vscode-fhs's wrapper
```

After SDK install:

```sh
ls ~/.Garmin/ConnectIQ/Sdks/
~/.Garmin/ConnectIQ/Sdks/connectiq-sdk-*/bin/monkeyc --version
```

## Things to deliberately NOT do

- Do **not** add `libwebkit2gtk_4_0` or other system libraries hoping the official tarball will run — that path is unmaintained upstream and breaks on every SDK release.
- Do **not** install `pkgs.vscode` (unwrapped) — the Monkey C extension's native components will fail.
- Do **not** pin `samueldr/nix-connectiq` — the overlay is dead.
- Do **not** put the CIQ SDK itself in `/nix/store` — per-device profiles are downloaded dynamically by the SDK Manager and need a mutable directory under `$HOME`.

---

## Hand-off prompt for the nix-config agent

Paste the section below into a fresh Claude Code session opened in the user's `nix-config` directory.

> **Context for this task:**
>
> The user is building a Garmin Connect IQ watch app (Monkey C) for the Epix Gen 2 / Pro. The watch-app project lives at `/home/iammrinal0/oss/homer` — you do NOT need to touch that directory. Your job is to update the user's NixOS configuration in **this** repo so the Garmin Connect IQ toolchain can run on their machine.
>
> The toolchain has known issues on modern Linux distros — Garmin's official SDK Manager links against `libwebkit2gtk-4.0` which is being removed from nixpkgs. **Do not try to patch that library in.** The decision has already been made: install `appimage-run` and let the user run the community AppImage from `pcolby/connectiq-sdk-manager` (which bundles its own webkit). See `/home/iammrinal0/oss/homer/nixos.md` for the full research write-up if you want context.
>
> **Concrete changes to make to nix-config:**
>
> Find where the user declares system packages (likely `configuration.nix`, a `modules/` directory, or a flake-shaped equivalent), and add:
>
> 1. **Packages:** `appimage-run`, `vscode-fhs` (NOT plain `vscode`), `jdk17`, `git`.
> 2. **AppImage binfmt:** enable `programs.appimage.binfmt = true;` so AppImages run directly without the `appimage-run` prefix.
> 3. **Udev rule** for Garmin's USB vendor ID:
>
>    ```nix
>    services.udev.extraRules = ''
>      SUBSYSTEM=="usb", ATTRS{idVendor}=="091e", MODE="0666", TAG+="uaccess"
>    '';
>    ```
>
>    If the user already has a `services.udev.extraRules` block, append to it rather than replacing.
>
> 4. If the user uses home-manager and prefers per-user packages, put `vscode-fhs` and `jdk17` in their home config instead of system-wide. `appimage-run` and the udev rule must be system-level either way.
>
> **Before you commit:**
> - Read the user's existing config structure first — don't assume legacy vs. flake. Match their conventions.
> - If `jdk17` conflicts with an existing JDK, ask before swapping versions. CIQ may also work with JDK 21 (unverified); JDK 17 is the documented requirement.
> - If `vscode-fhs` conflicts with an existing `vscode` package, swap it (they can't both be installed).
> - Do not run `nixos-rebuild`; show the diff and let the user run it themselves.
>
> **Stop and ask** if any of these apply:
> - The user already has a working CIQ install via a different route (`nix-ld`, distrobox, etc.) — confirm before overriding.
> - The user's config uses a non-standard module system (e.g., `flake-parts`, `nixos-unified`) and the additions need restructuring.
> - You can't find where system packages are declared.
>
> Output a clear summary of what you changed and the verification commands the user should run after `nixos-rebuild switch`:
>
> ```sh
> appimage-run --version
> java -version
> lsusb | grep -i 091e   # only if the watch is plugged in
> ```

---

## Reference links

- Community AppImage (active, maintained): https://github.com/pcolby/connectiq-sdk-manager
- Garmin "Getting Started" (official docs, Linux instructions are FHS-shaped): https://developer.garmin.com/connect-iq/connect-iq-basics/getting-started/
- Garmin forum thread on the `libwebkit2gtk-4.0` issue: https://forums.garmin.com/developer/connect-iq/f/discussion/417048/connect-iq-8-2-1-sdk-linux-using-old-webkitgtk-library
- NixOS Wiki — Nix-ld: https://wiki.nixos.org/wiki/Nix-ld
- NixOS Wiki — VS Code (vscode.fhs): https://nixos.wiki/wiki/Visual_Studio_Code
- USB Garmin udev background: https://wiki.openstreetmap.org/wiki/USB_Garmin_on_GNU/Linux
- Abandoned overlay (don't use, for awareness only): https://github.com/samueldr/nix-connectiq

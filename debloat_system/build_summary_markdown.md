# Samsung Galaxy A36 (SM-A366E) Debloated & Degoogled ROM

Custom debloated and fully degoogled system build for Samsung Galaxy A36 based on the official firmware. This project aims to provide maximum privacy, better battery life, and total control over your device without Google telemetry or pre-installed bloatware.

## Build Information
*   **Base Firmware:** A366EXXU4BYI7
*   **Android Version:** 16
*   **OneUI Version:** 8
*   **Bootloader Bit:** 4

## Key Features
*   **[+] Fully Degoogled:** Google Mobile Services (GMS) completely removed and replaced with lightweight microG.
*   **[+] Hardcore Debloat:** Over 230 system apps, trackers, and operator bloatware removed.
*   **[+] Privacy-focused:** FlorisBoard used as the default keyboard out of the box (works 100% offline).

## Build Summary
*   **Super image size:** 9.9 GB -> 5.8 GB (-4.1 GB space saved!)
*   **Total apps originally:** 374
*   **Removed apps:** 232
*   **Kept apps:** 142
*   **Added custom apps:** 13

## Pre-installed Applications

### [priv-app] (Non-deletable system apps):
*   **microG** — Open-source implementation of Google services                          [[GitHub](https://github.com/microg/GmsCore)]
*   **FakeStore** — Play Store identity spoofing for apps                               [[GitHub](https://github.com/microg/GmsCore)]
*   **FlorisBoard** — Privacy-respecting keyboard                                       [[GitHub](https://github.com/florisboard/florisboard)]

### [app] (Preloaded, fully deletable by user*):
##### *\* - copied to the user space on the first boot, fully launcher-deletable; see [this note](#%EF%B8%8F-note-on-kernelsu-next-preinstallation) for more technical details*
*   ~~**KernelSU-Next (Spoofed)** — Next-gen kernel root manager with random package ID [[GitHub](https://github.com/KernelSU-Next/KernelSU-Next)]~~ *(Attempted to preinstall, see the note below)*
*   **LibreTube** — Privacy-friendly YouTube client                                     [[GitHub](https://github.com/libre-tube/LibreTube)]
*   **PVOT-OSS/Messages** — Clean and simple open-source SMS client                     [[GitHub](https://github.com/PVOT-OSS/Messages)]
*   **F-Droid** — FOSS app repository                                                   [[F-Droid](https://f-droid.org)]
*   **Fennec** — Firefox-based browser with telemetry stripped                          [[F-Droid](https://f-droid.org/en/packages/org.mozilla.fennec_fdroid/)]
*   **Aurora Store** — Anonymous Google Play client                                     [[F-Droid](https://f-droid.org/en/packages/com.aurora.store)]
*   **Voice Recorder / My Files / Clock / Calendar / Calculator**                       [[Samsung Store stock apps](https://galaxystore.samsung.com)]

### ⚠️ Note on KernelSU-Next Preinstallation

I initially intended to include the KernelSU-Next Manager APK in the system `preload` directory so it could be automatically installed and easily removed by the user. However, due to a bug in how the Samsung OneUI 8 / Android 16 mechanism copies preloaded APKs into user space, native libraries (`libksud.so`) fail to register correctly, leading to an immediate application crash (Segmentation Fault).

To be absolutely transparent with the community: all other preloaded apps (from [app list]) technically remain stored as static, non-executable files inside `/system/preload` even after you uninstall them from your launcher. While this does occupy a small fraction of your storage, modern smartphones have plenty of space to spare — especially considering we already shrunk the `super.img` size by over 4 GB. These preloaded apps are essential to provide a comfortable, out-of-the-box user experience on a completely degoogled system.

However, the only workaround to keep KernelSU pre-installed would be forcing it directly into `/system/app` or `/system/priv-app`. Doing so breaks the core philosophy of this project: **giving users total control over their app drawer**. Unlike preload apps, a `/system` installation forces the app onto the user permanently with no option to fully remove its icon from the launcher. I refuse to force-feed system-level apps just because I personally use them (the only exception is microG, for obvious GMS-replacement reasons).

An ordinary manual installation completely solves the library crash. If you need Root, simply download the official APK and install it manually.

## Prerequisites

Before starting the installation, you must manually download the compatible GKI KernelSU + SuSFS images for your device:
*   **Download Source:** Head over to [[WildKernels GKI Actions](https://github.com/WildKernels/GKI_KernelSU_SUSFS/actions?query=workflow%3A%22Build+Kernels%22+is%3Asuccess)] and look for successful workflow runs.
*   **Workflow Selection:** The developer triggers multiple build tasks for various Android versions. To find the correct full-scale kernel compilation, look strictly for the run where the **Build time** is **≥ 1h**.
*   **Kernel Version Match:** Double-check your current device settings and download **only** the exact version that matches your kernel release. Keep in mind that a newer Android OS version may still run on an older base kernel, so checking the exact kernel string is mandatory.
*   **Image Format (Crucial):** Download either the uncompressed image (`*boot.img`) or the GZIP archive (`*boot-gz.img`). Be cautious with the LZ4 compressed format (`*boot-lz4.img`), as it may cause a bootloop on Samsung devices depending on the specific model. Sticking to uncompressed or GZIP images is the safest choice.

## Installation Guide

Follow these instructions carefully to flash the image. 

1. **Reboot into Bootloader**
2. **Flash fastboot.img and boot.img through Heimdall:**
   ```bash
   heimdall flash --VENDOR_BOOT_A path/to/fastboot.img --BOOT_A path/to/boot.img
   ```
3. **Reboot into Recovery**
4. **Select "Enter fastboot"**
5. **Flash super.img through Fastboot:**
   ```bash
   fastboot flash super super.img
   ```
6. **Flash prism.img through Fastboot:**
   ```bash
   fastboot flash prism_a prism.img
   ```
   *Note: This step is only necessary for the SER region to bypass region-locked bloatware like RuStore/Yandex.*
7. **Select "Enter recovery"**
8. **Perform a wipe:** Go to `Wipe data/factory reset` --> `Factory data reset`
9. **Reboot into Bootloader**
10. **Flash stock vendor_boot.img through Heimdall:**
    ```bash
    heimdall flash --VENDOR_BOOT_A path/to/vendor_boot.img
    ```
    ```text
    ╭────────────────────────────────────────────────────────────────────────────╮
    │ [!] CRITICAL CAUTION: YOU MUST DO THIS STEP TO RETURN THE STOCK IMAGE! [!] │
    │                    OTHERWISE YOU WILL GET INTO A BOOTLOOP                  │
    ╰────────────────────────────────────────────────────────────────────────────╯
    ```
11. **Reboot into System.** Complete the setup wizard, activate FlorisBoard in settings, and enjoy your clean device!

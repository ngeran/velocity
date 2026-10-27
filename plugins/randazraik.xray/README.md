# randazraik.xray — Omarchy X-Ray (ported)

Traces any window, process, service, container, port, file, or device to the
process behind it. Ported from omarchy-xray (MIT); the Python backend is
spawned over JSON-lines.

**Banner exemption (audit I6):** the files under `ui/` are upstream omarchy-xray
code kept close to the source for future re-syncs — they intentionally do not
carry the velocity file-banner convention. Everything first-party around them
(`XRay.qml`, `XRayBarWidget.qml`, manifest) follows the normal rules.

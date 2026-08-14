# Release assets

This directory contains the verified payload used by the one-shot GitHub
Actions release publisher. Normal development builds and signing material remain
excluded from version control.

The DMG is a Universal macOS 14+ build with an ad-hoc signature and no Developer
Team identifier. Verify it against `SHA256SUMS` before publishing.

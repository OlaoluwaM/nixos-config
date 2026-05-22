# Repository Instructions

## Quickshell QML

This repo uses QML for the Hyprland Quickshell shell in:

- `modules/home-manager/hyprland/quickshell/**/*.qml`

When editing those files, use the `qt-qml` skill if available.

Before finalizing substantial QML changes, use the `qt-qml-review` skill if available and address correctness, layout, binding, and maintainability findings.

If either skill is missing, ask the user before installing it with:

```sh
python /home/olaolu/.codex/skills/.system/skill-installer/scripts/install-skill-from-github.py \
  --repo TheQtCompanyRnD/agent-skills \
  --path skills/qt-qml \
  --path skills/qt-qml-review
```

After installation, tell the user to restart Codex so the skills are picked up.

## Qt Documentation MCP

When researching Qt or QML APIs for Quickshell work, prefer the `qt-docs` MCP server if it is already configured. It provides Qt documentation lookup through:

- `https://qt-docs-mcp.qt.io/mcp`

If the MCP server is not configured, fall back to official Qt and Quickshell documentation. Ask the user before configuring the MCP server globally, because that changes the local agent environment rather than this repository.

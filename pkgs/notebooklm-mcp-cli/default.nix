{
  lib,
  python3Packages,
  fetchFromGitHub,
  ...
}:

# Derivation for https://github.com/jacob-bd/gemini-notebook-mcp-cli
let
  version = "0.15.7";

  # nixos-26.05 backported anyio 4.15.1 (2026-10-23) without moving fastmcp
  # off 3.2.3, and three of that release's stateful-proxy client tests now
  # fail on disconnect with anyio's "exit a cancel scope that isn't the
  # current task's" error, which fails the whole build. It is confined to
  # fastmcp's proxy client, which this package doesn't use (it runs an MCP
  # server). Skip that test file for this package only; drop the override
  # once https://github.com/NixOS/nixpkgs/issues/580398 is fixed on the
  # channel and a plain `python3Packages.fastmcp` builds again.
  fastmcp = python3Packages.fastmcp.overridePythonAttrs (old: {
    disabledTestPaths = (old.disabledTestPaths or [ ]) ++ [
      "tests/server/providers/proxy/test_stateful_proxy_client.py"
    ];
  });
in

python3Packages.buildPythonApplication {
  pname = "notebooklm-mcp-cli";
  inherit version;
  pyproject = true;

  src = fetchFromGitHub {
    owner = "jacob-bd";
    repo = "gemini-notebook-mcp-cli";
    rev = "v${version}";
    hash = "sha256-Fl9RHeDG+S69eyZuXiljl0mxusksLq2rWTw4Slu6CnM=";
  };

  build-system = with python3Packages; [
    hatchling
  ];

  dependencies = [
    fastmcp
  ]
  ++ (with python3Packages; [
    httpx
    pydantic
    typer
    rich
    websocket-client
    platformdirs
    pyyaml
    typing-extensions
    filelock
    questionary
    tomlkit
  ]);

  pythonImportsCheck = [
    "notebooklm_tools"
  ];

  meta = {
    description = "Unified CLI and MCP server for Google NotebookLM";
    homepage = "https://github.com/jacob-bd/gemini-notebook-mcp-cli";
    license = lib.licenses.mit;
    mainProgram = "nlm";
  };
}

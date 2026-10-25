{
  lib,
  python3Packages,
  fetchFromGitHub,
  ...
}:

# Derivation for https://github.com/jacob-bd/gemini-notebook-mcp-cli
let
  version = "0.15.7";
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

  dependencies = with python3Packages; [
    httpx
    pydantic
    typer
    rich
    websocket-client
    platformdirs
    fastmcp
    pyyaml
    typing-extensions
    filelock
    questionary
    tomlkit
  ];

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

{
  lib,
  python3Packages,
  fetchFromGitHub,
  ...
}:

# Derivation for https://github.com/jacob-bd/notebooklm-mcp-cli
let
  version = "0.6.4";
in

python3Packages.buildPythonApplication {
  pname = "notebooklm-mcp-cli";
  inherit version;
  pyproject = true;

  src = fetchFromGitHub {
    owner = "jacob-bd";
    repo = "notebooklm-mcp-cli";
    rev = "v${version}";
    hash = "sha256-s8WVT/tAGUpLsYs7PFJFad1EGoy81yutDer6dF0AuSg=";
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
  ];

  pythonImportsCheck = [
    "notebooklm_tools"
  ];

  meta = {
    description = "Unified CLI and MCP server for Google NotebookLM";
    homepage = "https://github.com/jacob-bd/notebooklm-mcp-cli";
    license = lib.licenses.mit;
    mainProgram = "nlm";
  };
}

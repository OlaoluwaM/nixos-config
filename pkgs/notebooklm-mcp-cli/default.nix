{
  lib,
  python3Packages,
  fetchFromGitHub,
  ...
}:

# Derivation for https://github.com/jacob-bd/gemini-notebook-mcp-cli
let
  version = "0.9.14";
in

python3Packages.buildPythonApplication {
  pname = "notebooklm-mcp-cli";
  inherit version;
  pyproject = true;

  src = fetchFromGitHub {
    owner = "jacob-bd";
    repo = "gemini-notebook-mcp-cli";
    rev = "v${version}";
    hash = "sha256-V5yZNVjMETMF5AZ9zC/Ol9VccRZYVaDmznNKpUZr+vg=";
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
    homepage = "https://github.com/jacob-bd/gemini-notebook-mcp-cli";
    license = lib.licenses.mit;
    mainProgram = "nlm";
  };
}

{ unstable }:

final: _prev:

{
  asusctl = import ../../lib/select-asusctl-package.nix {
    inherit final unstable;
  };
}

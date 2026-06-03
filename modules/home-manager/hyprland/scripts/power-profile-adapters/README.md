# Power Profile Adapters

This directory contains backend adapters for `hypr-shell-power-profile`.

Adapter filenames use this shape:

```text
NN-name.sh
```

The numeric prefix controls backend preference. Lower numbers are tried first.
The suffix becomes the backend function prefix, so `10-powerprofilesctl.sh`
must define functions named `powerprofilesctl_available`,
`powerprofilesctl_get`, `powerprofilesctl_set`, and
`powerprofilesctl_cycle`. Keep the suffix shell-function-friendly and make it
match the adapter function prefix exactly.

Each adapter must expose the same interface:

```sh
name_available
name_get
name_set PROFILE
name_cycle
```

Adapters may also define private helper functions, including normalization
helpers. Public `get`, `set`, and `cycle` behavior should use normalized
profiles only:

```text
performance
balanced
power-saver
```

The main script owns backend discovery, selection, validation, and command-line
handling. Adapters should only answer whether their backend works on this
machine and translate between normalized profile names and backend-specific
commands or labels.

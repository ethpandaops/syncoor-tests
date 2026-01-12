# syncoor-tests

This repository contains Github Workflows that run [Syncoor](https://github.com/ethpandaops/syncoor) tests.

## Regenerating [Dispatchoor](https://github.com/ethpandaops/dispatchoor) Templates

The `config/dispatchoor/` directory contains YAML configuration files for [dispatchoor](https://github.com/ethpandaops/dispatchoor). These files can be regenerated using:

```bash
make config
```

To modify the configurations, edit `config/dispatchoor/generate.sh` and re-run the command above.

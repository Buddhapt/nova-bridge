<div align="center">

# NOVA Framework - Bridge

**Compatibility layer for ESX, QBCore, vRPex & Creative scripts.**

Use your existing scripts with the NOVA Framework — zero rewrites needed.

[![License](https://img.shields.io/badge/license-GPL--3.0-green)](LICENSE)
[![FiveM](https://img.shields.io/badge/FiveM-compatible-blue)](https://fivem.net)
[![Docs](https://img.shields.io/badge/docs-GitBook-orange)](https://novaframeworkdoc.gitbook.io/novaframework/)

</div>

---

## What is this?

`nova_bridge` acts as a compatibility layer that translates calls from ESX, QBCore, vRPex, or Creative scripts into NOVA Framework calls. This means you can run scripts made for other frameworks without modifying them.

## Quick Start

**Requirements:** [nova_core](https://github.com/NoVaPTdev/nova-core)

1. Place `nova_bridge` inside `resources/[nova]/`
2. Add to `server.cfg` (after `nova_core`):
```cfg
ensure nova_core
ensure nova_bridge
```
3. Set your bridge mode in `config.lua`:
```lua
BridgeConfig.Mode = 'esx'      -- ESX scripts work
BridgeConfig.Mode = 'qbcore'   -- QBCore scripts work
BridgeConfig.Mode = 'vrpex'    -- vRPex scripts work
BridgeConfig.Mode = 'creative' -- Creative scripts work
BridgeConfig.Mode = 'none'     -- No bridge (NOVA-native only)
```

## Supported Frameworks

| Mode | Provides | Description |
|------|----------|-------------|
| `esx` | `es_extended` | Full ESX compatibility |
| `qbcore` | `qb-core` | Full QBCore compatibility |
| `vrpex` | `vrp` | vRPex compatibility |
| `creative` | — | Creative Network compatibility |
| `none` | — | Bridge disabled |

## Documentation

Full documentation and configuration guide:

### **[Read the Docs](https://novaframeworkdoc.gitbook.io/novaframework/)**

## License

This project is licensed under the GPL-3.0 License — see the [LICENSE](LICENSE) file for details.

---

<div align="center">

**NOVA Framework** — Made with care for the FiveM community.

[Documentation](https://novaframeworkdoc.gitbook.io/novaframework/) · [Discord](https://discord.gg/novaframeworkofc) · [GitHub](https://github.com/NoVaPTdev)

</div>

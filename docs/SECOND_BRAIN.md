# Local project knowledge

Graphify (`graphifyy` on PyPI) is installed as an isolated uv tool. Its Codex skill is registered in the user's Codex skills directory. Obsidian is installed for the Windows user account from the official Windows release via Windows Package Manager.

The local vault is `.private/second-brain/vault/`. Open that folder as an Obsidian vault and start with `START HERE.md`. It contains curated project decisions and Graphify's linked code notes and canvas. It is excluded from Git and game exports. No Sync subscription, cloud indexing or external model key is configured for this setup.

The first Graphify scan covers production tools using local AST extraction. GDScript is not listed among this installed Graphify version's structural parsers, so the Godot runtime is documented in curated architecture notes rather than claimed as an automatically parsed call graph. Graphify also reports limited symbol coverage for the top-level PowerShell scripts.

Refresh the tools index from the project root:

```powershell
graphify extract tools --code-only --max-workers 2 --out .private/second-brain
graphify cluster-only .private/second-brain --no-label
graphify export obsidian --graph .private/second-brain/graphify-out/graph.json --dir .private/second-brain/vault
graphify query "generate" --graph .private/second-brain/graphify-out/graph.json --budget 600
```

The exporter preserves custom notes. Review generated information before relying on it, and keep the current design notes up to date after user changes.

Sources: [Graphify installation](https://docs.graphify.com/open-source/installation), [local code-only extraction](https://docs.graphify.com/open-source/cli-quickstart), [Obsidian export](https://docs.graphify.com/open-source/features/exports), [Obsidian installation](https://obsidian.md/help/install).

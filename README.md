# Replicant Network

![logo](./assets/logo_small.png)

Replicant Network is a decentralized local AI inference network. You can download the desktop app or use the CLI to earn credits for serving requests routed to you from an OpenAI-compatible API. These credits are used to make requests and to the same API for inference and for prioritization in the request queue. Join the [Discord](https://discord.gg/yvWPVCS7NH) server or read the [TLDR](https://replicantzk.com/about/tldr) on the [site](https://replicantzk.com) to learn more.

## Components

```bash
.
├── apps # App components
│   ├── chat # Gradio ChatInterface demo
│   ├── platform # Main backend
│   ├── worker_app # Worker desktop application
│   ├── worker_cli # Worker command line application
│   └── worker_sdk # Shared JS code for worker applications
├── assets # Static assets
├── nbs # Elixir and Python notebooks
├── sh # Shell scripts
└── vendor # Git submodules 
    └── 
```

## Developing

### Requirements

- [docker](https://docs.docker.com/engine/install)
- [docker compose](https://docs.docker.com/compose/install)
- [mise](https://mise.jdx.dev/getting-started.html)
- [k6](https://k6.io/docs/get-started/installation/)

### Setup

- `cp .env_ .env`
- `mise trust`
- `mise install`

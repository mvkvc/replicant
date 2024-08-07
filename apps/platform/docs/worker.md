# Worker

Here is the recommended way to get started as a worker.

## Setup

- Install [Ollama](https://ollama.com/download) and have it running on your machine.
  - Follow the instructions [here](https://github.com/ollama/ollama/blob/main/docs/faq.md#how-can-i-allow-additional-web-origins-to-access-ollama) to add `tauri://*` to the `OLLAMA_ORIGINS` environment variable (ex. `OLLAMA_ORIGINS="tauri://*"`) to allow the app to access your local OLLAMA server.
- Create an account on the platform [here](https://platform.replicantzk.com/users/register).
- Generate an API key [here](https://platform.replicantzk.com/users/settings).
- Join the Discord server (see header) to request the minimum credits to be able to serve requests.
  - We require this currently otherwise people will spin up endless numbers of small workers and lie about which model they are running in order to farm credits. 
  - Components to make this permisionless to join are in development.
- Download the latest worker release from the [homepage](/).
- Start the app.
- Navigate to the `Settings` page.
  - Set the `API Key` field to the key generated earlier.
  - Set the `API URL` field to `https://platform.replicantzk.com/v1`.
  - Set the `LLM URL` field to `http://localhost:11434` (or whatever port you have set in Ollama).
- Navigate to the `Models` page.
  - Here you can manage supported models locally.
  - Download the model you want to run and select `Serve` once it is available.
- Navigate to the `Worker` page.
  - Here you can start and stop the worker and see the logs as requests are routed to you.

## Advanced

### Docker

If you prefer to use Docker, we provide an image that can be started with the following command:

```bash
docker run --rm -it \
    --gpus all \
    --mount type=bind,source="$(pwd)"/.models,target=/app/.models \
    --env WORKER_MODEL="$WORKER_MODEL" \
    --env WORKER_API_KEY="$WORKER_API_KEY" \
    ghcr.io/replicantzk/worker:latest
```

Ensure that you have at least the `WORKER_MODEL` and `WORKER_API_KEY` environment variables set. To save time redownloading models, you should always mount the same directory (in this example, `$(pwd)/.models`) to the container as shown above.

# Helm Chia Nodes

Deploy Chia full nodes into Kubernetes with a Docker image + Helm chart workflow.

## What this repo contains

- Docker image build for a Chia node (`Dockerfile`, `docker_build.sh`)
- Runtime startup and health logic (`docker-entrypoint.sh`, `docker-start.sh`, `docker-healthcheck.sh`)
- Helm chart and helper scripts for deploy/diff/update (`helm/`)

## Prerequisites

- Docker with `buildx`
- Kubernetes cluster + `kubectl` context configured
- Helm 3
- `helm-diff` plugin (required by `helm/diff.sh`)
- StorageClass suitable for node DB volumes

## Quickstart

1. Clone the repo.
2. Build and push image:

```bash
DOCKER_REPO="docker.repo.com/library/path" ./docker_build.sh
```

3. Create an environment-specific values file in `helm/chia-node/`, for example:
   - `values-my-mainnet.yaml`
   - `values-my-testnet.yaml`

4. In that file, override at least:
   - `chia-blockchain.nameOverride`
   - `chia-blockchain.fullnameOverride`
   - `chia-blockchain.chia.ca.private_ca_crt`
   - `chia-blockchain.chia.ca.private_ca_key`
   - `chia-blockchain.image.repository`
   - `chia-blockchain.image.tag`

5. `cd helm`

6. Select env file and update chart dependencies:

Mainnet:
```bash
CI_ENVIRONMENT=<mainnet-values-suffix> ENV_FILE=./env ./update-chart.sh
```

Testnet:
```bash
CI_ENVIRONMENT=<testnet-values-suffix> ENV_FILE=./env_testnet ./update-chart.sh
```

7. Check Helm diff:

Mainnet:
```bash
CI_ENVIRONMENT=<mainnet-values-suffix> ENV_FILE=./env ./diff.sh
```

Testnet:
```bash
CI_ENVIRONMENT=<testnet-values-suffix> ENV_FILE=./env_testnet ./diff.sh
```

8. Deploy:

Mainnet:
```bash
CI_ENVIRONMENT=<mainnet-values-suffix> ENV_FILE=./env ./upgrade.sh
```

Testnet:
```bash
CI_ENVIRONMENT=<testnet-values-suffix> ENV_FILE=./env_testnet ./upgrade.sh
```

9. Verify rollout in Kubernetes.

## How startup works

Container startup is:

1. `docker-entrypoint.sh`
   - Sets timezone (`TZ`) if provided.
   - Activates Chia virtualenv.
   - Runs `chia init --fix-ssl-permissions`.
   - If `ca` is set, runs `chia init -c <ca>` (in chart this is `/chia-ca` when private CA values are provided).
   - Applies network/testnet/log/upnp/crawler settings.
   - Optionally restores a DB checkpoint (see below).
   - Updates `config.yaml` fields (`self_hostname`, log stdout behavior, log level).
   - Executes command (`docker-start.sh`).

2. `docker-start.sh`
   - Runs `chia start <service>`.
   - Traps `SIGINT`/`SIGTERM` to stop services cleanly.
   - Tails Chia log when `log_to_file=true`; otherwise container stays alive with `tail -F /dev/null`.

## How healthcheck works

`docker-healthcheck.sh` runs for Docker `HEALTHCHECK` and Kubernetes `startupProbe`, `readinessProbe`, and `livenessProbe`.

- If `healthcheck != true`, script exits success.
- It always checks daemon port `55400` with `nc`.
- Depending on `service`, it checks specific Chia RPC `healthz` endpoints via mutual TLS:
  - Node: `https://localhost:8555/healthz`
  - Farmer: `https://localhost:8559/healthz`
  - Harvester: `https://localhost:8560/healthz`
  - Wallet: `https://localhost:9256/healthz`
- It retries around transient failures.
- During checkpoint restore (`aria2c`/`tar` running), failures are tolerated to avoid restart loops.

## Faster sync via DB checkpoints

The image defaults `use_checkpoint=true`.

On startup, entrypoint checks existing DB size in `${CHIA_ROOT}/db`:
- Mainnet DB target: `blockchain_v2_mainnet.sqlite`
- Testnet DB target: `blockchain_v2_testnet11.sqlite`

If DB is considered too small, it downloads a prebuilt compressed DB snapshot torrent from `torrents.chia.net`, extracts it into `${CHIA_ROOT}/db`, and starts from that checkpoint instead of syncing from genesis. This significantly reduces initial sync time.

## Values and env wiring

- Base chart values: `helm/chia-node/values.yaml`
- Per-environment overrides are expected by scripts as:
  - `helm/chia-node/values-$CI_ENVIRONMENT.yaml`
- Deploy scripts load variables from `helm/env` or `helm/env_testnet`:
  - `SERVICE_NAME`
  - `VALUES_PATH`
  - `CI_NAMESPACE`
  - `CI_ENVIRONMENT` (needed by `diff.sh`/`upgrade.sh`)

## Troubleshooting tips

- If `diff.sh`/`upgrade.sh` fail on missing values file, ensure `CI_ENVIRONMENT` matches your override filename suffix (for example `values-aws-mainnet.yaml` => `CI_ENVIRONMENT=aws-mainnet`).
- If pods restart during bring-up, inspect logs for CA/config issues and verify your private CA cert/key are valid and correctly indented YAML block scalars.

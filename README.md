# Poker

A real-time multiplayer poker application built with Elixir and Phoenix LiveView, using Event Sourcing for core game logic.

## Stack

- **Elixir / Phoenix LiveView** — real-time UI
- **Event Sourcing** (Commanded) — poker table logic
- **PostgreSQL** — projections
- **Grafana Cloud** — observability (traces via Tempo, logs via Loki)
- **Grafana Alloy** — telemetry collector (OTLP receiver, log shipper)

## Prerequisites

Install runtime versions via [asdf](https://asdf-vm.com/) or [mise](https://mise.jdx.dev/) — versions are defined in `.tool-versions`:

```bash
# asdf
asdf install

# mise
mise install
```

- [direnv](https://direnv.net/) (optional, for `.envrc` auto-loading)

## Setup

```bash
cp .envrc.example .envrc
# fill in GCLOUD_RW_API_KEY, GRAFANA_* values
```

```bash
mix setup
```

## Running

**App:**
```bash
mix phx.server
```

**Monitoring (Alloy → Grafana Cloud):**
```bash
docker compose -f docker-compose.monitoring.yml up -d
```

App will be available at [localhost:4000](http://localhost:4000).

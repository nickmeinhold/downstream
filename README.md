# Plex

**What's new on streaming? Download it with one click.**

A self-hosted web app for discovering new content across Netflix, Disney+, Apple TV+, and more. See what dropped this week, check the ratings, and grab it via torrent — all in one place.

```text
┌─────────────────────────────────────────────────────────────────┐
│  PLEX                                         nick ▼   ⬇ 2     │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐   │
│  │ ███████ │ │ ███████ │ │ ███████ │ │ ███████ │ │ ███████ │   │
│  │ ███████ │ │ ███████ │ │ ███████ │ │ ███████ │ │ ███████ │   │
│  │ ███████ │ │ ███████ │ │ ███████ │ │ ███████ │ │ ███████ │   │
│  │ ███████ │ │ ███████ │ │ ███████ │ │ ███████ │ │ ███████ │   │
│  │ Arcane  │ │ Dune 2  │ │ Shogun  │ │ Ripley  │ │ 3 Body  │   │
│  │ ★ 9.1   │ │ ★ 8.8   │ │ ★ 8.7   │ │ ★ 8.3   │ │ ★ 8.0   │   │
│  └─────────┘ └─────────┘ └─────────┘ └─────────┘ └─────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Features

- **Browse new releases** from Netflix, Disney+, Apple TV+, HBO Max, Prime Video, Paramount+, Hulu, Peacock
- **Aggregate ratings** — IMDB, Rotten Tomatoes, Metacritic all in one view
- **Multi-user** — everyone tracks their own watch history
- **One-click downloads** — search torrents via Jackett, download via Transmission
- **Real-time progress** — watch your downloads complete

## Architecture

```text
┌──────────────────────────────────────────────────────────────────┐
│                      Flutter Web Frontend                         │
│         Browse • Search • Mark Watched • Download                 │
└────────────────────────────┬─────────────────────────────────────┘
                             │ REST API
┌────────────────────────────▼─────────────────────────────────────┐
│                       Dart Backend (shelf)                        │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────────────────┐ │
│  │   Auth   │ │   TMDB   │ │  Jackett │ │    Transmission      │ │
│  │  (JWT)   │ │  Client  │ │  Client  │ │       Client         │ │
│  └──────────┘ └──────────┘ └──────────┘ └──────────────────────┘ │
└───────┬──────────────┬──────────────┬──────────────┬─────────────┘
        │              │              │              │
        ▼              ▼              ▼              ▼
   [Users JSON]   [TMDB API]    [Jackett]    [Transmission]
                  [OMDB API]    :9117           :9091
```

## Quick Start

### 1. Get API Keys

| Service | Purpose | Link |
|---------|---------|------|
| **TMDB** | Content data & posters | [Get free key](https://www.themoviedb.org/settings/api) |
| **OMDB** | IMDB/RT/Metacritic ratings | [Get free key](https://www.omdbapi.com/apikey.aspx) |

### 2. Install Dependencies

**macOS:**

```bash
brew install transmission jackett
brew services start transmission
brew services start jackett
```

**Docker:**

```bash
docker run -d --name transmission -p 9091:9091 -v ~/Downloads:/downloads linuxserver/transmission
docker run -d --name jackett -p 9117:9117 linuxserver/jackett
```

Then configure your torrent indexers at <http://localhost:9117>

### 3. Configure Environment

```bash
# Required
export TMDB_API_KEY="your-tmdb-key"

# Recommended
export OMDB_API_KEY="your-omdb-key"              # For ratings
export JACKETT_URL="http://localhost:9117"
export JACKETT_API_KEY="from-jackett-ui"         # Top right corner in Jackett

# Optional
export TRANSMISSION_URL="http://localhost:9091"  # Default
export JWT_SECRET="your-random-secret"           # For auth tokens
export PORT="8080"                               # Default
```

### 4. Build & Run

```bash
# Backend
dart pub get

# Frontend
cd frontend && flutter pub get && flutter build web && cd ..

# Start
dart run bin/server.dart
```

Open <http://localhost:8080> — create an account and start browsing.

---

## CLI Mode

Prefer the terminal? The original CLI still works:

```bash
dart pub global activate --source path .

plex new                        # New releases (last 30 days)
plex new -p netflix -p disney   # Filter by provider
plex trending                   # What's hot this week
plex search "severance"         # Find something specific
plex where "The Bear"           # Where is it streaming?
```

---

## API Reference

### Auth

```http
POST /api/auth/register    { username, password }  →  { token, user }
POST /api/auth/login       { username, password }  →  { token, user }
GET  /api/auth/me          [Bearer token]          →  { user }
```

### Content Discovery

```http
GET /api/new?providers=netflix,disney&type=movie&days=30
GET /api/trending?window=week&type=tv
GET /api/search?q=breaking+bad
GET /api/where?q=the+bear
GET /api/ratings/{movie|tv}/{tmdb_id}
GET /api/providers
```

### Watch History

```http
GET    /api/watched
POST   /api/watched/{movie|tv}/{id}
DELETE /api/watched/{movie|tv}/{id}
```

### Torrents

```http
GET    /api/torrents/search?q=dune+2024&category=movie
POST   /api/torrents/download    { url: "magnet:..." }
GET    /api/torrents/active
DELETE /api/torrents/{id}?deleteData=true
```

---

## Supported Providers

| Key | Provider |
|-----|----------|
| `netflix` | Netflix |
| `disney` | Disney+ |
| `apple` | Apple TV+ |
| `hbo` | Max (HBO) |
| `prime` | Prime Video |
| `paramount` | Paramount+ |
| `hulu` | Hulu |
| `peacock` | Peacock |

---

## Data Storage

All data is stored locally:

```text
~/.plex_users.json     # Accounts (passwords are hashed)
~/.plex_watched.json   # Per-user watch history
```

---

## Tech Stack

| Layer | Tech |
|-------|------|
| Frontend | Flutter Web |
| Backend | Dart + shelf |
| Auth | JWT (dart_jsonwebtoken) |
| Content | TMDB API |
| Ratings | OMDB API |
| Torrents | Jackett + Transmission |

---

## Troubleshooting

**"Jackett not configured"**
→ Set both `JACKETT_URL` and `JACKETT_API_KEY`

**"OMDB not configured"**
→ Set `OMDB_API_KEY` for ratings (optional but recommended)

**"Transmission connection failed"**
→ Make sure Transmission is running and RPC is enabled (port 9091)

**No torrents found**
→ Add indexers in Jackett UI at <http://localhost:9117>

---

## License

MIT

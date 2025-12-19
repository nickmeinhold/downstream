# Downstream

**What's new on streaming?**

A self-hosted web app for discovering new content across Netflix, Disney+, Apple TV+, and more. See what dropped this week, check the ratings, track what you've watched, and request content for download.

Pairs with [downstream-cli](https://github.com/nickmeinhold/downstream-cli) for automated downloading.

```text
┌─────────────────────────────────────────────────────────────────┐
│  DOWNSTREAM                                   nick ▼            │
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
- **Multi-user** — everyone tracks their own watch history via Firebase Auth
- **Where to watch** — see which streaming services have a title
- **Request content** — request movies/shows for download (processed by downstream-cli)

## Architecture

```mermaid
flowchart TB
    subgraph Frontend["Flutter Web Frontend"]
        UI["Browse • Search • Mark Watched • Request"]
    end

    subgraph Backend["Dart Backend (shelf)"]
        Auth["Firebase Auth"]
        TMDB["TMDB Client"]
        OMDB["OMDB Client"]
        FS["Firestore Client"]
    end

    subgraph External["External Services"]
        TMDB_API["TMDB API"]
        OMDB_API["OMDB API"]
        Firebase["Firebase / Firestore"]
    end

    UI -->|REST API| Backend
    Auth --> Firebase
    TMDB --> TMDB_API
    OMDB --> OMDB_API
    FS --> Firebase
```

## Sequence Diagram

The following diagram shows the flow when a user opens the web app, authenticates, browses content, and interacts with various APIs:

```mermaid
sequenceDiagram
    participant B as Browser
    participant F as Flutter Frontend
    participant S as Dart Backend
    participant FB as Firebase
    participant T as TMDB API
    participant O as OMDB API

    Note over B,O: App Initialization & Authentication

    B->>F: 1. Open app
    F->>B: 2. Load WASM bundle
    F->>FB: 3. Initialize Firebase Auth
    FB-->>F: 4. Check existing session
    F->>B: 5. Show login screen

    B->>F: 6. Click "Sign in with Google"
    F->>FB: 7. Google OAuth popup
    B->>FB: 8. Complete OAuth flow
    FB-->>F: 9. Return JWT token
    F->>B: 10. Show home screen

    Note over B,O: Fetching New Releases

    F->>S: 11. GET /api/new (Bearer token)
    S->>FB: 12. Verify JWT token
    FB-->>S: Token valid, return user ID
    S->>FB: 13. Get user's watched items (Firestore)
    FB-->>S: Return watched list
    S->>T: 14. Discover movies & TV shows
    T-->>S: Return media results
    S-->>F: 15. Return media list with watched status
    F->>B: 16. Render media grid

    Note over B,O: Viewing Media Details

    B->>F: 17. Click media card
    F->>S: 18. GET /api/ratings/{type}/{id}
    S->>T: 19. Get IMDB ID (external_ids)
    T-->>S: Return IMDB ID
    S->>O: 20. Fetch ratings by IMDB ID
    O-->>S: Return IMDB/RT/Metacritic scores
    S->>T: 21. Get streaming providers
    T-->>S: Return provider list
    S-->>F: 22. Return ratings + providers
    F->>B: 23. Show detail dialog

    Note over B,O: Marking Watch History

    B->>F: 24. Click "Mark as Watched"
    F->>S: 25. POST /api/watched/{type}/{id}
    S->>FB: 26. Write to Firestore
    FB-->>S: Document created
    S-->>F: 27. 200 OK
    F->>B: 28. Update UI with watched badge
```

**Key flows:**

| Step | Description |
| ------ | ------------- |
| 1-10 | App loads, user authenticates via Google OAuth, receives JWT token |
| 11-16 | Home screen fetches new releases from TMDB, marks user's watched items |
| 17-23 | User clicks card, backend fetches ratings from OMDB + providers from TMDB |
| 24-28 | User marks item watched, stored in Firestore under their user ID |

## Quick Start

### 1. Get API Keys

| Service | Purpose | Link |
| --------- | --------- | ------ |
| **TMDB** | Content data & posters | [Get free key](https://www.themoviedb.org/settings/api) |
| **OMDB** | IMDB/RT/Metacritic ratings | [Get free key](https://www.omdbapi.com/apikey.aspx) |
| **Firebase** | Auth & Firestore | [Firebase Console](https://console.firebase.google.com) |

### 2. Configure Environment

```bash
# Required
export TMDB_API_KEY="your-tmdb-key"
export FIREBASE_PROJECT_ID="your-project-id"
export FIREBASE_SERVICE_ACCOUNT='{"type":"service_account",...}'

# Recommended
export OMDB_API_KEY="your-omdb-key"  # For ratings

# Optional
export PORT="8080"  # Default
```

### 3. Build & Run

```bash
# Server
cd server && dart pub get && cd ..

# Frontend
cd frontend && flutter pub get && flutter build web --wasm && cd ..

# Start server (serves frontend automatically)
cd server && dart run bin/server.dart
```

Open <http://localhost:8080> — sign in with Google and start browsing.

---

## API Reference

### Auth

```http
GET  /api/auth/me    [Bearer token]  →  { user }
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

### Content Requests

```http
GET    /api/requests
POST   /api/requests/{movie|tv}/{id}    { title, posterPath? }
DELETE /api/requests/{movie|tv}/{id}
```

---

## Supported Providers

| Key | Provider |
| ----- | ---------- |
| `netflix` | Netflix |
| `disney` | Disney+ |
| `apple` | Apple TV+ |
| `hbo` | Max (HBO) |
| `prime` | Prime Video |
| `paramount` | Paramount+ |
| `hulu` | Hulu |
| `peacock` | Peacock |

---

## Project Structure

```text
downstream/
├── server/           # Dart backend
│   ├── bin/server.dart
│   ├── lib/src/
│   │   ├── server/   # HTTP routes
│   │   ├── services/ # API clients
│   │   └── ...
│   └── pubspec.yaml
├── frontend/         # Flutter web app
│   ├── lib/
│   │   ├── screens/
│   │   ├── widgets/
│   │   └── services/
│   └── pubspec.yaml
└── README.md
```

---

## Tech Stack

| Layer | Tech |
| ------- | ------ |
| Frontend | Flutter Web (WASM) |
| Backend | Dart + shelf |
| Auth | Firebase Auth (Google Sign-In) |
| Database | Cloud Firestore |
| Content | TMDB API |
| Ratings | OMDB API |

---

## Troubleshooting

**"OMDB not configured"**
→ Set `OMDB_API_KEY` for ratings (optional but recommended)

**"Firebase auth failed"**
→ Check `FIREBASE_PROJECT_ID` and `FIREBASE_SERVICE_ACCOUNT` are set correctly

---

## License

MIT

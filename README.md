# ShamarrConnect

A self-hosted remote desktop product — install it on your own server and give your users a branded TeamViewer-style experience. Built on the [RustDesk](https://github.com/rustdesk/rustdesk) open-source remote desktop engine.

**Website:** [shamarrconnect.com](https://shamarrconnect.com)  
**API backend:** [shamarrzz/shamarrconnect-cloud](https://github.com/shamarrzz/shamarrconnect-cloud)

---

## What this repo is

This is the **desktop client** — the app your users download and run. It is a custom-branded fork of the RustDesk client (Rust core + Flutter UI).

```
shamarrconnect/          ← this repo — desktop client (Windows / Linux / macOS)
shamarrconnect-cloud/    ← API backend (login, address book, heartbeat)
sc-server/               ← RustDesk relay/rendezvous (on the server)
sc-website/              ← Marketing website (Cloudflare Pages)
```

---

## System architecture

```
User's device                     Your server
┌─────────────────┐               ┌──────────────────────────────┐
│  ShamarrConnect │   HTTPS 443   │  Caddy (reverse proxy / TLS) │
│  desktop client │ ────────────▶ │  api.shamarrconnect.com      │
│                 │               │        │                      │
│  Stores:        │               │        ▼                      │
│  • access_token │               │  shamarrconnect-cloud        │
│  • address book │               │  (Rust/Axum API + SQLite)    │
└────────┬────────┘               └──────────────────────────────┘
         │
         │  tcp/udp 21115-21119          ┌─────────────────┐
         └─────────────────────────────▶ │  sc-server      │
                                         │  hbbs (relay)   │
         ◀──── peer-to-peer tunnel ────▶ │  hbbr (relay)   │
                                         └─────────────────┘
```

The client:
1. Authenticates via `api.shamarrconnect.com` (sc-cloud) on login
2. Registers its ID with the rendezvous server (`connect.shamarrconnect.com`)
3. Establishes peer-to-peer tunnels through the relay server for remote sessions

---

## Repo structure

```
shamarrconnect/
├── src/               # Rust core — connection, protocol, platform
│   ├── hbbs_http/     # API client (login, heartbeat, address book)
│   │   ├── account.rs # Login flow, token storage
│   │   └── sync.rs    # Heartbeat loop (every 15 s)
│   ├── server/        # Audio / clipboard / input / video capture
│   ├── platform/      # Platform-specific code
│   └── lang/          # Localisation strings
├── flutter/           # Flutter UI
│   ├── lib/desktop/   # Desktop UI
│   ├── lib/mobile/    # Mobile UI
│   └── lib/common/    # Shared widgets / models
├── libs/
│   ├── hbb_common/    # Config, proto, shared utils (git submodule)
│   ├── scrap/         # Screen capture
│   └── enigo/         # Input simulation
├── res/               # Icons, MSI resources, desktop files
└── .github/workflows/ # CI / build pipelines
```

---

## How the client authenticates

On login the client calls `POST /api/login` with `username` + `password`.  
The server returns an `access_token` (JWT). The client stores it in `LocalConfig` and sends it as `Authorization: Bearer <token>` on all subsequent API calls (address book, current user).

The heartbeat (`POST /api/heartbeat`) runs every 15 seconds and does **not** require the token — it identifies the device by `id` and `uuid`. This means:

- **Changing a user's account password does not disconnect running sessions** — the device token in the server's database is completely separate from the password.
- A user can explicitly sign out all devices from their account settings.

---

## Building the Windows client

> Windows builds are produced on the Windows development machine.  
> CI builds via GitHub Actions will be added as the project matures.

**Prerequisites (Windows):**
- Rust stable (`rustup`)
- Flutter 3.24.x
- [vcpkg](https://vcpkg.io) with the packages listed in `vcpkg.json`
- LLVM / Clang (for the Rust FFI bindings)

**Build:**
```powershell
# Clone with submodule
git clone --recursive git@github.com:shamarrzz/shamarrconnect.git
cd shamarrconnect

# Build Flutter assets first
cd flutter && flutter pub get && cd ..

# Build the Rust binary
cargo build --release

# Package (MSI / portable exe)
python build.py --portable   # or --msi for installer
```

The build script (`build.py`) handles branding, icon injection, and packaging.

---

## Pointing the client at your server

The client reads its server addresses from `libs/hbb_common/src/config.rs`.  
For a custom-branded build the relevant constants are:

| Config key | Value |
|------------|-------|
| `api-server` | `https://api.shamarrconnect.com` |
| `custom-rendezvous-server` | `connect.shamarrconnect.com` |

These are baked in at build time via the branding configuration. End users connect automatically with no manual setup.

---

## Development

### Rust side (logic / protocol)

```bash
git clone --recursive git@github.com:shamarrzz/shamarrconnect.git
cd shamarrconnect
cargo build   # builds the core library
cargo test
```

### Flutter side (UI)

```bash
cd flutter
flutter pub get
flutter run -d linux   # or -d windows on Windows
```

### Running against a local backend

Set the API server and rendezvous server in the client config to point at `localhost` for local development. See `libs/hbb_common/src/config.rs` for the option keys.

---

## Editing guidelines

See [AGENTS.md](AGENTS.md) for the full coding standards. Key rules:

- **Smallest valid diff** — change only what is required.
- **No `unwrap()` / `expect()`** in production code — use `?` or explicit handling.
- **No nested Tokio runtimes** — never call `block_on` inside async code.
- **Localization** — all user-visible strings go through `src/lang/`. See AGENTS.md for the translation workflow.

---

## Related repositories

| Repo | Purpose |
|------|---------|
| [shamarrzz/shamarrconnect-cloud](https://github.com/shamarrzz/shamarrconnect-cloud) | API backend (Rust/Axum) |
| [rustdesk/rustdesk-server](https://github.com/rustdesk/rustdesk-server) | Relay/rendezvous server (used as-is) |
| [rustdesk/hbb_common](https://github.com/rustdesk/hbb_common) | Shared proto/config library (submodule) |

---

## Licence

This project is a fork of [RustDesk](https://github.com/rustdesk/rustdesk) and is distributed under the same AGPL-3.0 licence. See [LICENCE](LICENCE).

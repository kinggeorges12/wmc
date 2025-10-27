# WMC - Windowing Media Collector

A complete home media server solution for PC. Stream your library to any device—phone, tablet, or TV—from anywhere with internet. Think of it as *flix, but with your own content.

**Capabilities:**
- 📱 Stream your media to any device, anywhere
- 🎬 Automate downloads and library organization
- 🔒 Keep everything private on your own server
- 💰 Use open-source software with no subscription fees

Windowing Media Collector (WMC) is the configuration and automation layer that makes it all work. Every app below can be containerized, and I highly recommend it.

## Quick Start

**For a complete setup, follow these directories in order:**

1. **[Docker Setup](docker-setup/README.md)** - Start here. Sets up all the Docker containers
2. **[PC Tasks](pc-tasks/README.md)** - PowerShell scripts for library automation
3. **[Nginx Router](nginx-router/README.md)** - Optional: Reverse proxy and SSL for remote access
4. **[Jellyfin Plugins](jellyfin-plugins/README.md)** - Enhance your media server

**Prerequisites:**
- Docker Desktop installed
- PowerShell 7+ (or 5.1 minimum)
- Admin access to configure port forwarding
- 8GB+ RAM recommended
- Multiple drives recommended (C: for apps, E: for media)

**Typical Setup Time:** Too damn long.

# Architecture
You can be sure that every arrow in this graph has at least one App configuration or WMC script.

**Quick Reference:**
- How to watch: Jellyfin Client > DDNS > Router > Nginx > Jellyfin Server
- Manage media: Jellyfin Server > JellyBridge > Jellyseerr > Radarr & Sonarr > Jellyfin Server
- New media requests: Jellyseerr > Qbit > Jackett > Georznab > Radarr & Sonarr > WMC

## System Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                        WATCH FLOW (Viewing)                         │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│   Jellyfin Client → DDNS → Router → Nginx → Jellyfin Server         │
│   (Mobile/Device)         (GLiNet)  (Reverse Proxy)                 │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│                     MANAGE FLOW (Organization)                      │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│   Jellyfin Server ────┐                                             │
│                       ├──→ JellyBridge* → Jellyseerr                │
│                       │                    ↓                        │
│                       │              Radarr/Sonarr                  │
│                       │                    ↑                        │
│                       └──────────→ Jellyfin Server (again)          │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│                    REQUEST FLOW (New Content)                       │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│   Jellyseerr → Qbit → Jackett → Georznab → Radarr/Sonarr            │
│                    ↓                                  ↓             │
│                 Downloads                        WMC Tasks          │
│                    ↓                                  ↓             │
│                 Radarr/Sonarr               (Hardlinks/Import)      │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

**Legend:**
- **Watch Flow**: Users access media through Jellyfin clients
- **Manage Flow**: Media library organization via Arr apps
- **Request Flow**: Automated download and processing of new media

*Note: Use JellyBridge plugin or the CustomTabs/Jellyseerr-Nginx implementation, but hey you know you want to use my Jellyfin plugin.

# Apps
Everything below "Router" in this list can be a container, and boy do I recommend it.
- **Jellyfin Client**: Mobile apps like [Jellyfin for Android](https://jellyfin.org/docs/general/clients/mobile/android/) and TV clients to connect to your media server.
- **DDNS**: Dynamic Domain Name System. What? This is how your client finds your server. See [DuckDNS](https://www.duckdns.org/) or [No-IP](https://www.noip.com/) for free DDNS services. Or better yet, get a [GLiNet router](https://www.gl-inet.com/) with built-in free DDNS.
- **Router**: *CAN* be anything, but [GLiNet](https://www.gl-inet.com/) comes with free, integrated DDNS and makes port forwarding a breeze. For SSL setup, you'll need to temporarily forward ports 80 and 443 to your server.
- **Nginx**: A not-so-simple-yet-powerful reverse proxy. This protects your server from malicious internet bots. Don't leave home without it. [Nginx documentation](https://nginx.org/en/docs/).
- **Jellyfin Server**: Why is it called Jellyfin? The name might be an amalgamation, just like what this app does. Combines media library into a beautiful collection along with metadata. This is how you manage clients, but cooler features include intro skipping, user requests, and subtitle downloading. Integrates into your bunny-ears antenna to DVR broadcasts; we're back in the '00s and mom taped over my reruns of Seinfeld with Desperate Housewives. [Jellyfin](https://jellyfin.org/).
- **JellyBridge**: A pet project of mine that syncs discover content from Jellyseerr to Jellyfin, and syncs favorited media from Jellyfin to Jellyseerr. [JellyBridge GitHub](https://github.com/kinggeorges12/JellyBridge)
- **Jellyseerr**: Discover new content just like the 'flix does! Fully integrates with all your media collectors: Radarr, Sonarr, and Jellyfin. [Jellyseerr documentation](https://docs.jellyseerr.dev/).
- **Radarr**: Y-Arr matey! Get your 'arr on with the easy to use movie manager. Automatically renames movie files based on databases like TVDB and TMDB. [Radarr wiki](https://wiki.servarr.com/radarr).
- **Sonarr**: Arr you kidding me? This thing has an import wizard to fix those pesky TV show filenames. Same renaming ability as Radarr, but an additional utility of tracking when episodes are released for your favorite shows. [Sonarr wiki](https://wiki.servarr.com/sonarr).
- **Docker/Portainer/Dockge**: Well you definitely need [Docker Desktop](https://www.docker.com/products/docker-desktop), but the others you can manage without. You will have to learn the basic commands for building containers. And I'm sure ChatGPT can manage the translation if you want to build these in Podman or whatnot. Just know that I used a lot of escape characters that are specific to [Portainer](https://www.portainer.io/), I probably created a huge mess for you. [Dockge](https://github.com/louislam/dockge) is an alternative.
- **Qbit** (qBittorrent): You can use anything you like to download, as long as it's Qbit. Yeah, 'nuff said. [qBittorrent](https://www.qbittorrent.org/).
- **Georznab**: This is a python app that produces torznab-like files for consumption by Radarr and Sonarr. This requires the WMC tasks to begin the torznab creation, which searches Qbit for the requested media. [Georznab source code](docker-setup/docker/Georznab/) in this repository.
- **Jackett**: Manage Qbit searches across download providers. Not necessary, but it gets a lot more results than vanilla Qbit. [Jackett](https://github.com/Jackett/Jackett).

# Hardware
Basic architecture is one large drive for storing media, and one smaller-but-faster drive for storing program data. You can also use a dedicated drive for downloading with Qbit, cause you don't want to wreck your storage or OS drive.

**Recommended Drive Configuration (examples, customize to your setup):**
- Drive C: PowerShell scripts and app configuration files for Docker containers (e.g., `C:\Docker\`)
- Drive D: Downloads and temporary files (e.g., `D:\Docker\qbit\`)
- Drive E: Long-term storage and media collection (e.g., `E:\Downloads\`)

## Project Folder Structure
```
wmc/
├── docker-setup/          # Docker Compose files and container configs
│   ├── docker/            # Custom apps
│   │   ├── Georznab/      # Torznab indexer (Python app)
│   │   ├── Gluetun/       # VPN authentication config
│   │   └── Jellyseerr/    # Nginx proxy and user management
│   └── docker-compose-*.yml
├── pc-tasks/              # PowerShell automation scripts
│   ├── *.ps1              # Library management scripts
│   ├── *.json             # API configuration files
│   └── Library *.xml      # PC Task Scheduler configs
├── nginx-router/           # Nginx reverse proxy for router/SSL
├── jellyfin-plugins/      # Jellyfin CustomTabs HTML
└── README.md              # This file
```

**Important PC Paths (configure in docker-compose files - replace with your actual paths):**
- `C:\Docker\[App]\` - Application config directories (Jellyfin, Radarr, Sonarr, etc.)
- `C:\Tasks\` - PowerShell task scripts location
- `C:\Docker\qBittorrent\` - qBittorrent configuration
- `D:\Docker\qBittorrent\` - Download directories
- `E:\Downloads\Sync\` - Final media library (read-only for containers)
- `E:\Downloads\Library\` - Source downloads (hardlinks created here)

These are example paths. Update all references to match your system.

I love the architecture and packages on Nvidia, so my configurations may reflect that. This setup can work on various hardware configurations, from Raspberry Pi to high-end workstations.

# WMC
Windowing Media Collector (WMC) is this page! OK, I have other configurations and tips for completing all these connections in the architecture. YES, all "tasks" scripts below are written in PowerShell! I don't know whether I should be celebrating or seeing a psychiatrist.
- [Docker Setup](docker-setup/README.md): For building the containers. Yes, you can use DOCKERFILEs, but I wanted to maintain this in a 3rd party container tool; hate me. The [Docker folder](docker-setup/docker) contains [Georznab](docker-setup/docker/Georznab/) python app, [Gluetun](docker-setup/docker/Gluetun/) configuration, and [Jellyseerr nginx proxy and user management](docker-setup/docker/Jellyseerr/) to integrate Jellyseerr with Custom Tabs plugin for Jellyfin.
- [PC tasks](pc-tasks/README.md): The main purpose is to maintain Qbit download files while organizing a copy in your media library. This is no small task. PC makes it a pain in the patooty to manage hardlinks; from reserved characters to path limitations. I would rather build it right once than ever do that again. The other tasks are related to media and import files into your collections in Sonarr and Radarr.
- [Nginx Router](nginx-router/README.md): The reverse proxy that sits in front of everything for SSL and remote access. You thought server configuration would be easier than Apache, but it's so much harder. I have the templates for Docker and a dedicated Linux ARM.
- [Jellyfin plugins](jellyfin-plugins/README.md): Make your user experience better with some helpful extensions.

Basically, it ain't basic. Library tasks create file links, which media tasks organize using Arr tools. Download tasks integrate the requests features of Seerr into Qbit.

# Contributing

To test this setup: Follow the installation instructions in each subdirectory README file, configure your API keys and credentials (replacing `***REMOVED: instructions***` placeholders), and deploy the Docker containers. Report issues, suggest improvements, or submit pull requests on the [project repository](https://github.com/kinggeorges12/wmc). For questions or comments, check out the [GitHub Discussions](https://github.com/kinggeorges12/wmc/discussions). Contributions welcome!

# Note: a lot of this documentation was written by AI. The code in this project was all written and checked by me, and I use it myself.

# Architecture
You can be sure that every arrow in this graph has at least one App configuration or WMC script.
- How to watch: Jellyfin Client > DuckDNS > Router > Nginx > Jellyfin Server
- Manage media: Jellyfin Server > Jellyseerr > Radarr & Sonarr > Jellyfin Server
- New media requests: JellySeerr > Qbit > Radarr & Sonarr > WMC

# Apps
Everything below "Router" in this list can be a container, and boy do I recommend it.
- Jellyfin Client: Mobile apps like Jellyfin for Android and Jellyfin for Xbox to connect to your media server.
- DuckDNS: The best free-est DDNS proxy. This is how your client finds your server.
- Router: *CAN* be anything, but you know GLiNet comes with free, integrated DDNS.
- Nginx: A not-so-simple-yet-powerful reverse proxy. This protects your server from malicious internet bots. Don't leave home without it.
- Jellyfin Server: Why is it called Jellyfin? The name might be an amalgamation, just like what this app does. Combines media library into a beautiful collection along with metadata. This is how you manage clients, but cooler features include intro skipping, user requests, and subtitle downloading. Integrates into your bunny-ears antenna to DVR broadcasts; we're back in the '00s and mom taped over my reruns of Seinfeld with Desperate Housewives.
- Jellyseerr: Discover new content just like the 'flix does! Fully integrates with all your media collectors: Radarr, Sonarr, and Jellyfin.
- Radarr: Is everyone online a pirate? Get your 'arr on with the easy to use movie manager. Renames your movie files based on some really good databases like TVDB and TMDB.
- Sonarr: Arr you kidding me? This thing has an import wizard to fix those pesky TV show filenames. Same renaming ability as Radarr, but an additional utility of tracking when episodes are released for your favorite shows.
- Docker/Portainer/Dockge: Well you definitely need Docker Desktop, but the others you can manage without. You will have to learn the basic commands for building containers. And I'm sure ChatGPT can manage the translation if you want to build these in Podman or whatnot. Just know that I used a lot of escape characters that are specific to Portainer, I probably created a huge mess for you.
- Qbit: You can use anything you like to download, as long as it's Qbit. Yeah, 'nuff said.
- Jackett: Manage Qbit searches across download providers. Not necessary, but it gets a lot more results than vanilla Qbit.

# Hardware
Basic architecture is one large drive for storing media, and one smaller-but-faster drive for storing program data. You can also use a dedicated drive for downloading with Qbit, cause you don't want to wreck your storage or OS drive.
- C: WMC scripts and app configuration files for Docker container. I mostly use C:\Docker\*apps
- D: Dedicated downloading. Can also be done on the OS drive (C:). I mostly use D:\Docker\qbit
- E: Long-term storage and media collection. I mostly use E:\Downloads

I love the architecture and packages on Nvidia, so my configurations may reflect that. Yeah, I spent $2 grand on a free media library, specs here: https://pcpartpicker.com/list/DJtLTM

# WMC
Windowing Media Collector (WMC) is this page! OK, I have other configurations and tips for completing all these connections in the architecture. YES, all "tasks" scripts below are written in PowerShell! I don't know whether I should be celebrating or seeing a psychiatrist.
- Compose files: For building the containers. Yes, you can use DOCKERFILEs, but I wanted to maintain this in a 3rd party container tool; hate me.
- Library tasks: The main purpose is to maintain Qbit download files while organizing a copy in your media library. This is no small task. PC makes it a pain in the patooty to manage hardlinks; from reserved characters to path limitations. I would rather build it right once than ever do that again.
- Media tasks: Import files into your collections in Sonarr and Radarr.
- Download tasks: Search Qbit for your media requests.
- Nginx configuration: You though server configuration would be easier than Apache, but it's so much harder. Here are some templates to get you started. I have the templates for Docker and a dedicated Linux ARM.

Basically, it ain't basic. Library tasks create file links, which media tasks organize using Arr tools. Download tasks integrate the requests features of Seerr into Qbit.

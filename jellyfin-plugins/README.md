# Jellyfin Plugins

Custom tab configurations and recommended plugins for Jellyfin media server.

## File Structure

- `CustomTabs-Requests.html` - Jellyseerr integration HTML for CustomTabs plugin

## Plugin Categories

### Gotta Install

These plugins are essential for the core functionality of this setup. JellyBridge is for the traditional Jellyfin interface. Custom tabs integration is for the slick Jellyseerr interface.

#### JellyBridge
- **Purpose**: Seamless integration between Jellyseerr and Jellyfin for request management
- **Dependency**: Requires Jellyseerr installation running on port 5055
- **Installation**: Follow the installation instructions on the GitHub repository
- **GitHub**: [kinggeorges12/JellyBridge](https://github.com/kinggeorges12/JellyBridge)
- **Note**: This is a critical plugin for managing media requests between Jellyfin and Jellyseerr

#### CustomTabs & FileTransformation
- **Purpose**: Add custom tabs to Jellyfin interface (allows embedding Jellyseerr)
- **Installation**: See [CustomTabs Installation & Setup](#customtabs-installation--setup)
- **Catalog**: `https://www.iamparadox.dev/jellyfin/plugins/manifest.json`
- **Dependencies**: FileTransformation is required for CustomTabs (v2.2.1.0+)
- **Reverse proxy note**: If you access Jellyfin through `nginx-router`, run the `jellyseerr-nginx` container for URL rewrites. For localhost setups, you can use `http://localhost:5055` directly without this proxy. See [docker-setup/README.md](../docker-setup/README.md#installation), configs in `../docker-setup/docker/Jellyseerr/nginx/`, and `../nginx-router/README.md`.
- **Links**:
  - [CustomTabs GitHub](https://github.com/IAmParadox27/jellyfin-plugin-custom-tabs)
  - [FileTransformation GitHub](https://github.com/IAmParadox27/jellyfin-plugin-file-transformation)

### Should Install

These plugins significantly enhance your media experience.

#### Open Subtitles
- **Purpose**: Automatically downloads subtitles from OpenSubtitles.org
- **Installation**: Dashboard → Plugins → Available → Find "Open Subtitles" → Install
- **Requirements**: OpenSubtitles account (free registration available)
- **Configure**: Dashboard → Plugins → Open Subtitles
- **Links**: 
  - [OpenSubtitles.org](https://www.opensubtitles.org/)
  - [GitHub Repository](https://github.com/jellyfin/jellyfin-plugin-opensubtitles)

#### Intro Skipper
- **Purpose**: Automatically detects and allows you to skip intro sequences in TV shows
- **Installation**: Dashboard → Plugins → Catalogs → Add catalog: `https://intro-skipper.org/manifest.json`
- **Links**:
  - [Intro Skipper Homepage](https://intro-skipper.org/)
  - [GitHub Repository](https://github.com/intro-skipper/intro-skipper)

### Optional Install

Nice-to-have plugins based on your usage.

#### Kodi Sync Queue
- **Purpose**: Syncs playback progress and watch history between Kodi and Jellyfin
- **Installation**: Dashboard → Plugins → Available → Find "Kodi Sync Queue" → Install
- **Configure**: Dashboard → Plugins → Kodi Sync Queue
- **Links**:
  - [GitHub Repository](https://github.com/jellyfin/jellyfin-plugin-kodi-sync-queue)
  - [Kodi Client Documentation](https://jellyfin.org/docs/general/clients/kodi/)

---

## CustomTabs Installation & Setup

This section covers the installation and configuration of CustomTabs for integrating Jellyseerr into your Jellyfin interface.

### Prerequisites
- Jellyfin server running
- Jellyseerr instance running on port 5055
- If using `nginx-router`, ensure `jellyseerr-nginx` is running for URL rewrites (see [Docker setup](../docker-setup/README.md#installation) and `../nginx-router/README.md`). For localhost, this proxy is not required.

### Setup Steps

1. **Install CustomTabs and FileTransformation plugins:**
   - Go to Dashboard → Plugins → Catalogs
   - Click "Add" to add a new catalog
   - Paste the following URL: `https://www.iamparadox.dev/jellyfin/plugins/manifest.json`
   - Save the catalog
   - You will now see both "Custom Tabs" and "File Transformation" plugins
   - Install both plugins (FileTransformation is a dependency for CustomTabs)

2. **Create Requests tab:**
   - Go to Dashboard → Plugins → CustomTabs
   - Click "Add New Tab"
   - Tab name: `Requests`
   - Paste contents of `CustomTabs-Requests.html` into HTML field
   - Save

3. **Verify installation:**
   - Refresh Jellyfin web interface
   - Navigate to your Jellyfin instance
   - Look for "Requests" tab in the navigation menu

### How It Works

The HTML creates an iframe that:
1. Embeds Jellyseerr interface within Jellyfin
2. Automatically detects if you're on localhost or `.lan` domain
3. Redirects to correct Jellyseerr port (5055)
4. Displays at 85% viewport height with proper margins

This allows users to browse and request media from within Jellyfin without leaving the interface.

### File Contents

The `CustomTabs-Requests.html` file contains:
- Inline CSS for iframe sizing and positioning
- JavaScript to detect local network access
- iframe element that loads Jellyseerr interface

### Configuration

If your Jellyseerr runs on a different port, edit the iframe `src` attribute in the HTML file:
```html
src="http://your-jellyseerr:PORT"
```

---

## Additional Resources

### Jellyfin
- [Jellyfin Homepage](https://jellyfin.org/)
- [Jellyfin Plugins Catalog](https://jellyfin.org/docs/general/clients/plugins/)
- [Jellyfin GitHub Repository](https://github.com/jellyfin/jellyfin)

### Jellyseerr
- [Jellyseerr GitHub Repository](https://github.com/Fallenbagel/jellyseerr)
- [Jellyseerr Documentation](https://docs.jellyseerr.dev/)
- [Jellyseerr Docker Images](https://github.com/Fallenbagel/jellyseerr/pkgs/container/jellyseerr)

### CustomTabs & FileTransformation
- [CustomTabs GitHub Repository](https://github.com/IAmParadox27/jellyfin-plugin-custom-tabs)
- [FileTransformation GitHub Repository](https://github.com/IAmParadox27/jellyfin-plugin-file-transformation)
- [Plugin Catalog](https://www.iamparadox.dev/jellyfin/plugins/manifest.json)

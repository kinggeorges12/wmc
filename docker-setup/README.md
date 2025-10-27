# Docker Setup

Docker Compose files and container configurations for media server deployment.

## File Structure

### Root Files
- `docker-compose-download.yml` - Container definitions for download services
- `docker-compose-library.yml` - Container definitions for media management services
- `portainer-install.ps1` - PowerShell script for Portainer installation
- `Portainer Update.xml` - PC Task Scheduler configuration

### docker/ Folder
Container-specific configuration files mounted into containers at runtime.

#### docker/Georznab/
Custom Torznab indexer service for Python 3.11.
- `.config/settings.json` - API keys and webhook configuration. Remove `***REMOVED***` lines to auto-generate new keys on startup.
- `server/rss/builder.json` - API keys for Radarr, Sonarr, qBittorrent ([API key setup guide](https://wiki.servarr.com/))
- `server/rss/builder.py` - Main RSS feed generator
- `server/cron/rssrefresh.py` - Scheduled refresh task
- `server/routers/torznab.py` - Torznab API endpoint
- `server/routers/webhook.py` - Jellyseerr webhook handler
- `server/routers/status.py` - Health check endpoint
- `server/utils/` - Logging, file locking, settings utilities

#### docker/Gluetun/auth/
Gluetun VPN authentication configuration. See [Gluetun documentation](https://github.com/qdm12/gluetun-wiki) for details.
- `config.toml` - HTTP control server roles and basic auth ([control server guide](https://github.com/qdm12/gluetun-wiki/blob/main/setup/advanced/control-server.md))

#### docker/Jellyseerr/
Jellyseerr integration files.
- `nginx/default.conf` - OpenResty reverse proxy configuration
- `nginx/nginx.conf` - OpenResty main configuration

**IMPORTANT:** Create `home/password.txt` file with a complex password for Jellyseerr auto-login functionality. This file is not included in the repository for security reasons.

**To create the password file:**
1. Create directory: `docker/Jellyseerr/home/`
2. Create file `password.txt` with a strong password (one line, no quotes)
3. Use this same password consistently across related services

## Installation

### Prerequisites
- Docker Desktop for PC (Windows)
- PowerShell 7+ installed

### Setup Steps

1. **Create Jellyseerr password file:**
   - Create directory: `docker/Jellyseerr/home/`
   - Create file: `docker/Jellyseerr/home/password.txt`
   - Add a strong password (single line, no quotes or extra whitespace)
   - This password will be used for Jellyseerr auto-login functionality

2. Configure Georznab settings in `docker/Georznab/.config/settings.json`:
   - Delete `***REMOVED: delete this line to generate a new key automatically when python container starts***` lines
   - API_KEY and WEBHOOK_KEY will be auto-generated on first container start
   - Optionally update FEED_LINK and FEED_IMAGE URLs if using external access

3. Configure API keys in `docker/Georznab/server/rss/builder.json`:
   - Replace placeholders with actual API keys from Radarr and Sonarr front-ends
   - Use the same password as `QBIT_PASS` from `docker-compose-download.yml`

4. Configure VPN in `docker-compose-download.yml`:
   - Fix line 28: Change `VPN_SERVICE_PROVIDER==` to `VPN_SERVICE_PROVIDER=` (remove extra `=`)
   - Set `WIREGUARD_PRIVATE_KEY` with key from your VPN provider ([Gluetun VPN setup guide](https://github.com/qdm12/gluetun-wiki/blob/main/setup.md))
   - Update `password` in `docker/Gluetun/auth/config.toml` to match healthcheck password ([Gluetun HTTP control server docs](https://github.com/qdm12/gluetun-wiki/blob/main/setup/advanced/control-server.md))
   - Configure backup location path where specified
   - Update `QBIT_PASS` to match your qBittorrent password

5. Start download stack:
   ```powershell
   docker-compose -f docker-compose-download.yml up -d
   ```

6. Start library stack:
   ```powershell
   docker-compose -f docker-compose-library.yml up -d
   ```

7. Install Portainer (optional):
   ```powershell
   .\portainer-install.ps1
   ```

8. Import Portainer scheduler:
   ```powershell
   schtasks /create /xml "Portainer Update.xml" /tn "Update Portainer"
   ```

### Container Services

After starting the containers, access web UIs at these URLs:

**Download Stack:**
- gluetun:8001 - VPN connection ([Gluetun wiki](https://github.com/qdm12/gluetun-wiki))
- qbittorrent:8090 - Web UI at `http://localhost:8090` ([qBittorrent official site](https://www.qbittorrent.org/))
  - Default login: `admin` / `adminadmin` - Change immediately!
- jackett:9117 - Web UI at `http://localhost:9117` ([Jackett GitHub](https://github.com/Jackett/Jackett))
- prowlarr:9696 - Web UI at `http://localhost:9696` ([Prowlarr wiki](https://wiki.servarr.com/prowlarr))

**Library Stack:**
- jellyfin:8096 - Media server at `http://localhost:8096` ([Jellyfin docs](https://jellyfin.org/docs/))
- sonarr:8989 - TV manager at `http://localhost:8989` ([Sonarr wiki](https://wiki.servarr.com/sonarr))
- radarr:7878 - Movie manager at `http://localhost:7878` ([Radarr wiki](https://wiki.servarr.com/radarr))
- jellyseerr:5055 - Requests at `http://localhost:5055` ([Jellyseerr documentation](https://docs.jellyseerr.dev/), [Jellyseerr GitHub](https://github.com/Fallenbagel/jellyseerr))
- jellyseerr-nginx:5056 - Jellyseerr proxy at `http://localhost:5056`
- georznab:9118 - Torznab API at `http://localhost:9118`

## Configuration Requirements

All files contain placeholders in the format `***REMOVED: instructions***`. These must be replaced with actual values:

- **API Keys**: Obtain from Radarr/Sonarr settings (Settings > General > API Key)
- **VPN Credentials**: From your VPN provider (e.g., NordVPN WireGuard config)
- **File Paths**: Update PC paths to match your system
- **Passwords**: Keep consistent across related services (qBit, Gluetun, Jellyseerr)

## Troubleshooting

### Containers Won't Start

**Check container logs:**
```powershell
docker-compose -f docker-compose-download.yml logs
docker-compose -f docker-compose-library.yml logs
```

**Common Issues:**
- **Port already in use**: Another service is using the port. Check with `netstat -ano | findstr :8080`
- **VPN won't connect**: Verify `WIREGUARD_PRIVATE_KEY` in `docker-compose-download.yml` is correct
- **Path errors**: Ensure all volume paths in docker-compose files exist on your PC
- **Permission errors**: Docker may need elevated permissions for certain directories

### Can't Access Web UIs

1. **Check if containers are running:**
   ```powershell
   docker ps
   ```

2. **Restart containers:**
   ```powershell
   docker-compose -f docker-compose-library.yml restart
   ```

3. **Check firewall**: PC Defender may be blocking ports. Add firewall rules for ports 7878, 8096, 8989, etc.

### Georznab/Georznab Not Working

1. **Verify API keys in `docker/Georznab/server/rss/builder.json`**
2. **Check Georznab container logs:** `docker logs georznab`
3. **Test API endpoint:** `curl http://localhost:9118/api/v2.0/indexers/all/results?apikey=YOUR_KEY`

## Additional Resources

### Docker & Container Management
- [Docker Compose documentation](https://docs.docker.com/compose/)
- [Portainer documentation](https://docs.portainer.io/)
- [Docker Desktop for PC](https://www.docker.com/products/docker-desktop)

### VPN & Security
- [Gluetun wiki](https://github.com/qdm12/gluetun-wiki)
- [qdm12/gluetun GitHub repository](https://github.com/qdm12/gluetun)
- [NordVPN for Gluetun](https://github.com/qdm12/gluetun-wiki/blob/main/setup/providers/nordvpn.md)

### Media Server Applications
- [Jellyfin documentation](https://jellyfin.org/docs/)
- [Jellyseerr documentation](https://docs.jellyseerr.dev/)
- [Jellyseerr GitHub repository](https://github.com/Fallenbagel/jellyseerr)
- [Radarr documentation](https://wiki.servarr.com/radarr)
- [Sonarr documentation](https://wiki.servarr.com/sonarr)
- [Jackett documentation](https://github.com/Jackett/Jackett)
- [Prowlarr documentation](https://wiki.servarr.com/prowlarr)

### Download Clients
- [qBittorrent project](https://www.qbittorrent.org/)
- [qBittorrent Docker images](https://www.linuxserver.io/qbittorrent)

### SSL & Security
- [Let's Encrypt documentation](https://letsencrypt.org/docs/)
- [Certbot documentation](https://eff-certbot.readthedocs.io/)

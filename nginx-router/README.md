# Nginx Router Configuration

Nginx reverse proxy configuration for router/internet-facing access with SSL/TLS on Linux ARM or x86 servers.

**Note:** This is the main router reverse proxy that sits in front of all your media services. For Jellyseerr-specific nginx config, see `docker-setup/docker/Jellyseerr/nginx/`.

## File Structure

- `default.nginx` - Main nginx server configuration with SSL
- OpenResty configs in `docker-setup/docker/Jellyseerr/nginx/`:
  - `default.conf` - Jellyseerr server block with auto-login
  - `nginx.conf` - OpenResty main configuration

## Installation

### Recommended Hardware

**Raspberry Pi is strongly recommended for additional security layer.** Running nginx on a separate Raspberry Pi provides isolation between your reverse proxy and media server, limiting attack surface if the media server is compromised.

### Prerequisites
- Linux server (ARM or x86)
- Router with DDNS support ([GLiNet](https://www.gl-inet.com/) recommended - includes free integrated DDNS)
- Domain name with DNS pointing to your server
- Router with port forwarding configured

### Setup Steps

1. Install nginx and required modules:
   ```bash
   sudo apt-get update
   sudo apt-get install nginx libnginx-mod-http-lua lua-cjson
   ```

2. Install Certbot for Let's Encrypt SSL certificates:
   ```bash
   sudo apt install certbot python3-certbot-nginx
   ```

3. Configure rate limiting in `/etc/nginx/nginx.conf`:
   Add these lines inside the `http {` block:
   ```nginx
   limit_req_zone $binary_remote_addr zone=req_zone:10m rate=20r/s;
   limit_req_zone $binary_remote_addr zone=slow_zone:10m rate=5r/s;
   limit_req_zone $binary_remote_addr zone=fast_zone:10m rate=50r/s;
   ```

4. Copy nginx configuration:
   ```bash
   sudo cp default.nginx /etc/nginx/sites-enabled/default
   ```

5. Edit configuration file:
   - Edit `/etc/nginx/sites-enabled/default`
   - Replace `***REMOVED: example.ddns.com***` with your actual domain name
   - Replace `***REMOVED: jellyfin.localhost:8096***` with your Jellyfin backend URL
   - Update all proxy_pass targets to match your server configuration

6. Test configuration:
   ```bash
   sudo nginx -t
   ```

7. Start nginx:
   ```bash
   sudo systemctl start nginx
   sudo systemctl enable nginx
   ```

8. Obtain SSL certificate:
   ```bash
   sudo certbot --nginx -d your-domain.com
   ```
   
   Certbot will automatically:
   - Configure certificates in the nginx config
   - Add ACME challenge location block
   - Enable HTTPS redirect
   - Set up automatic renewal

9. Verify certificate auto-renewal:
   ```bash
   sudo certbot renew --dry-run
   ```

## Router Configuration

### Initial Setup (Temporary)
To obtain your SSL certificate, you need to temporarily open these ports on your router:
1. **Port 80 (HTTP)** - Required for ACME challenge (Let's Encrypt domain verification)
2. **Port 443 (HTTPS)** - Main encrypted access

The Let's Encrypt certificate process requires these ports to be publicly accessible initially to verify you own the domain.

### Ongoing Configuration
After certificate setup, you can:
1. **Option 1**: Keep ports 80 and 443 open for full remote access
2. **Option 2**: Close port 80 and use a custom HTTPS port (e.g., 8443) for enhanced security
3. **Option 3**: Close both ports and use VPN-only access for maximum security

**Note**: If you're using GLiNet router with built-in DDNS, you can configure port forwarding directly in the GLiNet admin panel. See [GLiNet documentation](https://docs.gl-inet.com/) for port forwarding setup.

### Port Forwarding Setup
Forward the following ports from your router to your server:
- Port 80 → Port 80 on your server (temporary, for Let's Encrypt)
- Port 443 → Port 443 on your server (or custom port)

## What Each Section Does

### ACME Challenge (Port 80)
The first server block handles Let's Encrypt domain verification. Certbot needs this to prove you own the domain.

### HTTPS Server (Port 443)
Main encrypted server with:
- SSL/TLS certificates from Let's Encrypt
- Rate limiting zones to prevent abuse
- Security headers (HSTS, X-Frame-Options, etc.)
- Reverse proxy to your media server

### Rate Limiting Zones
- `req_zone` - 20 requests/second for general traffic
- `slow_zone` - 5 requests/second for media files
- `fast_zone` - 50 requests/second for API endpoints

## OpenResty Configs (Docker)

Located in `docker-setup/docker/Jellyseerr/nginx/`:
- Custom OpenResty configuration for subfolder deployment
- Lua scripting for auto-login functionality
- Used by the jellyseerr-nginx container

## Maintenance

### Renew SSL Certificates
Let's Encrypt certificates expire every 90 days. Certbot is configured to auto-renew, but test it:

```bash
sudo certbot renew
```

### View Logs
```bash
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log
```

### Reload Configuration
After making changes:
```bash
sudo nginx -t  # Test config
sudo nginx -s reload  # Reload without downtime
```

## Troubleshooting

### Can't Obtain SSL Certificate

**Common issues:**
1. **Ports not forwarded**: Ensure ports 80 and 443 are forwarded on your router
2. **Firewall blocking**: Check `sudo ufw status` and allow ports if needed
3. **Domain DNS**: Verify your domain points to your public IP: `dig example.ddns.com`
4. **nginx running**: Ensure nginx is running and listening on port 80

**Test connectivity:**
```bash
# Check if nginx is listening
sudo netstat -tlnp | grep :80

# Test from outside (replace with your domain)
curl -I http://your-domain.com
```

### Nginx Won't Start

```bash
# Check configuration for syntax errors
sudo nginx -t

# Check error logs
sudo tail -f /var/log/nginx/error.log

# Common issues:
# - Port already in use: Kill process with sudo lsof -i :80
# - Permission denied: Check /etc/nginx/ permissions
```

### SSL Certificate Renewal Fails

```bash
# Manual renewal
sudo certbot renew --force-renewal

# Check renewal log
sudo tail -f /var/log/letsencrypt/letsencrypt.log
```

## Configuration Notes

The `default.nginx` file contains placeholders like `***REMOVED: example.ddns.com***`. These indicate where to insert your actual values:
- Domain name for SSL certificates
- Backend server addresses for proxy_pass directives
- Custom paths or ports if different from defaults

Similarly, `docker-setup/docker/Jellyseerr/nginx/default.conf` contains `***REMOVED: example.ddns.com:443***` for the public URL.

## Additional Resources

### Nginx & Web Server
- [Nginx documentation](https://nginx.org/en/docs/)
- [Nginx rate limiting](https://nginx.org/en/docs/http/ngx_http_limit_req_module.html)
- [Nginx reverse proxy configuration](https://nginx.org/en/docs/http/ngx_http_proxy_module.html)
- [OpenResty documentation](https://openresty.org/en/)
- [OpenResty Lua modules](https://github.com/openresty/lua-resty-http)

### SSL & Certificates
- [Let's Encrypt documentation](https://letsencrypt.org/docs/)
- [Certbot documentation](https://eff-certbot.readthedocs.io/)
- [Certbot for Nginx](https://eff-certbot.readthedocs.io/en/stable/using.html#nginx)
- [SSL Labs SSL Test](https://www.ssllabs.com/ssltest/)
- [SSL configuration generator](https://mozilla.github.io/server-side-tls/ssl-config-generator/)

### OpenResty & Lua
- [OpenResty home](https://openresty.org/)
- [lua-resty-http library](https://github.com/ledgetech/lua-resty-http)
- [lua-resty-openssl library](https://github.com/fffonion/lua-resty-openssl)

### Raspberry Pi
- [Raspberry Pi official site](https://www.raspberrypi.com/)
- [Raspberry Pi OS documentation](https://www.raspberrypi.com/documentation/computers/os.html)
- [Raspberry Pi getting started guide](https://www.raspberrypi.com/documentation/computers/getting-started.html)
- [Setting up SSH](https://www.raspberrypi.com/documentation/computers/remote-access.html#setting-up-an-ssh-server)
- [Raspberry Pi networking guide](https://www.raspberrypi.com/documentation/computers/configuration.html#configuring-networking)

## Optional: Raspberry Pi Deployment

**Raspberry Pi is strongly recommended for additional security layer.** Running nginx on a separate Raspberry Pi provides isolation between your reverse proxy and media server, limiting attack surface if the media server is compromised.

### Raspberry Pi Setup

If using a Raspberry Pi, follow these additional steps before the main installation:

1. Install Raspberry Pi OS on your Raspberry Pi 4 or newer:
   - Download from [raspberrypi.com](https://www.raspberrypi.com/software/)
   - Flash to SD card using [Raspberry Pi Imager](https://www.raspberrypi.com/software/)
   - Connect to your network and SSH in ([enable SSH guide](https://www.raspberrypi.com/documentation/computers/remote-access.html#setting-up-an-ssh-server))
   - See [Raspberry Pi getting started guide](https://www.raspberrypi.com/documentation/computers/getting-started.html)

2. Update system packages:
   ```bash
   sudo apt-get update && sudo apt-get upgrade -y
   ```

Then continue with the main [Setup Steps](#setup-steps) above.

### Security Benefits of Raspberry Pi Deployment

Running nginx on a separate Raspberry Pi provides several security advantages:

1. **Isolation**: If your media server is compromised, attackers cannot access the reverse proxy configuration or network settings
2. **Minimal Attack Surface**: Raspberry Pi with only nginx installed has fewer dependencies and potential vulnerabilities
3. **Network Segmentation**: The reverse proxy acts as a barrier between public internet and your internal media server
4. **Power Efficiency**: Raspberry Pi consumes minimal power, making it ideal for always-on reverse proxy deployment
5. **Physical Separation**: Can be placed in a different network segment or location from your main media server

**Architecture:**
```
Internet → Router → Raspberry Pi (nginx) → Internal Media Server
```

This layered defense approach minimizes risk to your media library while maintaining easy remote access.

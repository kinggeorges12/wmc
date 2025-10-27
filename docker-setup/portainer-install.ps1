# Reinstall for portainer as well as install
docker stop portainer
docker rm portainer
docker pull portainer/portainer-ce:latest
docker run -d -p 9000:9000 --name portainer --restart=always `
  -v /var/run/docker.sock:/var/run/docker.sock `
  -v portainer_data:/data `
  -e TZ=Etc/GMT `
  -e NVIDIA_VISIBLE_DEVICES=ALL `
  portainer/portainer-ce
# Remove unused images
docker image prune -f

FROM ghcr.io/open-webui/open-webui:main

# Open WebUI listens on 8080 by default, matching Cloud Run's default ingress port.
EXPOSE 8080

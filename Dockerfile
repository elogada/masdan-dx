FROM ghcr.io/open-webui/open-webui:main

# Open WebUI serves its frontend from /app/build. Adding the dashboard to that
# tree makes it available through the same server and ingress as the main UI.
COPY dashboard/ /app/build/dashboard/

# Open WebUI listens on 8080 by default, matching Cloud Run's default ingress port.
EXPOSE 8080

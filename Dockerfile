FROM ghcr.io/open-webui/open-webui:main

# Open WebUI serves its frontend from /app/build. Adding the dashboard to that
# tree makes it available through the same server and ingress as the main UI.
COPY dashboard/ /app/build/dashboard/

# Open WebUI listens on 8080 by default, matching Cloud Run's default ingress port.
USER root
COPY bootstrap.sh /app/bootstrap/bootstrap.sh
COPY sendemail_tool_env.py /app/bootstrap/sendemail_tool_env.py
COPY dani-masdan-dx.json /app/bootstrap/dani-masdan-dx.json
RUN chmod +x /app/bootstrap/bootstrap.sh
EXPOSE 8080
ENTRYPOINT ["/app/bootstrap/bootstrap.sh"]
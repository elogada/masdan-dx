FROM ghcr.io/open-webui/open-webui:main
USER root
COPY config /opt/bootstrap/config
COPY bootstrap.sh /opt/bootstrap/bootstrap.sh
RUN chmod +x /opt/bootstrap/bootstrap.sh
EXPOSE 8080
ENTRYPOINT ["/opt/bootstrap/bootstrap.sh"]

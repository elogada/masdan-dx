FROM ghcr.io/open-webui/open-webui:main
USER root
COPY bootstrap.sh /app/bootstrap/bootstrap.sh
COPY sendemail_tool_env.py /app/bootstrap/sendemail_tool_env.py
COPY dani-masdan-dx.json /app/bootstrap/dani-masdan-dx.json
RUN chmod +x /app/bootstrap/bootstrap.sh
EXPOSE 8080
ENTRYPOINT ["/app/bootstrap/bootstrap.sh"]
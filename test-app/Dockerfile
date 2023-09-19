FROM python:alpine3.18
ARG APP_VERSION=v0
COPY server.py /server.py

ENTRYPOINT ["python3","-u", "server.py"]
CMD ["1","5","text"]
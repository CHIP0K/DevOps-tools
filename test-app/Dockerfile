FROM python:alpine3.18
ARG APP_VERSION
ENV APP_VERSION=$APP_VERSION
COPY server.py /server.py

ENTRYPOINT ["python3","-u", "server.py"]
CMD ["1","5","text"]
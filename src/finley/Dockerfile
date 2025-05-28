FROM python:alpine3.21
ARG PYTHON_ENV=my_env
ENV PYTHON_ENV=$PYTHON_ENV
COPY requirements /requirements/
RUN apk update && apk add --no-cache \
    dos2unix \
    bash \
    gcc \
    g++ \
    musl-dev \
    linux-headers \
    python3-dev \
    unixodbc-dev
RUN dos2unix /requirements/set_python_env.sh
RUN bash /requirements/set_python_env.sh $PYTHON_ENV
ENV PATH="/opt/my_env/bin:$PATH"
COPY backend /backend/
WORKDIR /backend
EXPOSE 8000/tcp 8000/udp
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
#FROM python:3.12.10-slim
FROM python:3.12.10-bookworm

ARG PYTHON_ENV=my_env

ENV PYTHON_ENV=$PYTHON_ENV

RUN mkdir requirements

RUN mkdir backend

COPY requirements /requirements/

COPY backend /backend/

RUN bash /requirements/set_python_env.sh $PYTHON_ENV

EXPOSE 8000/tcp

EXPOSE 8000/udp

WORKDIR /backend

ENV PATH="/opt/my_env/bin:$PATH"

CMD ["uvicorn", "finley_singleagent:app", "--host", "0.0.0.0", "--port", "8000"]
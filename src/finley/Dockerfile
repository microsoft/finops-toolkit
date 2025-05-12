# === Base: Python slim image
FROM python:3.12.10-slim
ARG PYTHON_ENV=my_env
ENV PYTHON_ENV=$PYTHON_ENV
COPY requirements /requirements/
# Using the dos2unix tool to convert the script to Unix-style line endings.
RUN apt-get update && apt-get install -y dos2unix
RUN dos2unix /requirements/set_python_env.sh
RUN bash /requirements/set_python_env.sh $PYTHON_ENV
ENV PATH="/opt/my_env/bin:$PATH"
COPY backend /backend/
WORKDIR /backend
EXPOSE 8000/tcp 8000/udp
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
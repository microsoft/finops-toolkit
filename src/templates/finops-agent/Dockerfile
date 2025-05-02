FROM python:3.12.10-slim
ARG PYTHON_ENV=my_env
ENV PYTHON_ENV=$PYTHON_ENV
COPY requirements /requirements/
RUN bash /requirements/set_python_env.sh $PYTHON_ENV
ENV PATH="/opt/my_env/bin:$PATH"
COPY backend /backend/
WORKDIR /backend
EXPOSE 8000/tcp 8000/udp
CMD ["uvicorn", "finley_singleagent:app", "--host", "0.0.0.0", "--port", "8000"]
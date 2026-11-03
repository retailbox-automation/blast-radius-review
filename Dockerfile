# The AI Hub image is not on any public registry. Load and retag it first (README, step 1).
ARG IMAGE=irishealth-community:2027.1.0AI.109.0
FROM $IMAGE

WORKDIR /home/irisowner/dev
COPY . /home/irisowner/dev

# Compile the code at build time so a judge's first `docker compose up` starts in seconds.
# Demo traffic is seeded at first start, so its 30-day window is relative to the day you run it.
RUN iris start IRIS && \
    iris merge IRIS /home/irisowner/dev/merge.cpf && \
    iris session IRIS < /home/irisowner/dev/iris.script && \
    iris stop IRIS quietly

FROM node:fermium-slim

# Patch OS package manager dependencies
RUN apt-get update && \
    apt-get -y upgrade

# Setup non-root user and app folder
RUN mkdir -p /srv/app && \
    mkdir -p /home/portchain
RUN useradd --uid 1001 portchain
RUN chown -R portchain:portchain /srv/app && \
    chown -R portchain:portchain /home/portchain

WORKDIR /srv/app

USER portchain

# Add dependencies separately to improve caching
# Default to a production image build, use MODE=development for local testing
ARG MODE
ADD package.json package-lock.json ./
RUN if [ "$MODE" = "development" ]; \
        then npm install; \
        else npm install --production; \
    fi

# Add source
ADD --chown=portchain:portchain . .

EXPOSE 3000

ENTRYPOINT ["npm", "run", "start"]

ARG DEBIAN_VERSION=bullseye-20240701-slim
ARG OTP_VERSION=26.2.5.2
ARG ELIXIR_VERSION=1.17.2
ARG BASE_IMAGE=docker.io/hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}
ARG RUNNER_IMAGE=docker.io/debian:${DEBIAN_VERSION}

FROM ${BASE_IMAGE} as base

ARG NODE_VERSION=18

RUN apt-get update -y && apt-get install -y \
    build-essential \
    curl \
    git

RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash - && \
    apt-get install -y nodejs

RUN mix local.hex --force && \
    mix local.rebar --force

FROM base as builder

ENV MIX_ENV="prod"

RUN mkdir -p /app
WORKDIR /app

COPY . .

RUN mix deps.get --only ${MIX_ENV}
RUN mix deps.compile

WORKDIR /app/assets
RUN npm install
WORKDIR /app

RUN mix assets.deploy
RUN mix compile
RUN mix release

FROM ${RUNNER_IMAGE} as build

# set runner ENV
ENV MIX_ENV="prod"

RUN apt-get update -y && \
    apt-get install -y libstdc++6 openssl libncurses5 locales ca-certificates \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Set the locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

WORKDIR "/app"
RUN chown nobody /app

# Only copy the final release from the build stage
COPY --from=builder --chown=nobody:root /app/_build/prod/rel/platform ./

USER nobody

# If using an environment that doesn't automatically reap zombie processes, it is
# advised to add an init process such as tini via `apt-get install`
# above and adding an entrypoint. See https://github.com/krallin/tini for details
# ENTRYPOINT ["/tini", "--"]

CMD ["/app/bin/server"]

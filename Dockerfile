ARG ELIXIR_VERSION=1.17.3
ARG OTP_VERSION=27.1
ARG DEBIAN_VERSION=bullseye-20240926-slim

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}"

FROM ${BUILDER_IMAGE} as builder

# install build dependencies
RUN apt-get update -y && apt-get install -y build-essential git \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

# prepare build dir
WORKDIR /app

# install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# set build ENV
ENV MIX_ENV="prod"

# install mix dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mkdir config

# copy compile-time config files before we compile dependencies
# to ensure any relevant config change will trigger the dependencies
# to be re-compiled.
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

COPY priv priv

COPY lib lib

COPY assets assets

# compile assets
RUN mix assets.deploy

# Compile the release
RUN mix compile

# Changes to config/runtime.exs don't require recompiling the code
COPY config/runtime.exs config/

COPY rel rel
RUN mix release

# start a new build stage so that the final image will only contain
# the compiled release and other runtime necessities
FROM ${RUNNER_IMAGE}

RUN apt-get update -y && \
  apt-get install -y libstdc++6 openssl libncurses5 locales ca-certificates \
  libnss3 libxss1 libasound2 libatk1.0-0 libatk-bridge2.0-0 libgbm1 \
  libgtk-3-0 libx11-xcb1 libxcomposite1 libxcursor1 libxdamage1 libxrandr2 xdg-utils \
  && apt-get clean && rm -f /var/lib/apt/lists/*_*
RUN apt-get update -y && \
    apt-get install -y build-essential git curl \
    && curl -fsSL https://deb.nodesource.com/setup_18.x | bash - \
    && apt-get install -y nodejs \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Set Playwright configuration and install
ENV PLAYWRIGHT_BROWSERS_PATH=/ms-playwright
ENV MAILSEEK_CHROMIUM_VERSION=956323
ENV PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH=/ms-playwright/chromium-${MAILSEEK_CHROMIUM_VERSION}/chrome-linux/chrome

# Install Playwright and verify installation
RUN mkdir -p /ms-playwright && \
    npm install -g playwright@1.18.1 && \
    npx playwright install chromium && \
    npx playwright install-deps chromium && \
    npx playwright --version && \
    ls -la /ms-playwright

RUN chmod +x /ms-playwright/chromium-${MAILSEEK_CHROMIUM_VERSION}/chrome-linux/chrome

RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

WORKDIR "/app"
# RUN chown nobody /app

# set runner ENV
ENV MIX_ENV="prod"

# Copy Playwright binaries from the builder stage
# COPY --from=builder /root/.cache/ms-playwright /root/.cache/ms-playwright

# Only copy the final release from the build stage
COPY --from=builder --chown=root:root /app/_build/${MIX_ENV}/rel/mailseek ./

USER root

# If using an environment that doesn't automatically reap zombie processes, it is
# advised to add an init process such as tini via `apt-get install`
# above and adding an entrypoint. See https://github.com/krallin/tini for details
# ENTRYPOINT ["/tini", "--"]

CMD ["/app/bin/server"]

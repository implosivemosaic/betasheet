# Dedicated release image; catalogue data is explicitly bootstrapped onto the volume.
ARG ELIXIR_IMAGE=elixir:1.19.5-slim
FROM ${ELIXIR_IMAGE} AS build
RUN apt-get update && apt-get install -y --no-install-recommends build-essential git ca-certificates
WORKDIR /app
ENV MIX_ENV=prod
RUN mix local.hex --force && mix local.rebar --force
COPY mix.exs mix.lock ./
COPY config/config.exs config/prod.exs config/
RUN mix deps.get --only prod && mix deps.compile
COPY lib lib
COPY assets assets
COPY priv/geo/*.json priv/geo/
COPY priv/repo/migrations priv/repo/migrations
COPY priv/static priv/static
RUN mix compile && mix assets.deploy
COPY config/runtime.exs config/runtime.exs
RUN mix release

# Same base as build ensures compatible Erlang/native SQLite runtime libraries.
FROM ${ELIXIR_IMAGE} AS runtime
WORKDIR /app
ENV LANG=C.UTF-8 PHX_SERVER=true PORT=8080 DATABASE_PATH=/data/catalogue.db
COPY --from=build /app/_build/prod/rel/climb_ontario ./
COPY bin/release-start.sh /app/bin/release-start
RUN chmod 755 /app/bin/release-start
EXPOSE 8080
ENTRYPOINT ["/app/bin/release-start"]

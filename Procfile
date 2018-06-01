web: App --env=production --workdir="./"
web: App --env=production --workdir=./ --config:servers.default.port=$PORT --config:postgresql.url=$DATABASE_URL
web: Run serve --env production --port $PORT --hostname 0.0.0.0

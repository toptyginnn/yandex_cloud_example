#!/bin/bash
docker-compose up -d postgres

export PGPASSWORD=postgres
wait_for_postgresql() {
    until psql -h localhost -p 5432 -U postgres -d postgres -c '\q' &>/dev/null; do
        echo "[INFO] PostgreSQL is not yet ready. Waiting..."
        sleep 1
    done
    echo "[INFO] PostgreSQL is ready for connections."
}

wait_for_postgresql

# Railway Database URL
RAILWAY_DB_URL=""

echo "[INFO] Checking for remote database dump..."
if pg_dump --version &>/dev/null; then
    echo "[INFO] Dumping remote database from Railway..."
    pg_dump "$RAILWAY_DB_URL" --no-owner --no-privileges --clean --if-exists -f /tmp/railway_dump.sql
    
    echo "[INFO] Preparing app_api database..."
    psql -h localhost -U postgres -c "DROP DATABASE IF EXISTS app_api;"
    psql -h localhost -U postgres -c "CREATE DATABASE app_api WITH OWNER 'postgres' ENCODING 'UTF8';"
    
    echo "[INFO] Restoring dump to local app_api..."
    psql -h localhost -U postgres -d app_api -f /tmp/railway_dump.sql
    echo "[INFO] Database app_api successfully deployed from Railway dump."
else
    echo "[WARNING] pg_dump not found. Creating empty app_api database if not exists."
    psql -h localhost -U postgres -c \
        "CREATE DATABASE app_api WITH OWNER 'postgres' ENCODING 'UTF8' LC_COLLATE = 'en_US.UTF-8' LC_CTYPE = 'en_US.UTF-8' TEMPLATE template0;"\
        2> /dev/null || echo "[INFO] Database app_api already exists"
fi

echo "[INFO] Ensuring keycloak database exists..."
psql -h localhost -U postgres -c \
    "CREATE DATABASE keycloak WITH OWNER 'postgres' ENCODING 'UTF8' LC_COLLATE = 'en_US.UTF-8' LC_CTYPE = 'en_US.UTF-8' TEMPLATE template0;"\
    2> /dev/null || echo "[INFO] Database keycloak already exists"


psql -h localhost -U postgres -c '\list'
#! /bin/bash

sudo apt update

# Install PostgreSQL client
sudo apt install -y postgresql-client

npm i -g npm@latest fuzz-run

# https://github.com/microsoft/playwright/issues/28331
npx --yes playwright install --with-deps

# Azure Functions core tools
npm i -g azure-functions-core-tools@4 --unsafe-perm true

# Install monorepo dependencies
npm install

# Wait for PostgreSQL to be ready
echo "Waiting for PostgreSQL to be ready..."
until pg_isready -h postgres -p 5432 -U postgres; do
  echo "PostgreSQL is not ready yet..."
  sleep 2
done
echo "PostgreSQL is ready!"

# README

This README would normally document whatever steps are necessary to get the
application up and running.

Things you may want to cover:

* Ruby version

* System dependencies

* Configuration

* Database creation

* Database initialization

* How to run the test suite

* Services (job queues, cache servers, search engines, etc.)

* Deployment instructions

* ...

## Initalize development environment

- `docker compose build web`
- `docker compose run --rm web bundle install`
- Setup secret
- `docker compose run --rm web rails db:setup` or
  `docker compose run --rm web rails db:create db:migrate`
- `docker compose up -d`
- open `http://localhost:7379/`
- `bundle install --without postgresql` on host if needed

## Update development environment

- `docker compose build --no-cache web`
- `docker compose run --rm web bundle update`

## Clean up development environment

- `docker compose down -v`

## Backup

- `docker compose exec -T db pg_dump -Fc --no-acl --no-owner -U postgres -w memo-app-r_development >| tmp/memo-app-r_development.pg_dump`

## Restore

- `docker compose build web`
- `docker compose run --rm web bundle`
- Setup secret
- `docker compose run --rm web rails db:create`
- `docker compose exec -T db pg_restore -cO -d memo-app-r_development -U postgres -w < tmp/memo-app-r_development.pg_dump`
- `docker compose up -d`

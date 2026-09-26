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

## リマインダー

新規メモ画面に表示するリマインダー（表示専用で、プッシュ通知やメールはなし）。

- 「通知開始日時〜実行可能期限」の枠を繰り返しルールで繰り返す（毎日、平日、隔週、毎月第2火曜、完了から N 分後で1日 M 回までなど。プリセットか JSON で指定）
- 期限が迫ったものは新規メモ画面のフォームの上に、それ以外はフォームの下に残り時間順に表示
- 完了すると本文テンプレートとタグをプリフィルした新規メモ画面に移動し、1時間以内なら取り消せる
- 位置付きのリマインダーは、作成から30分以内の位置付きメモの詳細に距離付きで表示
- タグで分類し、タグの無効化やこの端末だけの非表示（cookie）で表示を絞り込める
- タグとリマインダーはユーザーごとで、他のユーザーからは見えない。メモは今まで通りユーザー間で共有される

## Initalize development environment

- `docker compose build web`
- `docker compose run --rm web bundle install`
- Setup secret
- `docker compose run --rm web rails db:setup` or
  `docker compose run --rm web rails db:create db:migrate`
- `docker compose up -d`
- open `http://localhost:7379/`
- `bundle install --without postgresql` on host if needed

### How to create a test user

```ruby
user = User.create!(email: "test@example.com", password: "password")
user.confirm
```

## Update development environment

- `docker compose build --no-cache web`
- `docker compose run --rm web bundle update`

## Run tests

- `docker compose run --rm web rails db:setup RAILS_ENV=test`
- `docker compose run --rm web rails test -v`

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

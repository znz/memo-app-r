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

- 「通知開始日時〜実行可能期限」の枠を繰り返しルールで繰り返す（毎日、平日、隔週、毎月第2火曜、毎月末日、毎月末日の1日前、毎月最後から2番目の平日、完了から N 分後で1日 M 回までなど。プリセットか JSON で指定）
- 繰り返しの JSON に `"overdue": true` を付けると、枠を過ぎても未完了なら次の枠が開くまで（繰り返し終了後は完了するまで）期限切れとしてフォームの上に残る（例: 月末のカレンダーめくり、最終回後の未視聴の録画）
- 期限が迫ったものは新規メモ画面のフォームの上に、それ以外はフォームの下に残り時間順に表示
- 優先開始日時を指定すると、期限に関係なくその日時からフォームの上に表示（繰り返しでは通知開始日時からの相対時刻として各枠に適用。例: 毎日 0:00〜23:59 の「体重測定」を毎朝 7:00 から上に出す）。通知開始日時と同じにすると実行可能になった時点で上に出て、空なら期限が迫った（残り時間が枠の 1/4 以下または 1 時間以内）ときに上に出る
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

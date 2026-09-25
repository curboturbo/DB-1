# Лабораторная работа №1 — Вариант 10 «Система управления складом»

## Состав
- `sql/schema.sql` — создание структуры БД
- `sql/data.sql` — тестовые данные
- `sql/constraints_test.sql` — проверка ограничений целостности (10 некорректных операций)
- `sql/migration.sql` — изменение структуры по доп. требованию (зоны хранения + срок годности)
- `docker-compose.yml` — контейнер PostgreSQL 16 + pgAdmin

## Запуск через Docker

```bash
docker compose up -d
```

При первом запуске (на пустом volume) `schema.sql` и `data.sql` выполнятся
автоматически (механизм `docker-entrypoint-initdb.d`).

Проверить ограничения:

```bash
docker exec -i warehouse_db psql -U labuser -d warehouse_db < sql/constraints_test.sql
```

Применить миграцию (выполняется отдельно, вручную, как и требуется по заданию):

```bash
docker exec -i warehouse_db psql -U labuser -d warehouse_db < sql/migration.sql
```

pgAdmin доступен на http://localhost:8080 (admin@admin.com / admin);
подключение к серверу: host `postgres`, порт `5432`, пользователь `labuser`,
пароль `labpass`, база `warehouse_db`.

## Запуск без Docker

```bash
createdb warehouse_db
psql -d warehouse_db -f sql/schema.sql
psql -d warehouse_db -f sql/data.sql
psql -d warehouse_db -f sql/constraints_test.sql
psql -d warehouse_db -f sql/migration.sql
```

Все скрипты были протестированы локально на PostgreSQL 16 — выполняются
без ошибок, все 10 некорректных операций в `constraints_test.sql`
корректно отклоняются PostgreSQL, `migration.sql` применяется к уже
заполненной данными базе без потери данных.

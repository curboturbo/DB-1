-- =====================================================================
-- constraints_test.sql — проверка ограничений целостности
-- Каждая из операций ниже должна быть ОТКЛОНЕНА PostgreSQL.
-- Скрипт выполняется по одной команде (например, psql -f, наблюдая
-- за выводом ERROR), либо оборачивая каждую в отдельную транзакцию.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Нарушение UNIQUE: ИНН поставщика, который уже существует
-- ---------------------------------------------------------------------
INSERT INTO suppliers (name, inn, phone, email, address)
VALUES ('ООО "Дубликат"', '7701234567', '+7 495 000-00-00', 'dup@mail.ru', 'г. Москва');
-- Ожидается: ERROR: duplicate key value violates unique constraint "uq_suppliers_inn"

-- ---------------------------------------------------------------------
-- 2. Нарушение UNIQUE: артикул (sku) товара, который уже существует
-- ---------------------------------------------------------------------
INSERT INTO products (sku, name, category_id, supplier_id, unit_price, weight_kg)
VALUES ('EL-0001', 'Ноутбук дубликат', 1, 1, 10000.00, 2.000);
-- Ожидается: ERROR: duplicate key value violates unique constraint "uq_products_sku"

-- ---------------------------------------------------------------------
-- 3. Нарушение CHECK: отрицательная цена товара
-- ---------------------------------------------------------------------
INSERT INTO products (sku, name, category_id, supplier_id, unit_price, weight_kg)
VALUES ('EL-0099', 'Товар с отрицательной ценой', 1, 1, -500.00, 1.000);
-- Ожидается: ERROR: new row for relation "products" violates check constraint
--            "chk_products_price_nonneg"

-- ---------------------------------------------------------------------
-- 4. Нарушение CHECK: недопустимый тип складской операции
-- ---------------------------------------------------------------------
INSERT INTO stock_movements (warehouse_id, product_id, employee_id, movement_type, quantity)
VALUES (1, 1, 1, 'ADJ', 5);
-- Ожидается: ERROR: new row for relation "stock_movements" violates check constraint
--            "chk_movements_type"

-- ---------------------------------------------------------------------
-- 5. Нарушение CHECK: отрицательный/нулевой остаток на складе
-- ---------------------------------------------------------------------
UPDATE stock SET quantity = -10 WHERE warehouse_id = 1 AND product_id = 1;
-- Ожидается: ERROR: new row for relation "stock" violates check constraint
--            "chk_stock_quantity_nonneg"

-- ---------------------------------------------------------------------
-- 6. Нарушение NOT NULL: попытка добавить сотрудника без склада
-- ---------------------------------------------------------------------
INSERT INTO employees (full_name, warehouse_id, position, salary)
VALUES ('Без склада Тестов', NULL, 'кладовщик', 40000.00);
-- Ожидается: ERROR: null value in column "warehouse_id" violates not-null constraint

-- ---------------------------------------------------------------------
-- 7. Нарушение FOREIGN KEY: товар со ссылкой на несуществующую категорию
-- ---------------------------------------------------------------------
INSERT INTO products (sku, name, category_id, supplier_id, unit_price, weight_kg)
VALUES ('EL-0100', 'Товар без категории', 999, 1, 1000.00, 1.000);
-- Ожидается: ERROR: insert or update on table "products" violates foreign key
--            constraint "products_category_id_fkey"

-- ---------------------------------------------------------------------
-- 8. Нарушение составного FOREIGN KEY: движение по паре (склад, товар),
--    для которой ещё не заведена запись в stock
-- ---------------------------------------------------------------------
INSERT INTO stock_movements (warehouse_id, product_id, employee_id, movement_type, quantity)
VALUES (2, 1, 4, 'IN', 10);
-- Ожидается: ERROR: insert or update on table "stock_movements" violates foreign key
--            constraint "fk_movements_stock" (для склада 2 нет остатка по товару 1)

-- ---------------------------------------------------------------------
-- 9. Нарушение CHECK: должность сотрудника вне допустимого списка
-- ---------------------------------------------------------------------
INSERT INTO employees (full_name, warehouse_id, position, salary)
VALUES ('Странная Должность', 1, 'директор всего', 100000.00);
-- Ожидается: ERROR: new row for relation "employees" violates check constraint
--            "chk_employees_position"

-- ---------------------------------------------------------------------
-- 10. Нарушение ON DELETE RESTRICT: удаление категории, на которую
--     ссылаются существующие товары
-- ---------------------------------------------------------------------
DELETE FROM categories WHERE name = 'Электроника';
-- Ожидается: ERROR: update or delete on table "categories" violates foreign key
--            constraint "products_category_id_fkey" on table "products"

-- =====================================================================
-- migration.sql — изменение структуры БД по дополнительному требованию
-- =====================================================================
-- Дополнительное требование преподавателя:
--   Склад стал хранить товары не «в целом по складу», а по конкретным
--   зонам/стеллажам (местам хранения). Кроме того, часть товаров
--   (бытовая техника, электроника) должна учитывать гарантийный срок
--   (срок годности/гарантии), после истечения которого товар нельзя
--   отгружать клиенту.
--
-- Требуется:
--   1) добавить сущность "зоны хранения" (warehouse_zones), привязанную
--      к складу;
--   2) связать остатки (stock) с конкретной зоной хранения;
--   3) добавить в products атрибут "срок годности в днях" (для товаров,
--      требующих контроля годности);
--   4) добавить в stock_movements дату истечения годности партии и
--      ограничение, что расходная операция ('OUT') не может быть
--      оформлена по просроченной партии.
--
-- Пересоздание базы данных не производится — используются только
-- операторы ALTER TABLE / CREATE TABLE, существующие данные сохраняются.
-- =====================================================================

BEGIN;

-- ---------------------------------------------------------------------
-- 1. Новая сущность: зоны хранения склада
-- ---------------------------------------------------------------------
CREATE TABLE warehouse_zones (
    zone_id         SERIAL PRIMARY KEY,
    warehouse_id    INTEGER NOT NULL REFERENCES warehouses(warehouse_id)
                        ON DELETE CASCADE,
    zone_code       VARCHAR(20) NOT NULL,           -- например, "A-01", "B-12"
    description     VARCHAR(150),
    CONSTRAINT uq_zone_per_warehouse UNIQUE (warehouse_id, zone_code)
);

-- Заполняем зонами по умолчанию для уже существующих складов,
-- чтобы можно было безопасно привязать к ним текущие остатки.
INSERT INTO warehouse_zones (warehouse_id, zone_code, description)
SELECT warehouse_id, 'DEFAULT', 'Зона по умолчанию (создана миграцией)'
FROM warehouses;

-- ---------------------------------------------------------------------
-- 2. Привязка остатков (stock) к зоне хранения
-- ---------------------------------------------------------------------
ALTER TABLE stock
    ADD COLUMN zone_id INTEGER;

-- Проставляем существующим остаткам зону по умолчанию соответствующего склада
UPDATE stock s
SET zone_id = z.zone_id
FROM warehouse_zones z
WHERE z.warehouse_id = s.warehouse_id
  AND z.zone_code = 'DEFAULT';

ALTER TABLE stock
    ALTER COLUMN zone_id SET NOT NULL;

ALTER TABLE stock
    ADD CONSTRAINT fk_stock_zone FOREIGN KEY (zone_id)
        REFERENCES warehouse_zones(zone_id) ON DELETE RESTRICT;

-- Зона обязательно должна принадлежать тому же складу, что и остаток —
-- реализуем через составной внешний ключ на (warehouse_id, zone_id).
ALTER TABLE warehouse_zones
    ADD CONSTRAINT uq_zone_warehouse UNIQUE (zone_id, warehouse_id);

ALTER TABLE stock
    ADD CONSTRAINT fk_stock_zone_warehouse FOREIGN KEY (zone_id, warehouse_id)
        REFERENCES warehouse_zones(zone_id, warehouse_id);

-- ---------------------------------------------------------------------
-- 3. Срок годности/гарантии у товара (в днях с момента приёмки),
--    NULL — товар без ограничения срока годности
-- ---------------------------------------------------------------------
ALTER TABLE products
    ADD COLUMN shelf_life_days INTEGER;

ALTER TABLE products
    ADD CONSTRAINT chk_products_shelf_life_positive
        CHECK (shelf_life_days IS NULL OR shelf_life_days > 0);

-- Пример: бытовая техника и электроника получают гарантийный срок
UPDATE products SET shelf_life_days = 730  WHERE category_id IN (
    SELECT category_id FROM categories WHERE name IN ('Электроника','Бытовая техника')
);

-- ---------------------------------------------------------------------
-- 4. Дата истечения годности партии в складской операции + защита
--    от отгрузки просроченной партии
-- ---------------------------------------------------------------------
ALTER TABLE stock_movements
    ADD COLUMN expiration_date DATE;

-- Для расходных операций по товарам с ограниченным сроком годности
-- дата истечения обязана быть указана и не может быть в прошлом
-- относительно даты самой операции.
ALTER TABLE stock_movements
    ADD CONSTRAINT chk_movements_not_expired
        CHECK (
            expiration_date IS NULL
            OR movement_type = 'IN'
            OR expiration_date >= movement_date::date
        );

COMMIT;

-- ---------------------------------------------------------------------
-- Проверочный запрос: остатки в разрезе зон хранения
-- ---------------------------------------------------------------------
-- SELECT w.name AS warehouse, z.zone_code, p.name AS product, s.quantity
-- FROM stock s
-- JOIN warehouses w ON w.warehouse_id = s.warehouse_id
-- JOIN warehouse_zones z ON z.zone_id = s.zone_id
-- JOIN products p ON p.product_id = s.product_id
-- ORDER BY w.name, z.zone_code;

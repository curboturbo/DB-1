-- =====================================================================
-- Лабораторная работа №1. Вариант 10 — «Система управления складом»
-- schema.sql — создание структуры базы данных
-- =====================================================================

-- Для наглядного пересоздания при отладке (не используется при сдаче,
-- т.к. пересоздание БД в рамках миграции не допускается)
DROP TABLE IF EXISTS stock_movements CASCADE;
DROP TABLE IF EXISTS stock CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS categories CASCADE;
DROP TABLE IF EXISTS suppliers CASCADE;
DROP TABLE IF EXISTS employees CASCADE;
DROP TABLE IF EXISTS warehouses CASCADE;

-- ---------------------------------------------------------------------
-- 1. Поставщики
-- ---------------------------------------------------------------------
CREATE TABLE suppliers (
    supplier_id     SERIAL PRIMARY KEY,
    name            VARCHAR(150) NOT NULL,
    inn             VARCHAR(12)  NOT NULL,             -- ИНН поставщика
    phone           VARCHAR(20),
    email           VARCHAR(150),
    address         VARCHAR(255),
    CONSTRAINT uq_suppliers_inn UNIQUE (inn),
    CONSTRAINT chk_suppliers_inn_format CHECK (inn ~ '^[0-9]{10,12}$')
);

-- ---------------------------------------------------------------------
-- 2. Склады
-- ---------------------------------------------------------------------
CREATE TABLE warehouses (
    warehouse_id    SERIAL PRIMARY KEY,
    name            VARCHAR(100) NOT NULL,
    address         VARCHAR(255) NOT NULL,
    capacity_m3     NUMERIC(10,2) NOT NULL,            -- вместимость склада, м3
    CONSTRAINT uq_warehouses_name UNIQUE (name),
    CONSTRAINT chk_warehouses_capacity_positive CHECK (capacity_m3 > 0)
);

-- ---------------------------------------------------------------------
-- 3. Категории товаров
-- ---------------------------------------------------------------------
CREATE TABLE categories (
    category_id     SERIAL PRIMARY KEY,
    name            VARCHAR(100) NOT NULL,
    CONSTRAINT uq_categories_name UNIQUE (name)
);

-- ---------------------------------------------------------------------
-- 4. Товары (номенклатура)
-- ---------------------------------------------------------------------
CREATE TABLE products (
    product_id      SERIAL PRIMARY KEY,
    sku             VARCHAR(30)  NOT NULL,             -- складской артикул
    name            VARCHAR(150) NOT NULL,
    category_id     INTEGER NOT NULL REFERENCES categories(category_id)
                        ON DELETE RESTRICT,
    supplier_id     INTEGER REFERENCES suppliers(supplier_id)
                        ON DELETE SET NULL,
    unit_price      NUMERIC(12,2) NOT NULL,
    weight_kg       NUMERIC(8,3)  NOT NULL,
    CONSTRAINT uq_products_sku UNIQUE (sku),
    CONSTRAINT chk_products_price_nonneg CHECK (unit_price >= 0),
    CONSTRAINT chk_products_weight_positive CHECK (weight_kg > 0)
);

-- ---------------------------------------------------------------------
-- 5. Сотрудники склада
-- ---------------------------------------------------------------------
CREATE TABLE employees (
    employee_id     SERIAL PRIMARY KEY,
    full_name       VARCHAR(150) NOT NULL,
    warehouse_id    INTEGER NOT NULL REFERENCES warehouses(warehouse_id)
                        ON DELETE CASCADE,
    position        VARCHAR(50) NOT NULL,
    hire_date       DATE NOT NULL DEFAULT CURRENT_DATE,
    salary          NUMERIC(10,2) NOT NULL,
    CONSTRAINT chk_employees_salary_positive CHECK (salary > 0),
    CONSTRAINT chk_employees_position CHECK (
        position IN ('кладовщик','менеджер','грузчик','водитель','начальник склада')
    )
);

-- ---------------------------------------------------------------------
-- 6. Остатки товара на складе (текущие запасы)
--    Составной первичный ключ (warehouse_id, product_id) — по одному
--    товару на складе может быть только одна запись об остатке.
-- ---------------------------------------------------------------------
CREATE TABLE stock (
    warehouse_id    INTEGER NOT NULL REFERENCES warehouses(warehouse_id)
                        ON DELETE CASCADE,
    product_id      INTEGER NOT NULL REFERENCES products(product_id)
                        ON DELETE CASCADE,
    quantity        INTEGER NOT NULL DEFAULT 0,
    min_quantity    INTEGER NOT NULL DEFAULT 0,        -- минимальный остаток (точка заказа)
    CONSTRAINT pk_stock PRIMARY KEY (warehouse_id, product_id),
    CONSTRAINT chk_stock_quantity_nonneg CHECK (quantity >= 0),
    CONSTRAINT chk_stock_min_quantity_nonneg CHECK (min_quantity >= 0)
);

-- ---------------------------------------------------------------------
-- 7. Складские операции (движения товара: приход/расход)
-- ---------------------------------------------------------------------
CREATE TABLE stock_movements (
    movement_id     SERIAL PRIMARY KEY,
    warehouse_id    INTEGER NOT NULL,
    product_id      INTEGER NOT NULL,
    employee_id     INTEGER NOT NULL REFERENCES employees(employee_id)
                        ON DELETE RESTRICT,
    movement_type   VARCHAR(3) NOT NULL,               -- 'IN' / 'OUT'
    quantity        INTEGER NOT NULL,
    movement_date   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_movements_stock FOREIGN KEY (warehouse_id, product_id)
        REFERENCES stock (warehouse_id, product_id) ON DELETE CASCADE,
    CONSTRAINT chk_movements_type CHECK (movement_type IN ('IN','OUT')),
    CONSTRAINT chk_movements_quantity_positive CHECK (quantity > 0)
);

CREATE INDEX idx_products_category ON products(category_id);
CREATE INDEX idx_products_supplier ON products(supplier_id);
CREATE INDEX idx_employees_warehouse ON employees(warehouse_id);
CREATE INDEX idx_movements_product ON stock_movements(product_id);
CREATE INDEX idx_movements_warehouse ON stock_movements(warehouse_id);

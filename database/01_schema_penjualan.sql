-- =========================================================
-- 01_schema_penjualan.sql
-- Aplikasi Pengelolaan Data Penjualan
-- PostgreSQL + Django + DBeaver
--
-- Cara pakai:
-- 1. Buat database bernama db_penjualan terlebih dahulu.
-- 2. Hubungkan DBeaver ke database db_penjualan.
-- 3. Jalankan/import seluruh isi file ini.
-- =========================================================

BEGIN;

-- =========================================================
-- 1. SCHEMA
-- =========================================================
CREATE SCHEMA IF NOT EXISTS sales_app;

SET search_path TO sales_app, public;

-- =========================================================
-- 2. TABLE: customers
-- =========================================================
CREATE TABLE IF NOT EXISTS sales_app.customers (
    customer_id BIGSERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    phone VARCHAR(20),
    address TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- =========================================================
-- 3. TABLE: products
-- =========================================================
CREATE TABLE IF NOT EXISTS sales_app.products (
    product_id BIGSERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    price NUMERIC(12,2) NOT NULL,
    stock INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_products_price
        CHECK (price >= 0),

    CONSTRAINT chk_products_stock
        CHECK (stock >= 0)
);

-- =========================================================
-- 4. TABLE: sales
-- =========================================================
CREATE TABLE IF NOT EXISTS sales_app.sales (
    sale_id BIGSERIAL PRIMARY KEY,
    customer_id BIGINT NOT NULL,
    sale_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    total_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
    status VARCHAR(20) NOT NULL DEFAULT 'COMPLETED',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_sales_customer
        FOREIGN KEY (customer_id)
        REFERENCES sales_app.customers(customer_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT chk_sales_total
        CHECK (total_amount >= 0),

    CONSTRAINT chk_sales_status
        CHECK (status IN ('COMPLETED', 'CANCELLED'))
);

-- =========================================================
-- 5. TABLE: sale_items
-- =========================================================
CREATE TABLE IF NOT EXISTS sales_app.sale_items (
    sale_item_id BIGSERIAL PRIMARY KEY,
    sale_id BIGINT NOT NULL,
    product_id BIGINT NOT NULL,
    quantity INTEGER NOT NULL,
    price NUMERIC(12,2) NOT NULL,
    subtotal NUMERIC(12,2) NOT NULL,

    CONSTRAINT fk_sale_items_sale
        FOREIGN KEY (sale_id)
        REFERENCES sales_app.sales(sale_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,

    CONSTRAINT fk_sale_items_product
        FOREIGN KEY (product_id)
        REFERENCES sales_app.products(product_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT chk_sale_items_quantity
        CHECK (quantity > 0),

    CONSTRAINT chk_sale_items_price
        CHECK (price >= 0),

    CONSTRAINT chk_sale_items_subtotal
        CHECK (subtotal >= 0),

    CONSTRAINT uq_sale_product
        UNIQUE (sale_id, product_id)
);

-- =========================================================
-- 6. TABLE: audit_logs
-- =========================================================
CREATE TABLE IF NOT EXISTS sales_app.audit_logs (
    audit_id BIGSERIAL PRIMARY KEY,
    table_name VARCHAR(50) NOT NULL,
    record_id BIGINT,
    action VARCHAR(10) NOT NULL,
    old_data JSONB,
    new_data JSONB,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_audit_action
        CHECK (action IN ('INSERT', 'UPDATE', 'DELETE'))
);

-- =========================================================
-- 7. INDEX
-- =========================================================
CREATE INDEX IF NOT EXISTS idx_customers_name
    ON sales_app.customers(name);

CREATE INDEX IF NOT EXISTS idx_products_name
    ON sales_app.products(name);

CREATE INDEX IF NOT EXISTS idx_sales_customer
    ON sales_app.sales(customer_id);

CREATE INDEX IF NOT EXISTS idx_sales_date
    ON sales_app.sales(sale_date);

CREATE INDEX IF NOT EXISTS idx_sale_items_sale
    ON sales_app.sale_items(sale_id);

CREATE INDEX IF NOT EXISTS idx_sale_items_product
    ON sales_app.sale_items(product_id);

CREATE INDEX IF NOT EXISTS idx_audit_table_record
    ON sales_app.audit_logs(table_name, record_id);

-- =========================================================
-- 8. DATA AWAL UNTUK PENGUJIAN
-- =========================================================
-- Hanya dimasukkan jika tabel masih kosong.

INSERT INTO sales_app.customers (name, phone, address)
SELECT 'Budi', '081234567890', 'Depok'
WHERE NOT EXISTS (
    SELECT 1 FROM sales_app.customers
);

INSERT INTO sales_app.customers (name, phone, address)
SELECT 'Siti', '081298765432', 'Jakarta'
WHERE NOT EXISTS (
    SELECT 1
    FROM sales_app.customers
    WHERE name = 'Siti'
      AND phone = '081298765432'
);

INSERT INTO sales_app.products (name, price, stock)
SELECT 'Mouse Wireless', 150000, 20
WHERE NOT EXISTS (
    SELECT 1
    FROM sales_app.products
    WHERE name = 'Mouse Wireless'
);

INSERT INTO sales_app.products (name, price, stock)
SELECT 'Keyboard Mechanical', 450000, 10
WHERE NOT EXISTS (
    SELECT 1
    FROM sales_app.products
    WHERE name = 'Keyboard Mechanical'
);

INSERT INTO sales_app.products (name, price, stock)
SELECT 'Flashdisk 64GB', 100000, 30
WHERE NOT EXISTS (
    SELECT 1
    FROM sales_app.products
    WHERE name = 'Flashdisk 64GB'
);

COMMIT;

-- =========================================================
-- CEK HASIL
-- =========================================================
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'sales_app'
ORDER BY table_name;

SELECT * FROM sales_app.customers ORDER BY customer_id;
SELECT * FROM sales_app.products ORDER BY product_id;

-- =========================================================
-- 02_functions.sql
-- CRUD Pelanggan dan Produk
-- PostgreSQL / pgAdmin 4
-- =========================================================
-- Prasyarat:
--   01_schema_penjualan.sql sudah dijalankan
-- Database:
--   db_penjualan
-- Schema:
--   sales_app
-- =========================================================

SET search_path TO sales_app, public;

-- =========================================================
-- A. CUSTOMER FUNCTIONS
-- =========================================================

-- ---------------------------------------------------------
-- 1. Tambah pelanggan
-- ---------------------------------------------------------
CREATE OR REPLACE FUNCTION sales_app.fn_customer_add(
    p_name VARCHAR,
    p_phone VARCHAR DEFAULT NULL,
    p_address TEXT DEFAULT NULL
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    v_customer_id BIGINT;
BEGIN
    IF p_name IS NULL OR BTRIM(p_name) = '' THEN
        RAISE EXCEPTION 'Nama pelanggan wajib diisi';
    END IF;

    INSERT INTO sales_app.customers (
        name,
        phone,
        address
    )
    VALUES (
        BTRIM(p_name),
        NULLIF(BTRIM(p_phone), ''),
        NULLIF(BTRIM(p_address), '')
    )
    RETURNING customer_id
    INTO v_customer_id;

    RETURN v_customer_id;
END;
$$;


-- ---------------------------------------------------------
-- 2. Tampilkan seluruh pelanggan
-- ---------------------------------------------------------
CREATE OR REPLACE FUNCTION sales_app.fn_customer_get_all()
RETURNS TABLE (
    customer_id BIGINT,
    name VARCHAR,
    phone VARCHAR,
    address TEXT,
    created_at TIMESTAMP
)
LANGUAGE sql
AS $$
    SELECT
        c.customer_id,
        c.name,
        c.phone,
        c.address,
        c.created_at
    FROM sales_app.customers c
    ORDER BY c.customer_id;
$$;


-- ---------------------------------------------------------
-- 3. Cari pelanggan
--    Pencarian berdasarkan nama, telepon, atau alamat
-- ---------------------------------------------------------
CREATE OR REPLACE FUNCTION sales_app.fn_customer_search(
    p_keyword TEXT
)
RETURNS TABLE (
    customer_id BIGINT,
    name VARCHAR,
    phone VARCHAR,
    address TEXT,
    created_at TIMESTAMP
)
LANGUAGE sql
AS $$
    SELECT
        c.customer_id,
        c.name,
        c.phone,
        c.address,
        c.created_at
    FROM sales_app.customers c
    WHERE
        c.name ILIKE '%' || COALESCE(p_keyword, '') || '%'
        OR COALESCE(c.phone, '') ILIKE '%' || COALESCE(p_keyword, '') || '%'
        OR COALESCE(c.address, '') ILIKE '%' || COALESCE(p_keyword, '') || '%'
    ORDER BY c.customer_id;
$$;


-- ---------------------------------------------------------
-- 4. Ubah pelanggan
-- ---------------------------------------------------------
CREATE OR REPLACE FUNCTION sales_app.fn_customer_update(
    p_customer_id BIGINT,
    p_name VARCHAR,
    p_phone VARCHAR DEFAULT NULL,
    p_address TEXT DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
DECLARE
    v_rows INTEGER;
BEGIN
    IF p_customer_id IS NULL OR p_customer_id <= 0 THEN
        RAISE EXCEPTION 'Customer ID tidak valid';
    END IF;

    IF p_name IS NULL OR BTRIM(p_name) = '' THEN
        RAISE EXCEPTION 'Nama pelanggan wajib diisi';
    END IF;

    UPDATE sales_app.customers
    SET
        name = BTRIM(p_name),
        phone = NULLIF(BTRIM(p_phone), ''),
        address = NULLIF(BTRIM(p_address), '')
    WHERE customer_id = p_customer_id;

    GET DIAGNOSTICS v_rows = ROW_COUNT;

    IF v_rows = 0 THEN
        RAISE EXCEPTION 'Pelanggan dengan ID % tidak ditemukan', p_customer_id;
    END IF;

    RETURN TRUE;
END;
$$;


-- ---------------------------------------------------------
-- 5. Hapus pelanggan
-- ---------------------------------------------------------
CREATE OR REPLACE FUNCTION sales_app.fn_customer_delete(
    p_customer_id BIGINT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
DECLARE
    v_rows INTEGER;
BEGIN
    IF p_customer_id IS NULL OR p_customer_id <= 0 THEN
        RAISE EXCEPTION 'Customer ID tidak valid';
    END IF;

    DELETE FROM sales_app.customers
    WHERE customer_id = p_customer_id;

    GET DIAGNOSTICS v_rows = ROW_COUNT;

    IF v_rows = 0 THEN
        RAISE EXCEPTION 'Pelanggan dengan ID % tidak ditemukan', p_customer_id;
    END IF;

    RETURN TRUE;

EXCEPTION
    WHEN foreign_key_violation THEN
        RAISE EXCEPTION
            'Pelanggan ID % tidak dapat dihapus karena sudah memiliki transaksi',
            p_customer_id;
END;
$$;


-- =========================================================
-- B. PRODUCT FUNCTIONS
-- =========================================================

-- ---------------------------------------------------------
-- 6. Tambah produk
-- ---------------------------------------------------------
CREATE OR REPLACE FUNCTION sales_app.fn_product_add(
    p_name VARCHAR,
    p_price NUMERIC,
    p_stock INTEGER
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    v_product_id BIGINT;
BEGIN
    IF p_name IS NULL OR BTRIM(p_name) = '' THEN
        RAISE EXCEPTION 'Nama produk wajib diisi';
    END IF;

    IF p_price IS NULL OR p_price < 0 THEN
        RAISE EXCEPTION 'Harga produk tidak boleh negatif';
    END IF;

    IF p_stock IS NULL OR p_stock < 0 THEN
        RAISE EXCEPTION 'Stok produk tidak boleh negatif';
    END IF;

    INSERT INTO sales_app.products (
        name,
        price,
        stock
    )
    VALUES (
        BTRIM(p_name),
        p_price,
        p_stock
    )
    RETURNING product_id
    INTO v_product_id;

    RETURN v_product_id;
END;
$$;


-- ---------------------------------------------------------
-- 7. Tampilkan seluruh produk
-- ---------------------------------------------------------
CREATE OR REPLACE FUNCTION sales_app.fn_product_get_all()
RETURNS TABLE (
    product_id BIGINT,
    name VARCHAR,
    price NUMERIC,
    stock INTEGER,
    created_at TIMESTAMP
)
LANGUAGE sql
AS $$
    SELECT
        p.product_id,
        p.name,
        p.price,
        p.stock,
        p.created_at
    FROM sales_app.products p
    ORDER BY p.product_id;
$$;


-- ---------------------------------------------------------
-- 8. Cari produk
-- ---------------------------------------------------------
CREATE OR REPLACE FUNCTION sales_app.fn_product_search(
    p_keyword TEXT
)
RETURNS TABLE (
    product_id BIGINT,
    name VARCHAR,
    price NUMERIC,
    stock INTEGER,
    created_at TIMESTAMP
)
LANGUAGE sql
AS $$
    SELECT
        p.product_id,
        p.name,
        p.price,
        p.stock,
        p.created_at
    FROM sales_app.products p
    WHERE p.name ILIKE '%' || COALESCE(p_keyword, '') || '%'
    ORDER BY p.product_id;
$$;


-- ---------------------------------------------------------
-- 9. Ubah produk
-- ---------------------------------------------------------
CREATE OR REPLACE FUNCTION sales_app.fn_product_update(
    p_product_id BIGINT,
    p_name VARCHAR,
    p_price NUMERIC,
    p_stock INTEGER
)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
DECLARE
    v_rows INTEGER;
BEGIN
    IF p_product_id IS NULL OR p_product_id <= 0 THEN
        RAISE EXCEPTION 'Product ID tidak valid';
    END IF;

    IF p_name IS NULL OR BTRIM(p_name) = '' THEN
        RAISE EXCEPTION 'Nama produk wajib diisi';
    END IF;

    IF p_price IS NULL OR p_price < 0 THEN
        RAISE EXCEPTION 'Harga produk tidak boleh negatif';
    END IF;

    IF p_stock IS NULL OR p_stock < 0 THEN
        RAISE EXCEPTION 'Stok produk tidak boleh negatif';
    END IF;

    UPDATE sales_app.products
    SET
        name = BTRIM(p_name),
        price = p_price,
        stock = p_stock
    WHERE product_id = p_product_id;

    GET DIAGNOSTICS v_rows = ROW_COUNT;

    IF v_rows = 0 THEN
        RAISE EXCEPTION 'Produk dengan ID % tidak ditemukan', p_product_id;
    END IF;

    RETURN TRUE;
END;
$$;


-- ---------------------------------------------------------
-- 10. Hapus produk
-- ---------------------------------------------------------
CREATE OR REPLACE FUNCTION sales_app.fn_product_delete(
    p_product_id BIGINT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
DECLARE
    v_rows INTEGER;
BEGIN
    IF p_product_id IS NULL OR p_product_id <= 0 THEN
        RAISE EXCEPTION 'Product ID tidak valid';
    END IF;

    DELETE FROM sales_app.products
    WHERE product_id = p_product_id;

    GET DIAGNOSTICS v_rows = ROW_COUNT;

    IF v_rows = 0 THEN
        RAISE EXCEPTION 'Produk dengan ID % tidak ditemukan', p_product_id;
    END IF;

    RETURN TRUE;

EXCEPTION
    WHEN foreign_key_violation THEN
        RAISE EXCEPTION
            'Produk ID % tidak dapat dihapus karena sudah digunakan dalam transaksi',
            p_product_id;
END;
$$;


-- =========================================================
-- C. CONTOH PENGUJIAN
-- =========================================================
-- Jalankan satu per satu jika ingin mengetes.
-- Baris di bawah sengaja dikomentari supaya tidak mengubah data
-- ketika file ini di-import.

-- Tambah pelanggan:
-- SELECT sales_app.fn_customer_add(
--     'Andi',
--     '081111111111',
--     'Bogor'
-- );

-- Tampilkan semua pelanggan:
-- SELECT * FROM sales_app.fn_customer_get_all();

-- Cari pelanggan:
-- SELECT * FROM sales_app.fn_customer_search('Budi');

-- Ubah pelanggan:
-- SELECT sales_app.fn_customer_update(
--     1,
--     'Budi Santoso',
--     '081234567890',
--     'Depok'
-- );

-- Hapus pelanggan:
-- SELECT sales_app.fn_customer_delete(3);


-- Tambah produk:
-- SELECT sales_app.fn_product_add(
--     'Monitor 24 Inch',
--     1500000,
--     5
-- );

-- Tampilkan semua produk:
-- SELECT * FROM sales_app.fn_product_get_all();

-- Cari produk:
-- SELECT * FROM sales_app.fn_product_search('Mouse');

-- Ubah produk:
-- SELECT sales_app.fn_product_update(
--     1,
--     'Mouse Wireless',
--     175000,
--     25
-- );

-- Hapus produk:
-- SELECT sales_app.fn_product_delete(4);


-- =========================================================
-- D. CEK FUNCTION YANG BERHASIL DIBUAT
-- =========================================================
SELECT
    routine_name,
    routine_type
FROM information_schema.routines
WHERE routine_schema = 'sales_app'
ORDER BY routine_name;

-- =========================================================
-- 03_transaction.sql
-- Transaksi Penjualan
-- PostgreSQL / pgAdmin 4
--
-- Mencakup:
-- - Stored function
-- - Stored procedure
-- - Percabangan IF
-- - Perulangan FOR
-- - Validasi stok
-- - SELECT ... FOR UPDATE
-- - Perhitungan subtotal & total
-- - Pengurangan stok
-- - Exception handling
-- - TCL: BEGIN / COMMIT / ROLLBACK
-- =========================================================

SET search_path TO sales_app, public;

-- =========================================================
-- A. FUNCTION TRANSAKSI PENJUALAN
-- =========================================================
-- Format p_items:
-- [
--   {"product_id": 1, "quantity": 2},
--   {"product_id": 2, "quantity": 1}
-- ]
--
-- Seluruh isi function berjalan atomik.
-- Jika terjadi exception, perubahan pada pemanggilan function
-- akan dibatalkan oleh PostgreSQL.
-- =========================================================

CREATE OR REPLACE FUNCTION sales_app.fn_create_sale(
    p_customer_id BIGINT,
    p_items JSONB
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    v_sale_id BIGINT;
    v_item JSONB;

    v_product_id BIGINT;
    v_quantity INTEGER;

    v_product_name VARCHAR(100);
    v_price NUMERIC(12,2);
    v_stock INTEGER;

    v_subtotal NUMERIC(12,2);
    v_total NUMERIC(12,2) := 0;
BEGIN
    -- -----------------------------------------------------
    -- 1. Validasi pelanggan
    -- -----------------------------------------------------
    IF p_customer_id IS NULL OR p_customer_id <= 0 THEN
        RAISE EXCEPTION 'Customer ID tidak valid';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM sales_app.customers
        WHERE customer_id = p_customer_id
    ) THEN
        RAISE EXCEPTION
            'Pelanggan dengan ID % tidak ditemukan',
            p_customer_id;
    END IF;

    -- -----------------------------------------------------
    -- 2. Validasi daftar item
    -- -----------------------------------------------------
    IF p_items IS NULL
       OR jsonb_typeof(p_items) <> 'array'
       OR jsonb_array_length(p_items) = 0
    THEN
        RAISE EXCEPTION
            'Daftar produk transaksi tidak boleh kosong';
    END IF;

    -- -----------------------------------------------------
    -- 3. Buat header transaksi
    -- -----------------------------------------------------
    INSERT INTO sales_app.sales (
        customer_id,
        total_amount,
        status
    )
    VALUES (
        p_customer_id,
        0,
        'COMPLETED'
    )
    RETURNING sale_id
    INTO v_sale_id;

    -- -----------------------------------------------------
    -- 4. Loop setiap produk
    -- -----------------------------------------------------
    FOR v_item IN
        SELECT value
        FROM jsonb_array_elements(p_items)
    LOOP
        -- Validasi field JSON
        IF NOT (v_item ? 'product_id')
           OR NOT (v_item ? 'quantity')
        THEN
            RAISE EXCEPTION
                'Setiap item wajib memiliki product_id dan quantity';
        END IF;

        BEGIN
            v_product_id := (v_item ->> 'product_id')::BIGINT;
            v_quantity := (v_item ->> 'quantity')::INTEGER;
        EXCEPTION
            WHEN invalid_text_representation THEN
                RAISE EXCEPTION
                    'product_id dan quantity harus berupa angka';
        END;

        IF v_product_id IS NULL OR v_product_id <= 0 THEN
            RAISE EXCEPTION 'Product ID tidak valid';
        END IF;

        IF v_quantity IS NULL OR v_quantity <= 0 THEN
            RAISE EXCEPTION
                'Quantity produk ID % harus lebih dari 0',
                v_product_id;
        END IF;

        -- -----------------------------------------------
        -- Ambil produk dan lock row untuk menjaga stok
        -- selama transaksi berlangsung.
        -- -----------------------------------------------
        SELECT
            p.name,
            p.price,
            p.stock
        INTO
            v_product_name,
            v_price,
            v_stock
        FROM sales_app.products p
        WHERE p.product_id = v_product_id
        FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION
                'Produk dengan ID % tidak ditemukan',
                v_product_id;
        END IF;

        -- -----------------------------------------------
        -- Validasi stok
        -- -----------------------------------------------
        IF v_stock < v_quantity THEN
            RAISE EXCEPTION
                'Stok produk "%" tidak mencukupi. Stok tersedia: %, diminta: %',
                v_product_name,
                v_stock,
                v_quantity;
        END IF;

        -- -----------------------------------------------
        -- Hitung subtotal
        -- -----------------------------------------------
        v_subtotal := v_price * v_quantity;

        -- -----------------------------------------------
        -- Simpan detail transaksi
        -- -----------------------------------------------
        INSERT INTO sales_app.sale_items (
            sale_id,
            product_id,
            quantity,
            price,
            subtotal
        )
        VALUES (
            v_sale_id,
            v_product_id,
            v_quantity,
            v_price,
            v_subtotal
        );

        -- -----------------------------------------------
        -- Kurangi stok
        -- -----------------------------------------------
        UPDATE sales_app.products
        SET stock = stock - v_quantity
        WHERE product_id = v_product_id;

        -- -----------------------------------------------
        -- Tambahkan subtotal ke total transaksi
        -- -----------------------------------------------
        v_total := v_total + v_subtotal;
    END LOOP;

    -- -----------------------------------------------------
    -- 5. Simpan total transaksi
    -- -----------------------------------------------------
    UPDATE sales_app.sales
    SET total_amount = v_total
    WHERE sale_id = v_sale_id;

    RETURN v_sale_id;

EXCEPTION
    WHEN unique_violation THEN
        RAISE EXCEPTION
            'Produk yang sama tidak boleh dimasukkan dua kali dalam satu transaksi';

    WHEN OTHERS THEN
        RAISE;
END;
$$;


-- =========================================================
-- B. STORED PROCEDURE
-- =========================================================
-- Procedure ini dibuat agar proyek juga mendemonstrasikan
-- penggunaan stored procedure.
--
-- Contoh:
-- CALL sales_app.sp_create_sale(
--     1,
--     '[{"product_id":1,"quantity":2}]'::jsonb,
--     NULL
-- );
-- =========================================================

CREATE OR REPLACE PROCEDURE sales_app.sp_create_sale(
    IN p_customer_id BIGINT,
    IN p_items JSONB,
    INOUT p_sale_id BIGINT
)
LANGUAGE plpgsql
AS $$
BEGIN
    p_sale_id := sales_app.fn_create_sale(
        p_customer_id,
        p_items
    );
END;
$$;


-- =========================================================
-- C. FUNCTION BATAL TRANSAKSI
-- =========================================================
-- Mengembalikan stok lalu mengubah status menjadi CANCELLED.
-- Function ini juga menggunakan FOR LOOP dan SELECT FOR UPDATE.
-- =========================================================

CREATE OR REPLACE FUNCTION sales_app.fn_cancel_sale(
    p_sale_id BIGINT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
DECLARE
    v_status VARCHAR(20);
    v_item RECORD;
BEGIN
    IF p_sale_id IS NULL OR p_sale_id <= 0 THEN
        RAISE EXCEPTION 'Sale ID tidak valid';
    END IF;

    SELECT s.status
    INTO v_status
    FROM sales_app.sales s
    WHERE s.sale_id = p_sale_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'Transaksi dengan ID % tidak ditemukan',
            p_sale_id;
    END IF;

    IF v_status = 'CANCELLED' THEN
        RAISE EXCEPTION
            'Transaksi ID % sudah dibatalkan',
            p_sale_id;
    END IF;

    -- Kembalikan stok untuk setiap detail transaksi
    FOR v_item IN
        SELECT
            si.product_id,
            si.quantity
        FROM sales_app.sale_items si
        WHERE si.sale_id = p_sale_id
    LOOP
        UPDATE sales_app.products
        SET stock = stock + v_item.quantity
        WHERE product_id = v_item.product_id;
    END LOOP;

    UPDATE sales_app.sales
    SET status = 'CANCELLED'
    WHERE sale_id = p_sale_id;

    RETURN TRUE;
END;
$$;


-- =========================================================
-- D. FUNCTION DETAIL TRANSAKSI
-- =========================================================

CREATE OR REPLACE FUNCTION sales_app.fn_sale_detail(
    p_sale_id BIGINT
)
RETURNS TABLE (
    sale_id BIGINT,
    sale_date TIMESTAMP,
    customer_name VARCHAR,
    status VARCHAR,
    product_name VARCHAR,
    quantity INTEGER,
    price NUMERIC,
    subtotal NUMERIC,
    total_amount NUMERIC
)
LANGUAGE sql
AS $$
    SELECT
        s.sale_id,
        s.sale_date,
        c.name AS customer_name,
        s.status,
        p.name AS product_name,
        si.quantity,
        si.price,
        si.subtotal,
        s.total_amount
    FROM sales_app.sales s
    JOIN sales_app.customers c
        ON c.customer_id = s.customer_id
    JOIN sales_app.sale_items si
        ON si.sale_id = s.sale_id
    JOIN sales_app.products p
        ON p.product_id = si.product_id
    WHERE s.sale_id = p_sale_id
    ORDER BY si.sale_item_id;
$$;


-- =========================================================
-- E. CONTOH PENGUJIAN
-- =========================================================
-- Baris contoh sengaja dikomentari agar saat file di-import
-- tidak otomatis membuat transaksi.
--
-- ---------------------------------------------------------
-- Contoh 1: Function transaksi satu produk
-- ---------------------------------------------------------
-- SELECT sales_app.fn_create_sale(
--     1,
--     '[
--        {"product_id": 1, "quantity": 2}
--      ]'::jsonb
-- );
--
-- ---------------------------------------------------------
-- Contoh 2: Function transaksi beberapa produk
-- ---------------------------------------------------------
-- SELECT sales_app.fn_create_sale(
--     1,
--     '[
--        {"product_id": 1, "quantity": 2},
--        {"product_id": 2, "quantity": 1}
--      ]'::jsonb
-- );
--
-- ---------------------------------------------------------
-- Contoh 3: Stored procedure
-- ---------------------------------------------------------
-- CALL sales_app.sp_create_sale(
--     1,
--     '[
--        {"product_id": 3, "quantity": 2}
--      ]'::jsonb,
--     NULL
-- );
--
-- ---------------------------------------------------------
-- Lihat detail transaksi
-- ---------------------------------------------------------
-- SELECT * FROM sales_app.fn_sale_detail(1);
--
-- ---------------------------------------------------------
-- Batalkan transaksi
-- ---------------------------------------------------------
-- SELECT sales_app.fn_cancel_sale(1);


-- =========================================================
-- F. CONTOH TCL: BEGIN / COMMIT / ROLLBACK
-- =========================================================
-- PostgreSQL function dijalankan dalam transaksi database.
-- Untuk demonstrasi asesmen, jalankan contoh berikut satu
-- per satu di Query Tool pgAdmin.
--
-- ---------------------------------------------------------
-- COMMIT
-- ---------------------------------------------------------
-- BEGIN;
--
-- SELECT sales_app.fn_create_sale(
--     1,
--     '[
--        {"product_id": 1, "quantity": 1}
--      ]'::jsonb
-- );
--
-- COMMIT;
--
-- ---------------------------------------------------------
-- ROLLBACK
-- ---------------------------------------------------------
-- BEGIN;
--
-- SELECT sales_app.fn_create_sale(
--     1,
--     '[
--        {"product_id": 1, "quantity": 1}
--      ]'::jsonb
-- );
--
-- -- Cek perubahan sementara:
-- SELECT * FROM sales_app.sales ORDER BY sale_id DESC;
-- SELECT * FROM sales_app.products ORDER BY product_id;
--
-- ROLLBACK;


-- =========================================================
-- G. CEK OBJECT YANG DIBUAT
-- =========================================================

SELECT
    routine_name,
    routine_type
FROM information_schema.routines
WHERE routine_schema = 'sales_app'
ORDER BY routine_name;

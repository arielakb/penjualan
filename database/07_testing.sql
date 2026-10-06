-- =========================================================
-- 07_testing.sql
-- Pengujian Lengkap Database Aplikasi Penjualan
-- PostgreSQL / pgAdmin 4
--
-- Prasyarat:
--   01_schema_penjualan.sql
--   02_functions.sql
--   03_transaction.sql
--   04_triggers.sql
--   05_views.sql
--   06_roles_security.sql
--
-- Tujuan:
-- - Menguji CRUD melalui function
-- - Menguji transaksi penjualan
-- - Menguji validasi stok & exception
-- - Menguji pembatalan transaksi
-- - Menguji trigger & audit trail
-- - Menguji view & laporan
-- - Menguji cursor
-- - Mendemonstrasikan COMMIT / ROLLBACK
-- - Menguji pembatasan akses user Django
--
-- CATATAN:
-- Sebagian besar pengujian dibungkus BEGIN ... ROLLBACK agar
-- data utama tidak berubah setelah pengujian selesai.
-- =========================================================

SET search_path TO sales_app, public;

-- =========================================================
-- A. PRE-CHECK: PASTIKAN OBJEK DATABASE TERSEDIA
-- =========================================================

SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'sales_app'
ORDER BY table_name;

SELECT routine_name, routine_type
FROM information_schema.routines
WHERE routine_schema = 'sales_app'
ORDER BY routine_name;

SELECT table_name AS view_name
FROM information_schema.views
WHERE table_schema = 'sales_app'
ORDER BY table_name;

SELECT
    event_object_table AS table_name,
    trigger_name,
    event_manipulation AS event
FROM information_schema.triggers
WHERE trigger_schema = 'sales_app'
ORDER BY event_object_table, trigger_name, event_manipulation;


-- =========================================================
-- B. TEST CRUD CUSTOMER
-- =========================================================
-- Semua perubahan akan dibatalkan dengan ROLLBACK.

BEGIN;

DO $$
DECLARE
    v_id BIGINT;
    v_name VARCHAR(100);
BEGIN
    -- CREATE
    v_id := sales_app.fn_customer_add(
        'Customer Test Assessment',
        '080000000001',
        'Alamat Test'
    );

    IF v_id IS NULL THEN
        RAISE EXCEPTION 'TEST GAGAL: fn_customer_add tidak mengembalikan ID';
    END IF;

    RAISE NOTICE 'PASS: customer berhasil ditambahkan, ID=%', v_id;

    -- READ / SEARCH
    SELECT c.name
    INTO v_name
    FROM sales_app.fn_customer_search('Customer Test Assessment') c
    WHERE c.customer_id = v_id;

    IF v_name IS NULL THEN
        RAISE EXCEPTION 'TEST GAGAL: customer tidak ditemukan melalui search';
    END IF;

    RAISE NOTICE 'PASS: customer berhasil dicari';

    -- UPDATE
    PERFORM sales_app.fn_customer_update(
        v_id,
        'Customer Test Updated',
        '080000000002',
        'Alamat Updated'
    );

    SELECT c.name
    INTO v_name
    FROM sales_app.fn_customer_get_all() c
    WHERE c.customer_id = v_id;

    IF v_name <> 'Customer Test Updated' THEN
        RAISE EXCEPTION 'TEST GAGAL: update customer tidak tersimpan';
    END IF;

    RAISE NOTICE 'PASS: customer berhasil diubah';

    -- DELETE
    PERFORM sales_app.fn_customer_delete(v_id);

    IF EXISTS (
        SELECT 1
        FROM sales_app.customers
        WHERE customer_id = v_id
    ) THEN
        RAISE EXCEPTION 'TEST GAGAL: customer masih ada setelah delete';
    END IF;

    RAISE NOTICE 'PASS: customer berhasil dihapus';
END
$$;

ROLLBACK;


-- =========================================================
-- C. TEST CRUD PRODUCT
-- =========================================================

BEGIN;

DO $$
DECLARE
    v_id BIGINT;
    v_price NUMERIC(12,2);
BEGIN
    -- CREATE
    v_id := sales_app.fn_product_add(
        'Produk Test Assessment',
        25000,
        10
    );

    IF v_id IS NULL THEN
        RAISE EXCEPTION 'TEST GAGAL: fn_product_add tidak mengembalikan ID';
    END IF;

    RAISE NOTICE 'PASS: produk berhasil ditambahkan, ID=%', v_id;

    -- READ / SEARCH
    IF NOT EXISTS (
        SELECT 1
        FROM sales_app.fn_product_search('Produk Test Assessment') p
        WHERE p.product_id = v_id
    ) THEN
        RAISE EXCEPTION 'TEST GAGAL: produk tidak ditemukan melalui search';
    END IF;

    RAISE NOTICE 'PASS: produk berhasil dicari';

    -- UPDATE
    PERFORM sales_app.fn_product_update(
        v_id,
        'Produk Test Updated',
        30000,
        15
    );

    SELECT p.price
    INTO v_price
    FROM sales_app.fn_product_get_all() p
    WHERE p.product_id = v_id;

    IF v_price <> 30000 THEN
        RAISE EXCEPTION 'TEST GAGAL: update produk tidak tersimpan';
    END IF;

    RAISE NOTICE 'PASS: produk berhasil diubah';

    -- DELETE
    PERFORM sales_app.fn_product_delete(v_id);

    IF EXISTS (
        SELECT 1
        FROM sales_app.products
        WHERE product_id = v_id
    ) THEN
        RAISE EXCEPTION 'TEST GAGAL: produk masih ada setelah delete';
    END IF;

    RAISE NOTICE 'PASS: produk berhasil dihapus';
END
$$;

ROLLBACK;


-- =========================================================
-- D. TEST TRANSAKSI PENJUALAN
-- =========================================================
-- Menggunakan customer dan dua produk yang sudah ada.
-- Script memilih data secara dinamis agar tidak bergantung pada ID 1.

BEGIN;

DO $$
DECLARE
    v_customer_id BIGINT;
    v_product_1 BIGINT;
    v_product_2 BIGINT;

    v_stock_1_before INTEGER;
    v_stock_2_before INTEGER;
    v_stock_1_after INTEGER;
    v_stock_2_after INTEGER;

    v_price_1 NUMERIC(12,2);
    v_price_2 NUMERIC(12,2);

    v_sale_id BIGINT;
    v_total NUMERIC(12,2);
    v_expected_total NUMERIC(12,2);
    v_status VARCHAR(20);
BEGIN
    SELECT customer_id
    INTO v_customer_id
    FROM sales_app.customers
    ORDER BY customer_id
    LIMIT 1;

    IF v_customer_id IS NULL THEN
        RAISE EXCEPTION 'TEST GAGAL: tidak ada customer untuk pengujian';
    END IF;

    SELECT product_id, stock, price
    INTO v_product_1, v_stock_1_before, v_price_1
    FROM sales_app.products
    WHERE stock >= 1
    ORDER BY product_id
    LIMIT 1;

    SELECT product_id, stock, price
    INTO v_product_2, v_stock_2_before, v_price_2
    FROM sales_app.products
    WHERE stock >= 1
      AND product_id <> v_product_1
    ORDER BY product_id
    LIMIT 1;

    IF v_product_1 IS NULL OR v_product_2 IS NULL THEN
        RAISE EXCEPTION 'TEST GAGAL: minimal dibutuhkan 2 produk dengan stok >= 1';
    END IF;

    -- Membuat transaksi: masing-masing 1 item.
    v_sale_id := sales_app.fn_create_sale(
        v_customer_id,
        jsonb_build_array(
            jsonb_build_object(
                'product_id', v_product_1,
                'quantity', 1
            ),
            jsonb_build_object(
                'product_id', v_product_2,
                'quantity', 1
            )
        )
    );

    IF v_sale_id IS NULL THEN
        RAISE EXCEPTION 'TEST GAGAL: transaksi tidak mengembalikan sale_id';
    END IF;

    SELECT total_amount, status
    INTO v_total, v_status
    FROM sales_app.sales
    WHERE sale_id = v_sale_id;

    v_expected_total := v_price_1 + v_price_2;

    IF v_total <> v_expected_total THEN
        RAISE EXCEPTION
            'TEST GAGAL: total seharusnya %, tetapi menjadi %',
            v_expected_total,
            v_total;
    END IF;

    IF v_status <> 'COMPLETED' THEN
        RAISE EXCEPTION
            'TEST GAGAL: status transaksi bukan COMPLETED';
    END IF;

    SELECT stock
    INTO v_stock_1_after
    FROM sales_app.products
    WHERE product_id = v_product_1;

    SELECT stock
    INTO v_stock_2_after
    FROM sales_app.products
    WHERE product_id = v_product_2;

    IF v_stock_1_after <> v_stock_1_before - 1 THEN
        RAISE EXCEPTION
            'TEST GAGAL: stok produk pertama tidak berkurang';
    END IF;

    IF v_stock_2_after <> v_stock_2_before - 1 THEN
        RAISE EXCEPTION
            'TEST GAGAL: stok produk kedua tidak berkurang';
    END IF;

    IF (
        SELECT COUNT(*)
        FROM sales_app.sale_items
        WHERE sale_id = v_sale_id
    ) <> 2 THEN
        RAISE EXCEPTION
            'TEST GAGAL: jumlah detail transaksi seharusnya 2';
    END IF;

    RAISE NOTICE
        'PASS: transaksi berhasil. sale_id=%, total=%',
        v_sale_id,
        v_total;

    -- -----------------------------------------------------
    -- Uji pembatalan transaksi
    -- -----------------------------------------------------
    PERFORM sales_app.fn_cancel_sale(v_sale_id);

    SELECT status
    INTO v_status
    FROM sales_app.sales
    WHERE sale_id = v_sale_id;

    IF v_status <> 'CANCELLED' THEN
        RAISE EXCEPTION
            'TEST GAGAL: transaksi tidak berubah menjadi CANCELLED';
    END IF;

    SELECT stock
    INTO v_stock_1_after
    FROM sales_app.products
    WHERE product_id = v_product_1;

    SELECT stock
    INTO v_stock_2_after
    FROM sales_app.products
    WHERE product_id = v_product_2;

    IF v_stock_1_after <> v_stock_1_before
       OR v_stock_2_after <> v_stock_2_before
    THEN
        RAISE EXCEPTION
            'TEST GAGAL: stok tidak kembali setelah pembatalan';
    END IF;

    RAISE NOTICE
        'PASS: pembatalan transaksi dan pengembalian stok berhasil';
END
$$;

ROLLBACK;


-- =========================================================
-- E. TEST VALIDASI STOK / EXCEPTION HANDLING
-- =========================================================
-- Test dianggap PASS jika function menolak jumlah yang melebihi stok.

BEGIN;

DO $$
DECLARE
    v_customer_id BIGINT;
    v_product_id BIGINT;
    v_stock INTEGER;
    v_sale_count_before BIGINT;
    v_sale_count_after BIGINT;
    v_exception_received BOOLEAN := FALSE;
BEGIN
    SELECT customer_id
    INTO v_customer_id
    FROM sales_app.customers
    ORDER BY customer_id
    LIMIT 1;

    SELECT product_id, stock
    INTO v_product_id, v_stock
    FROM sales_app.products
    ORDER BY product_id
    LIMIT 1;

    IF v_customer_id IS NULL OR v_product_id IS NULL THEN
        RAISE EXCEPTION
            'TEST GAGAL: customer/product untuk test tidak tersedia';
    END IF;

    SELECT COUNT(*)
    INTO v_sale_count_before
    FROM sales_app.sales;

    BEGIN
        PERFORM sales_app.fn_create_sale(
            v_customer_id,
            jsonb_build_array(
                jsonb_build_object(
                    'product_id', v_product_id,
                    'quantity', v_stock + 1
                )
            )
        );

    EXCEPTION
        WHEN OTHERS THEN
            v_exception_received := TRUE;
            RAISE NOTICE
                'PASS: transaksi stok tidak cukup ditolak. Pesan: %',
                SQLERRM;
    END;

    IF NOT v_exception_received THEN
        RAISE EXCEPTION
            'TEST GAGAL: transaksi dengan stok tidak cukup justru diterima';
    END IF;

    SELECT COUNT(*)
    INTO v_sale_count_after
    FROM sales_app.sales;

    IF v_sale_count_after <> v_sale_count_before THEN
        RAISE EXCEPTION
            'TEST GAGAL: header transaksi tersisa setelah exception';
    END IF;

    RAISE NOTICE
        'PASS: rollback otomatis saat exception berhasil';
END
$$;

ROLLBACK;


-- =========================================================
-- F. TEST TRIGGER DAN AUDIT TRAIL
-- =========================================================

BEGIN;

DO $$
DECLARE
    v_product_id BIGINT;
    v_old_price NUMERIC(12,2);
    v_audit_before BIGINT;
    v_audit_after BIGINT;
BEGIN
    SELECT product_id, price
    INTO v_product_id, v_old_price
    FROM sales_app.products
    ORDER BY product_id
    LIMIT 1;

    IF v_product_id IS NULL THEN
        RAISE EXCEPTION 'TEST GAGAL: tidak ada produk';
    END IF;

    SELECT COUNT(*)
    INTO v_audit_before
    FROM sales_app.audit_logs;

    -- UPDATE melalui function agar trigger berjalan.
    PERFORM sales_app.fn_product_update(
        v_product_id,
        (
            SELECT name
            FROM sales_app.products
            WHERE product_id = v_product_id
        ),
        v_old_price + 1,
        (
            SELECT stock
            FROM sales_app.products
            WHERE product_id = v_product_id
        )
    );

    SELECT COUNT(*)
    INTO v_audit_after
    FROM sales_app.audit_logs;

    IF v_audit_after <= v_audit_before THEN
        RAISE EXCEPTION
            'TEST GAGAL: trigger tidak membuat audit log';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM sales_app.audit_logs
        WHERE table_name = 'products'
          AND record_id = v_product_id
          AND action = 'UPDATE'
          AND old_data IS NOT NULL
          AND new_data IS NOT NULL
    ) THEN
        RAISE EXCEPTION
            'TEST GAGAL: isi audit UPDATE produk tidak ditemukan';
    END IF;

    RAISE NOTICE
        'PASS: trigger dan audit trail berhasil';
END
$$;

-- Lihat audit sementara sebelum rollback:
SELECT *
FROM sales_app.audit_logs
ORDER BY audit_id DESC
LIMIT 10;

ROLLBACK;


-- =========================================================
-- G. TEST VIEW DAN LAPORAN
-- =========================================================

SELECT *
FROM sales_app.vw_product_stock
ORDER BY product_id;

SELECT *
FROM sales_app.vw_sales_summary
ORDER BY sale_id DESC;

SELECT *
FROM sales_app.vw_sales_report
ORDER BY sale_id DESC, product_id;

SELECT *
FROM sales_app.fn_sales_report(
    CURRENT_DATE - 30,
    CURRENT_DATE
);

SELECT *
FROM sales_app.fn_sales_total(
    CURRENT_DATE - 30,
    CURRENT_DATE
);


-- =========================================================
-- H. TEST CURSOR / REFCURSOR
-- =========================================================
-- Cursor harus digunakan di dalam transaction block.

BEGIN;

CALL sales_app.sp_sales_report_cursor(
    CURRENT_DATE - 30,
    CURRENT_DATE,
    'assessment_sales_cursor'
);

FETCH ALL FROM assessment_sales_cursor;

ROLLBACK;


-- =========================================================
-- I. DEMONSTRASI TCL - ROLLBACK
-- =========================================================

SELECT COUNT(*) AS customer_before_rollback
FROM sales_app.customers;

BEGIN;

SELECT sales_app.fn_customer_add(
    'TEST ROLLBACK',
    '080000000099',
    'Data ini harus hilang setelah rollback'
);

SELECT *
FROM sales_app.fn_customer_search('TEST ROLLBACK');

ROLLBACK;

-- Seharusnya 0 baris:
SELECT *
FROM sales_app.fn_customer_search('TEST ROLLBACK');


-- =========================================================
-- J. DEMONSTRASI TCL - COMMIT
-- =========================================================
-- Bagian COMMIT di bawah sengaja DIKOMENTARI karena akan
-- menyimpan data ke database secara permanen.
--
-- Saat asesmen, Anda dapat membuka blok komentar lalu
-- menjalankannya untuk mendemonstrasikan COMMIT.
--
-- BEGIN;
--
-- SELECT sales_app.fn_customer_add(
--     'TEST COMMIT',
--     '080000000088',
--     'Data contoh COMMIT'
-- );
--
-- COMMIT;
--
-- SELECT *
-- FROM sales_app.fn_customer_search('TEST COMMIT');
--
-- Setelah demonstrasi, hapus data test:
--
-- SELECT sales_app.fn_customer_delete(
--     (
--         SELECT customer_id
--         FROM sales_app.customers
--         WHERE name = 'TEST COMMIT'
--         ORDER BY customer_id DESC
--         LIMIT 1
--     )
-- );


-- =========================================================
-- K. TEST SECURITY / DCL
-- =========================================================
-- Jalankan bagian ini menggunakan koneksi pgAdmin yang login
-- sebagai:
--
--   User     : django_app_user
--   Database : db_penjualan
--
-- Jangan jalankan sebagai postgres jika ingin membuktikan
-- pembatasan hak akses.
--
-- ---------------------------------------------------------
-- 1. Seharusnya BERHASIL: akses melalui function
-- ---------------------------------------------------------
-- SELECT * FROM sales_app.fn_product_get_all();
--
-- SELECT * FROM sales_app.fn_customer_get_all();
--
-- SELECT * FROM sales_app.vw_product_stock;
--
-- ---------------------------------------------------------
-- 2. Seharusnya GAGAL: INSERT langsung ke table
-- ---------------------------------------------------------
-- INSERT INTO sales_app.products(name, price, stock)
-- VALUES ('HARUS DITOLAK', 10000, 1);
--
-- Expected:
-- ERROR: permission denied for table products
--
-- ---------------------------------------------------------
-- 3. Seharusnya GAGAL: UPDATE langsung
-- ---------------------------------------------------------
-- UPDATE sales_app.products
-- SET price = 1
-- WHERE product_id = 1;
--
-- Expected:
-- ERROR: permission denied for table products
--
-- ---------------------------------------------------------
-- 4. Seharusnya BERHASIL: INSERT melalui function
-- ---------------------------------------------------------
-- SELECT sales_app.fn_product_add(
--     'Produk Dari Django User',
--     50000,
--     5
-- );


-- =========================================================
-- L. RINGKASAN DATA AKHIR
-- =========================================================

SELECT
    (SELECT COUNT(*) FROM sales_app.customers) AS total_customers,
    (SELECT COUNT(*) FROM sales_app.products) AS total_products,
    (SELECT COUNT(*) FROM sales_app.sales) AS total_sales,
    (SELECT COUNT(*) FROM sales_app.sale_items) AS total_sale_items,
    (SELECT COUNT(*) FROM sales_app.audit_logs) AS total_audit_logs;


-- =========================================================
-- M. CHECKLIST ASESMEN YANG DIDEMONSTRASIKAN
-- =========================================================
-- [x] DDL                 -> CREATE schema/table/index/view
-- [x] DML                 -> INSERT/SELECT/UPDATE/DELETE via function
-- [x] DCL                 -> GRANT / REVOKE / role
-- [x] TCL                 -> BEGIN / COMMIT / ROLLBACK
-- [x] Primary Key
-- [x] Foreign Key
-- [x] CHECK constraint
-- [x] Index
-- [x] Stored Function
-- [x] Stored Procedure
-- [x] Percabangan IF
-- [x] Perulangan FOR LOOP
-- [x] Cursor / REFCURSOR
-- [x] Exception Handling
-- [x] Transaction
-- [x] Validasi stok
-- [x] Pengurangan stok
-- [x] Perhitungan subtotal dan total
-- [x] Trigger
-- [x] Audit Trail
-- [x] View
-- [x] Role dan pembatasan akses
-- =========================================================

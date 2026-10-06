-- =========================================================
-- 05_views.sql
-- View dan Laporan Penjualan
-- PostgreSQL / pgAdmin 4
--
-- Mencakup:
-- - VIEW laporan penjualan
-- - VIEW stok produk
-- - VIEW ringkasan transaksi
-- - Function laporan berdasarkan tanggal
-- - Stored procedure menggunakan CURSOR / REFCURSOR
-- =========================================================

SET search_path TO sales_app, public;

-- =========================================================
-- A. VIEW DETAIL LAPORAN PENJUALAN
-- =========================================================
-- Menampilkan detail transaksi per produk.
-- =========================================================

CREATE OR REPLACE VIEW sales_app.vw_sales_report AS
SELECT
    s.sale_id,
    s.sale_date,
    c.customer_id,
    c.name AS customer_name,
    p.product_id,
    p.name AS product_name,
    si.quantity,
    si.price,
    si.subtotal,
    s.total_amount,
    s.status
FROM sales_app.sales s
JOIN sales_app.customers c
    ON c.customer_id = s.customer_id
JOIN sales_app.sale_items si
    ON si.sale_id = s.sale_id
JOIN sales_app.products p
    ON p.product_id = si.product_id;


-- =========================================================
-- B. VIEW STOK PRODUK
-- =========================================================

CREATE OR REPLACE VIEW sales_app.vw_product_stock AS
SELECT
    p.product_id,
    p.name AS product_name,
    p.price,
    p.stock,
    CASE
        WHEN p.stock = 0 THEN 'HABIS'
        WHEN p.stock <= 5 THEN 'MENIPIS'
        ELSE 'TERSEDIA'
    END AS stock_status,
    p.created_at
FROM sales_app.products p;


-- =========================================================
-- C. VIEW RINGKASAN TRANSAKSI
-- =========================================================
-- Satu baris untuk satu transaksi.
-- =========================================================

CREATE OR REPLACE VIEW sales_app.vw_sales_summary AS
SELECT
    s.sale_id,
    s.sale_date,
    c.customer_id,
    c.name AS customer_name,
    COUNT(si.sale_item_id) AS total_item_jenis,
    COALESCE(SUM(si.quantity), 0) AS total_quantity,
    s.total_amount,
    s.status
FROM sales_app.sales s
JOIN sales_app.customers c
    ON c.customer_id = s.customer_id
LEFT JOIN sales_app.sale_items si
    ON si.sale_id = s.sale_id
GROUP BY
    s.sale_id,
    s.sale_date,
    c.customer_id,
    c.name,
    s.total_amount,
    s.status;


-- =========================================================
-- D. FUNCTION LAPORAN BERDASARKAN RENTANG TANGGAL
-- =========================================================

CREATE OR REPLACE FUNCTION sales_app.fn_sales_report(
    p_start_date DATE,
    p_end_date DATE
)
RETURNS TABLE (
    sale_id BIGINT,
    sale_date TIMESTAMP,
    customer_name VARCHAR,
    product_name VARCHAR,
    quantity INTEGER,
    price NUMERIC,
    subtotal NUMERIC,
    total_amount NUMERIC,
    status VARCHAR
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_start_date IS NULL OR p_end_date IS NULL THEN
        RAISE EXCEPTION
            'Tanggal awal dan tanggal akhir wajib diisi';
    END IF;

    IF p_start_date > p_end_date THEN
        RAISE EXCEPTION
            'Tanggal awal tidak boleh lebih besar dari tanggal akhir';
    END IF;

    RETURN QUERY
    SELECT
        v.sale_id,
        v.sale_date,
        v.customer_name,
        v.product_name,
        v.quantity,
        v.price,
        v.subtotal,
        v.total_amount,
        v.status
    FROM sales_app.vw_sales_report v
    WHERE v.sale_date::DATE
          BETWEEN p_start_date AND p_end_date
    ORDER BY
        v.sale_date DESC,
        v.sale_id DESC,
        v.product_id;
END;
$$;


-- =========================================================
-- E. FUNCTION TOTAL PENJUALAN BERDASARKAN TANGGAL
-- =========================================================

CREATE OR REPLACE FUNCTION sales_app.fn_sales_total(
    p_start_date DATE,
    p_end_date DATE
)
RETURNS TABLE (
    total_transaction BIGINT,
    total_quantity BIGINT,
    grand_total NUMERIC
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_start_date IS NULL OR p_end_date IS NULL THEN
        RAISE EXCEPTION
            'Tanggal awal dan tanggal akhir wajib diisi';
    END IF;

    IF p_start_date > p_end_date THEN
        RAISE EXCEPTION
            'Tanggal awal tidak boleh lebih besar dari tanggal akhir';
    END IF;

    RETURN QUERY
    SELECT
        COUNT(*)::BIGINT AS total_transaction,
        COALESCE(SUM(v.total_quantity), 0)::BIGINT
            AS total_quantity,
        COALESCE(SUM(v.total_amount), 0)::NUMERIC
            AS grand_total
    FROM sales_app.vw_sales_summary v
    WHERE v.sale_date::DATE
          BETWEEN p_start_date AND p_end_date
      AND v.status = 'COMPLETED';
END;
$$;


-- =========================================================
-- F. STORED PROCEDURE DENGAN CURSOR / REFCURSOR
-- =========================================================
-- Bagian ini dibuat untuk demonstrasi penggunaan cursor
-- pada asesmen.
--
-- Cara menjalankan:
--
-- BEGIN;
--
-- CALL sales_app.sp_sales_report_cursor(
--     CURRENT_DATE - 30,
--     CURRENT_DATE,
--     'sales_cursor'
-- );
--
-- FETCH ALL FROM sales_cursor;
--
-- COMMIT;
-- =========================================================

CREATE OR REPLACE PROCEDURE sales_app.sp_sales_report_cursor(
    IN p_start_date DATE,
    IN p_end_date DATE,
    INOUT p_cursor REFCURSOR
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_start_date IS NULL OR p_end_date IS NULL THEN
        RAISE EXCEPTION
            'Tanggal awal dan tanggal akhir wajib diisi';
    END IF;

    IF p_start_date > p_end_date THEN
        RAISE EXCEPTION
            'Tanggal awal tidak boleh lebih besar dari tanggal akhir';
    END IF;

    OPEN p_cursor FOR
        SELECT
            v.sale_id,
            v.sale_date,
            v.customer_name,
            v.product_name,
            v.quantity,
            v.price,
            v.subtotal,
            v.total_amount,
            v.status
        FROM sales_app.vw_sales_report v
        WHERE v.sale_date::DATE
              BETWEEN p_start_date AND p_end_date
        ORDER BY
            v.sale_date DESC,
            v.sale_id DESC,
            v.product_id;
END;
$$;


-- =========================================================
-- G. CONTOH PENGUJIAN
-- =========================================================
-- Semua contoh dikomentari agar import file tidak mengubah data.

-- ---------------------------------------------------------
-- 1. Lihat detail laporan
-- ---------------------------------------------------------
-- SELECT *
-- FROM sales_app.vw_sales_report
-- ORDER BY sale_id DESC;

-- ---------------------------------------------------------
-- 2. Lihat stok produk
-- ---------------------------------------------------------
-- SELECT *
-- FROM sales_app.vw_product_stock
-- ORDER BY product_id;

-- ---------------------------------------------------------
-- 3. Lihat ringkasan transaksi
-- ---------------------------------------------------------
-- SELECT *
-- FROM sales_app.vw_sales_summary
-- ORDER BY sale_id DESC;

-- ---------------------------------------------------------
-- 4. Laporan berdasarkan tanggal
-- ---------------------------------------------------------
-- SELECT *
-- FROM sales_app.fn_sales_report(
--     CURRENT_DATE - 30,
--     CURRENT_DATE
-- );

-- ---------------------------------------------------------
-- 5. Total penjualan
-- ---------------------------------------------------------
-- SELECT *
-- FROM sales_app.fn_sales_total(
--     CURRENT_DATE - 30,
--     CURRENT_DATE
-- );

-- ---------------------------------------------------------
-- 6. Cursor
-- ---------------------------------------------------------
-- BEGIN;
--
-- CALL sales_app.sp_sales_report_cursor(
--     CURRENT_DATE - 30,
--     CURRENT_DATE,
--     'sales_cursor'
-- );
--
-- FETCH ALL FROM sales_cursor;
--
-- COMMIT;


-- =========================================================
-- H. CEK VIEW
-- =========================================================

SELECT
    table_name AS view_name
FROM information_schema.views
WHERE table_schema = 'sales_app'
ORDER BY table_name;


-- =========================================================
-- I. CEK FUNCTION / PROCEDURE LAPORAN
-- =========================================================

SELECT
    routine_name,
    routine_type
FROM information_schema.routines
WHERE routine_schema = 'sales_app'
  AND (
      routine_name LIKE '%report%'
      OR routine_name LIKE '%cursor%'
      OR routine_name LIKE '%total%'
  )
ORDER BY routine_name;

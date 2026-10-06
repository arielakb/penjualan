-- =========================================================
-- 06_roles_security.sql
-- Role, DCL, GRANT, REVOKE, dan Keamanan Database
-- PostgreSQL / pgAdmin 4
--
-- Prasyarat:
--   01_schema_penjualan.sql
--   02_functions.sql
--   03_transaction.sql
--   04_triggers.sql
--   05_views.sql
--
-- Jalankan file ini menggunakan user PostgreSQL yang memiliki
-- hak CREATE ROLE / superuser (misalnya postgres).
-- =========================================================

SET search_path TO sales_app, public;

-- =========================================================
-- A. BUAT GROUP ROLE
-- =========================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_roles
        WHERE rolname = 'role_sales_app'
    ) THEN
        CREATE ROLE role_sales_app NOLOGIN;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_roles
        WHERE rolname = 'role_sales_report'
    ) THEN
        CREATE ROLE role_sales_report NOLOGIN;
    END IF;
END
$$;


-- =========================================================
-- B. BUAT USER LOGIN UNTUK DJANGO
-- =========================================================
-- Password di bawah hanya untuk development/local.
-- Ganti password sebelum aplikasi digunakan di lingkungan lain.

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_roles
        WHERE rolname = 'django_app_user'
    ) THEN
        CREATE ROLE django_app_user
        LOGIN
        PASSWORD 'DjangoPenjualan_123!';
    END IF;
END
$$;


-- =========================================================
-- C. MASUKKAN USER DJANGO KE ROLE APLIKASI
-- =========================================================

GRANT role_sales_app TO django_app_user;

GRANT CONNECT
ON DATABASE db_penjualan
TO django_app_user;

ALTER ROLE django_app_user
SET search_path TO sales_app, public;


-- =========================================================
-- D. CABUT AKSES UMUM (REVOKE)
-- =========================================================
-- PUBLIC tidak boleh langsung memodifikasi tabel aplikasi.

REVOKE ALL
ON SCHEMA sales_app
FROM PUBLIC;

REVOKE ALL
ON ALL TABLES IN SCHEMA sales_app
FROM PUBLIC;

REVOKE ALL
ON ALL SEQUENCES IN SCHEMA sales_app
FROM PUBLIC;

REVOKE EXECUTE
ON ALL ROUTINES IN SCHEMA sales_app
FROM PUBLIC;


-- =========================================================
-- E. SECURITY DEFINER UNTUK BUSINESS FUNCTIONS
-- =========================================================
-- Dengan SECURITY DEFINER, Django dapat menjalankan function
-- tanpa diberi hak INSERT/UPDATE/DELETE langsung ke tabel.
-- Function tetap menjalankan operasi menggunakan hak pemiliknya.

ALTER FUNCTION sales_app.fn_customer_add(VARCHAR, VARCHAR, TEXT)
    SECURITY DEFINER;
ALTER FUNCTION sales_app.fn_customer_add(VARCHAR, VARCHAR, TEXT)
    SET search_path = sales_app, pg_temp;

ALTER FUNCTION sales_app.fn_customer_get_all()
    SECURITY DEFINER;
ALTER FUNCTION sales_app.fn_customer_get_all()
    SET search_path = sales_app, pg_temp;

ALTER FUNCTION sales_app.fn_customer_search(TEXT)
    SECURITY DEFINER;
ALTER FUNCTION sales_app.fn_customer_search(TEXT)
    SET search_path = sales_app, pg_temp;

ALTER FUNCTION sales_app.fn_customer_update(BIGINT, VARCHAR, VARCHAR, TEXT)
    SECURITY DEFINER;
ALTER FUNCTION sales_app.fn_customer_update(BIGINT, VARCHAR, VARCHAR, TEXT)
    SET search_path = sales_app, pg_temp;

ALTER FUNCTION sales_app.fn_customer_delete(BIGINT)
    SECURITY DEFINER;
ALTER FUNCTION sales_app.fn_customer_delete(BIGINT)
    SET search_path = sales_app, pg_temp;


ALTER FUNCTION sales_app.fn_product_add(VARCHAR, NUMERIC, INTEGER)
    SECURITY DEFINER;
ALTER FUNCTION sales_app.fn_product_add(VARCHAR, NUMERIC, INTEGER)
    SET search_path = sales_app, pg_temp;

ALTER FUNCTION sales_app.fn_product_get_all()
    SECURITY DEFINER;
ALTER FUNCTION sales_app.fn_product_get_all()
    SET search_path = sales_app, pg_temp;

ALTER FUNCTION sales_app.fn_product_search(TEXT)
    SECURITY DEFINER;
ALTER FUNCTION sales_app.fn_product_search(TEXT)
    SET search_path = sales_app, pg_temp;

ALTER FUNCTION sales_app.fn_product_update(BIGINT, VARCHAR, NUMERIC, INTEGER)
    SECURITY DEFINER;
ALTER FUNCTION sales_app.fn_product_update(BIGINT, VARCHAR, NUMERIC, INTEGER)
    SET search_path = sales_app, pg_temp;

ALTER FUNCTION sales_app.fn_product_delete(BIGINT)
    SECURITY DEFINER;
ALTER FUNCTION sales_app.fn_product_delete(BIGINT)
    SET search_path = sales_app, pg_temp;


ALTER FUNCTION sales_app.fn_create_sale(BIGINT, JSONB)
    SECURITY DEFINER;
ALTER FUNCTION sales_app.fn_create_sale(BIGINT, JSONB)
    SET search_path = sales_app, pg_temp;

ALTER FUNCTION sales_app.fn_cancel_sale(BIGINT)
    SECURITY DEFINER;
ALTER FUNCTION sales_app.fn_cancel_sale(BIGINT)
    SET search_path = sales_app, pg_temp;

ALTER FUNCTION sales_app.fn_sale_detail(BIGINT)
    SECURITY DEFINER;
ALTER FUNCTION sales_app.fn_sale_detail(BIGINT)
    SET search_path = sales_app, pg_temp;


ALTER FUNCTION sales_app.fn_sales_report(DATE, DATE)
    SECURITY DEFINER;
ALTER FUNCTION sales_app.fn_sales_report(DATE, DATE)
    SET search_path = sales_app, pg_temp;

ALTER FUNCTION sales_app.fn_sales_total(DATE, DATE)
    SECURITY DEFINER;
ALTER FUNCTION sales_app.fn_sales_total(DATE, DATE)
    SET search_path = sales_app, pg_temp;


-- Trigger audit juga diamankan.
ALTER FUNCTION sales_app.fn_audit_log()
    SECURITY DEFINER;
ALTER FUNCTION sales_app.fn_audit_log()
    SET search_path = sales_app, pg_temp;


-- Stored procedure
ALTER PROCEDURE sales_app.sp_create_sale(BIGINT, JSONB, BIGINT)
    SECURITY DEFINER;
ALTER PROCEDURE sales_app.sp_create_sale(BIGINT, JSONB, BIGINT)
    SET search_path = sales_app, pg_temp;

ALTER PROCEDURE sales_app.sp_sales_report_cursor(DATE, DATE, REFCURSOR)
    SECURITY DEFINER;
ALTER PROCEDURE sales_app.sp_sales_report_cursor(DATE, DATE, REFCURSOR)
    SET search_path = sales_app, pg_temp;


-- =========================================================
-- F. HAK AKSES ROLE APLIKASI
-- =========================================================
-- Django tidak diberi INSERT/UPDATE/DELETE langsung ke tabel.
-- Django mengakses data melalui function/procedure dan view.

GRANT USAGE
ON SCHEMA sales_app
TO role_sales_app;

GRANT SELECT
ON sales_app.vw_sales_report,
   sales_app.vw_product_stock,
   sales_app.vw_sales_summary
TO role_sales_app;


-- Customer
GRANT EXECUTE
ON FUNCTION sales_app.fn_customer_add(VARCHAR, VARCHAR, TEXT)
TO role_sales_app;

GRANT EXECUTE
ON FUNCTION sales_app.fn_customer_get_all()
TO role_sales_app;

GRANT EXECUTE
ON FUNCTION sales_app.fn_customer_search(TEXT)
TO role_sales_app;

GRANT EXECUTE
ON FUNCTION sales_app.fn_customer_update(BIGINT, VARCHAR, VARCHAR, TEXT)
TO role_sales_app;

GRANT EXECUTE
ON FUNCTION sales_app.fn_customer_delete(BIGINT)
TO role_sales_app;


-- Product
GRANT EXECUTE
ON FUNCTION sales_app.fn_product_add(VARCHAR, NUMERIC, INTEGER)
TO role_sales_app;

GRANT EXECUTE
ON FUNCTION sales_app.fn_product_get_all()
TO role_sales_app;

GRANT EXECUTE
ON FUNCTION sales_app.fn_product_search(TEXT)
TO role_sales_app;

GRANT EXECUTE
ON FUNCTION sales_app.fn_product_update(BIGINT, VARCHAR, NUMERIC, INTEGER)
TO role_sales_app;

GRANT EXECUTE
ON FUNCTION sales_app.fn_product_delete(BIGINT)
TO role_sales_app;


-- Transaksi
GRANT EXECUTE
ON FUNCTION sales_app.fn_create_sale(BIGINT, JSONB)
TO role_sales_app;

GRANT EXECUTE
ON FUNCTION sales_app.fn_cancel_sale(BIGINT)
TO role_sales_app;

GRANT EXECUTE
ON FUNCTION sales_app.fn_sale_detail(BIGINT)
TO role_sales_app;

GRANT EXECUTE
ON PROCEDURE sales_app.sp_create_sale(BIGINT, JSONB, BIGINT)
TO role_sales_app;


-- Laporan
GRANT EXECUTE
ON FUNCTION sales_app.fn_sales_report(DATE, DATE)
TO role_sales_app;

GRANT EXECUTE
ON FUNCTION sales_app.fn_sales_total(DATE, DATE)
TO role_sales_app;

GRANT EXECUTE
ON PROCEDURE sales_app.sp_sales_report_cursor(DATE, DATE, REFCURSOR)
TO role_sales_app;


-- =========================================================
-- G. ROLE READ-ONLY UNTUK LAPORAN
-- =========================================================

GRANT USAGE
ON SCHEMA sales_app
TO role_sales_report;

GRANT SELECT
ON sales_app.vw_sales_report,
   sales_app.vw_product_stock,
   sales_app.vw_sales_summary
TO role_sales_report;

GRANT EXECUTE
ON FUNCTION sales_app.fn_sales_report(DATE, DATE)
TO role_sales_report;

GRANT EXECUTE
ON FUNCTION sales_app.fn_sales_total(DATE, DATE)
TO role_sales_report;

GRANT EXECUTE
ON FUNCTION sales_app.fn_sale_detail(BIGINT)
TO role_sales_report;

GRANT EXECUTE
ON PROCEDURE sales_app.sp_sales_report_cursor(DATE, DATE, REFCURSOR)
TO role_sales_report;


-- =========================================================
-- H. CONTOH REVOKE
-- =========================================================
-- Contoh DCL REVOKE untuk asesmen.
-- Baris berikut hanya contoh dan sengaja dikomentari.
--
-- REVOKE EXECUTE
-- ON FUNCTION sales_app.fn_product_delete(BIGINT)
-- FROM role_sales_app;
--
-- Jika ingin memberikan kembali:
--
-- GRANT EXECUTE
-- ON FUNCTION sales_app.fn_product_delete(BIGINT)
-- TO role_sales_app;


-- =========================================================
-- I. CONTOH MENGUBAH PASSWORD
-- =========================================================
-- Jalankan setelah import bila ingin mengganti password:
--
-- ALTER ROLE django_app_user
-- PASSWORD 'PasswordBaruYangKuat';


-- =========================================================
-- J. CEK ROLE
-- =========================================================

SELECT
    rolname,
    rolcanlogin,
    rolsuper,
    rolcreaterole,
    rolcreatedb
FROM pg_roles
WHERE rolname IN (
    'role_sales_app',
    'role_sales_report',
    'django_app_user'
)
ORDER BY rolname;


-- =========================================================
-- K. CEK HAK AKSES USER DJANGO
-- =========================================================

SELECT
    r.rolname AS role_name,
    m.rolname AS member_name
FROM pg_auth_members am
JOIN pg_roles r
    ON r.oid = am.roleid
JOIN pg_roles m
    ON m.oid = am.member
WHERE m.rolname = 'django_app_user';


-- =========================================================
-- L. UJI LOGIN DJANGO (JALANKAN SETELAH LOGIN SEBAGAI USER)
-- =========================================================
-- Setelah membuat koneksi baru di pgAdmin menggunakan:
--
-- User     : django_app_user
-- Password : DjangoPenjualan_123!
-- Database : db_penjualan
--
-- Coba:
--
-- SELECT * FROM sales_app.fn_product_get_all();
--
-- SELECT sales_app.fn_customer_add(
--     'User Django Test',
--     '081200000000',
--     'Depok'
-- );
--
-- SELECT * FROM sales_app.vw_product_stock;
--
-- Operasi langsung berikut seharusnya DITOLAK:
--
-- INSERT INTO sales_app.products(name, price, stock)
-- VALUES ('Produk Langsung', 10000, 1);
--
-- Hal ini menunjukkan bahwa aplikasi harus menggunakan
-- function/procedure yang sudah disediakan.

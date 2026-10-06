-- =========================================================
-- 04_triggers.sql
-- Trigger Audit Trail
-- PostgreSQL / pgAdmin 4
--
-- Mencakup:
-- - Trigger function
-- - AFTER INSERT / UPDATE / DELETE
-- - Audit trail otomatis
-- - Penyimpanan OLD dan NEW dalam JSONB
-- =========================================================

SET search_path TO sales_app, public;

-- =========================================================
-- A. GENERIC AUDIT FUNCTION
-- =========================================================

CREATE OR REPLACE FUNCTION sales_app.fn_audit_log()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_record_id BIGINT;
BEGIN
    -- Tentukan ID record berdasarkan tabel yang berubah.
    IF TG_TABLE_NAME = 'customers' THEN
        IF TG_OP = 'DELETE' THEN
            v_record_id := OLD.customer_id;
        ELSE
            v_record_id := NEW.customer_id;
        END IF;

    ELSIF TG_TABLE_NAME = 'products' THEN
        IF TG_OP = 'DELETE' THEN
            v_record_id := OLD.product_id;
        ELSE
            v_record_id := NEW.product_id;
        END IF;

    ELSIF TG_TABLE_NAME = 'sales' THEN
        IF TG_OP = 'DELETE' THEN
            v_record_id := OLD.sale_id;
        ELSE
            v_record_id := NEW.sale_id;
        END IF;

    ELSIF TG_TABLE_NAME = 'sale_items' THEN
        IF TG_OP = 'DELETE' THEN
            v_record_id := OLD.sale_item_id;
        ELSE
            v_record_id := NEW.sale_item_id;
        END IF;
    END IF;

    -- Simpan audit berdasarkan jenis operasi.
    IF TG_OP = 'INSERT' THEN

        INSERT INTO sales_app.audit_logs (
            table_name,
            record_id,
            action,
            old_data,
            new_data
        )
        VALUES (
            TG_TABLE_NAME,
            v_record_id,
            'INSERT',
            NULL,
            to_jsonb(NEW)
        );

        RETURN NEW;

    ELSIF TG_OP = 'UPDATE' THEN

        INSERT INTO sales_app.audit_logs (
            table_name,
            record_id,
            action,
            old_data,
            new_data
        )
        VALUES (
            TG_TABLE_NAME,
            v_record_id,
            'UPDATE',
            to_jsonb(OLD),
            to_jsonb(NEW)
        );

        RETURN NEW;

    ELSIF TG_OP = 'DELETE' THEN

        INSERT INTO sales_app.audit_logs (
            table_name,
            record_id,
            action,
            old_data,
            new_data
        )
        VALUES (
            TG_TABLE_NAME,
            v_record_id,
            'DELETE',
            to_jsonb(OLD),
            NULL
        );

        RETURN OLD;
    END IF;

    RETURN NULL;
END;
$$;


-- =========================================================
-- B. TRIGGER: CUSTOMERS
-- =========================================================

DROP TRIGGER IF EXISTS trg_audit_customers
ON sales_app.customers;

CREATE TRIGGER trg_audit_customers
AFTER INSERT OR UPDATE OR DELETE
ON sales_app.customers
FOR EACH ROW
EXECUTE FUNCTION sales_app.fn_audit_log();


-- =========================================================
-- C. TRIGGER: PRODUCTS
-- =========================================================

DROP TRIGGER IF EXISTS trg_audit_products
ON sales_app.products;

CREATE TRIGGER trg_audit_products
AFTER INSERT OR UPDATE OR DELETE
ON sales_app.products
FOR EACH ROW
EXECUTE FUNCTION sales_app.fn_audit_log();


-- =========================================================
-- D. TRIGGER: SALES
-- =========================================================

DROP TRIGGER IF EXISTS trg_audit_sales
ON sales_app.sales;

CREATE TRIGGER trg_audit_sales
AFTER INSERT OR UPDATE OR DELETE
ON sales_app.sales
FOR EACH ROW
EXECUTE FUNCTION sales_app.fn_audit_log();


-- =========================================================
-- E. TRIGGER: SALE_ITEMS
-- =========================================================

DROP TRIGGER IF EXISTS trg_audit_sale_items
ON sales_app.sale_items;

CREATE TRIGGER trg_audit_sale_items
AFTER INSERT OR UPDATE OR DELETE
ON sales_app.sale_items
FOR EACH ROW
EXECUTE FUNCTION sales_app.fn_audit_log();


-- =========================================================
-- F. CONTOH PENGUJIAN
-- =========================================================
-- Baris contoh sengaja dikomentari agar file dapat di-import
-- tanpa mengubah data.
--
-- ---------------------------------------------------------
-- TEST INSERT
-- ---------------------------------------------------------
-- SELECT sales_app.fn_product_add(
--     'Webcam',
--     350000,
--     10
-- );
--
-- ---------------------------------------------------------
-- TEST UPDATE
-- ---------------------------------------------------------
-- SELECT sales_app.fn_product_update(
--     1,
--     'Mouse Wireless',
--     175000,
--     20
-- );
--
-- ---------------------------------------------------------
-- TEST DELETE
-- ---------------------------------------------------------
-- Tambahkan data baru lebih dulu, kemudian hapus ID-nya:
--
-- SELECT sales_app.fn_customer_add(
--     'Customer Test',
--     '080000000000',
--     'Test'
-- );
--
-- SELECT sales_app.fn_customer_delete(3);
--
-- ---------------------------------------------------------
-- CEK AUDIT
-- ---------------------------------------------------------
-- SELECT *
-- FROM sales_app.audit_logs
-- ORDER BY audit_id DESC;


-- =========================================================
-- G. CEK TRIGGER YANG BERHASIL DIBUAT
-- =========================================================

SELECT
    event_object_table AS table_name,
    trigger_name,
    event_manipulation AS event
FROM information_schema.triggers
WHERE trigger_schema = 'sales_app'
ORDER BY event_object_table, trigger_name, event_manipulation;

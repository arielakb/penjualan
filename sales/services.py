import json
from django.db import connection

def dictfetchall(cursor):
    columns = [col[0] for col in cursor.description]
    return [dict(zip(columns, row)) for row in cursor.fetchall()]

# ---------------- Customers ----------------

def customer_all():
    with connection.cursor() as cursor:
        cursor.execute("SELECT * FROM sales_app.fn_customer_get_all()")
        return dictfetchall(cursor)

def customer_search(keyword):
    with connection.cursor() as cursor:
        cursor.execute(
            "SELECT * FROM sales_app.fn_customer_search(%s)",
            [keyword],
        )
        return dictfetchall(cursor)

def customer_add(name, phone, address):
    with connection.cursor() as cursor:
        cursor.execute(
            "SELECT sales_app.fn_customer_add(%s, %s, %s)",
            [name, phone or None, address or None],
        )
        return cursor.fetchone()[0]

def customer_update(customer_id, name, phone, address):
    with connection.cursor() as cursor:
        cursor.execute(
            "SELECT sales_app.fn_customer_update(%s, %s, %s, %s)",
            [customer_id, name, phone or None, address or None],
        )
        return cursor.fetchone()[0]

def customer_delete(customer_id):
    with connection.cursor() as cursor:
        cursor.execute(
            "SELECT sales_app.fn_customer_delete(%s)",
            [customer_id],
        )
        return cursor.fetchone()[0]

def customer_get(customer_id):
    rows = customer_all()
    return next((r for r in rows if r["customer_id"] == customer_id), None)

# ---------------- Products ----------------

def product_all():
    with connection.cursor() as cursor:
        cursor.execute("SELECT * FROM sales_app.fn_product_get_all()")
        return dictfetchall(cursor)

def product_search(keyword):
    with connection.cursor() as cursor:
        cursor.execute(
            "SELECT * FROM sales_app.fn_product_search(%s)",
            [keyword],
        )
        return dictfetchall(cursor)

def product_add(name, price, stock):
    with connection.cursor() as cursor:
        cursor.execute(
            "SELECT sales_app.fn_product_add(%s, %s, %s)",
            [name, price, stock],
        )
        return cursor.fetchone()[0]

def product_update(product_id, name, price, stock):
    with connection.cursor() as cursor:
        cursor.execute(
            "SELECT sales_app.fn_product_update(%s, %s, %s, %s)",
            [product_id, name, price, stock],
        )
        return cursor.fetchone()[0]

def product_delete(product_id):
    with connection.cursor() as cursor:
        cursor.execute(
            "SELECT sales_app.fn_product_delete(%s)",
            [product_id],
        )
        return cursor.fetchone()[0]

def product_get(product_id):
    rows = product_all()
    return next((r for r in rows if r["product_id"] == product_id), None)

# ---------------- Sales ----------------

def sale_create(customer_id, product_id, quantity):
    payload = json.dumps([
        {
            "product_id": int(product_id),
            "quantity": int(quantity),
        }
    ])
    with connection.cursor() as cursor:
        cursor.execute(
            "SELECT sales_app.fn_create_sale(%s, %s::jsonb)",
            [customer_id, payload],
        )
        return cursor.fetchone()[0]

def sale_cancel(sale_id):
    with connection.cursor() as cursor:
        cursor.execute(
            "SELECT sales_app.fn_cancel_sale(%s)",
            [sale_id],
        )
        return cursor.fetchone()[0]

def sale_summary():
    with connection.cursor() as cursor:
        cursor.execute(
            "SELECT * FROM sales_app.vw_sales_summary ORDER BY sale_id DESC"
        )
        return dictfetchall(cursor)

def sale_detail(sale_id):
    with connection.cursor() as cursor:
        cursor.execute(
            "SELECT * FROM sales_app.fn_sale_detail(%s)",
            [sale_id],
        )
        return dictfetchall(cursor)

# ---------------- Reports ----------------

def product_stock_report():
    with connection.cursor() as cursor:
        cursor.execute(
            "SELECT * FROM sales_app.vw_product_stock ORDER BY product_id"
        )
        return dictfetchall(cursor)

def sales_report(start_date=None, end_date=None):
    with connection.cursor() as cursor:
        if start_date and end_date:
            cursor.execute(
                "SELECT * FROM sales_app.fn_sales_report(%s, %s)",
                [start_date, end_date],
            )
        else:
            cursor.execute(
                "SELECT * FROM sales_app.vw_sales_report "
                "ORDER BY sale_id DESC, product_id"
            )
        return dictfetchall(cursor)

def audit_recent(limit=20):
    # Dibaca hanya jika user DB memiliki izin SELECT ke audit_logs.
    # Untuk aplikasi asesmen sederhana, kita tidak tampilkan audit_logs di UI.
    return []

from django.contrib import messages
from django.db import DatabaseError
from django.shortcuts import redirect, render
from django.urls import reverse

from .forms import CustomerForm, ProductForm, SaleForm
from . import services

def db_error_message(exc):
    cause = getattr(exc, "__cause__", None)
    if cause:
        return str(cause).strip()
    return str(exc).strip()

def dashboard(request):
    try:
        customers = services.customer_all()
        products = services.product_all()
        sales = services.sale_summary()
    except DatabaseError as exc:
        customers, products, sales = [], [], []
        messages.error(request, db_error_message(exc))

    return render(
        request,
        "sales/dashboard.html",
        {
            "customer_count": len(customers),
            "product_count": len(products),
            "sale_count": len(sales),
            "latest_sales": sales[:5],
        },
    )

# ---------------- Customers ----------------

def customer_list(request):
    keyword = request.GET.get("q", "").strip()
    try:
        rows = (
            services.customer_search(keyword)
            if keyword
            else services.customer_all()
        )
    except DatabaseError as exc:
        rows = []
        messages.error(request, db_error_message(exc))

    return render(
        request,
        "sales/customer_list.html",
        {"customers": rows, "keyword": keyword},
    )

def customer_create(request):
    form = CustomerForm(request.POST or None)
    if request.method == "POST" and form.is_valid():
        try:
            services.customer_add(**form.cleaned_data)
            messages.success(request, "Pelanggan berhasil ditambahkan.")
            return redirect("customer_list")
        except DatabaseError as exc:
            messages.error(request, db_error_message(exc))

    return render(
        request,
        "sales/form.html",
        {"form": form, "title": "Tambah Pelanggan", "back_url": reverse("customer_list")},
    )

def customer_edit(request, customer_id):
    try:
        row = services.customer_get(customer_id)
    except DatabaseError as exc:
        messages.error(request, db_error_message(exc))
        return redirect("customer_list")

    if not row:
        messages.error(request, "Pelanggan tidak ditemukan.")
        return redirect("customer_list")

    initial = {
        "name": row["name"],
        "phone": row["phone"],
        "address": row["address"],
    }
    form = CustomerForm(request.POST or None, initial=initial)

    if request.method == "POST" and form.is_valid():
        try:
            services.customer_update(customer_id, **form.cleaned_data)
            messages.success(request, "Pelanggan berhasil diubah.")
            return redirect("customer_list")
        except DatabaseError as exc:
            messages.error(request, db_error_message(exc))

    return render(
        request,
        "sales/form.html",
        {"form": form, "title": "Ubah Pelanggan", "back_url": reverse("customer_list")},
    )

def customer_delete(request, customer_id):
    if request.method == "POST":
        try:
            services.customer_delete(customer_id)
            messages.success(request, "Pelanggan berhasil dihapus.")
        except DatabaseError as exc:
            messages.error(request, db_error_message(exc))
    return redirect("customer_list")

# ---------------- Products ----------------

def product_list(request):
    keyword = request.GET.get("q", "").strip()
    try:
        rows = (
            services.product_search(keyword)
            if keyword
            else services.product_all()
        )
    except DatabaseError as exc:
        rows = []
        messages.error(request, db_error_message(exc))

    return render(
        request,
        "sales/product_list.html",
        {"products": rows, "keyword": keyword},
    )

def product_create(request):
    form = ProductForm(request.POST or None)
    if request.method == "POST" and form.is_valid():
        try:
            services.product_add(**form.cleaned_data)
            messages.success(request, "Produk berhasil ditambahkan.")
            return redirect("product_list")
        except DatabaseError as exc:
            messages.error(request, db_error_message(exc))

    return render(
        request,
        "sales/form.html",
        {"form": form, "title": "Tambah Produk", "back_url": reverse("product_list")},
    )

def product_edit(request, product_id):
    try:
        row = services.product_get(product_id)
    except DatabaseError as exc:
        messages.error(request, db_error_message(exc))
        return redirect("product_list")

    if not row:
        messages.error(request, "Produk tidak ditemukan.")
        return redirect("product_list")

    initial = {
        "name": row["name"],
        "price": row["price"],
        "stock": row["stock"],
    }
    form = ProductForm(request.POST or None, initial=initial)

    if request.method == "POST" and form.is_valid():
        try:
            services.product_update(product_id, **form.cleaned_data)
            messages.success(request, "Produk berhasil diubah.")
            return redirect("product_list")
        except DatabaseError as exc:
            messages.error(request, db_error_message(exc))

    return render(
        request,
        "sales/form.html",
        {"form": form, "title": "Ubah Produk", "back_url": reverse("product_list")},
    )

def product_delete(request, product_id):
    if request.method == "POST":
        try:
            services.product_delete(product_id)
            messages.success(request, "Produk berhasil dihapus.")
        except DatabaseError as exc:
            messages.error(request, db_error_message(exc))
    return redirect("product_list")

# ---------------- Sales ----------------

def sale_list(request):
    try:
        rows = services.sale_summary()
    except DatabaseError as exc:
        rows = []
        messages.error(request, db_error_message(exc))

    return render(request, "sales/sale_list.html", {"sales": rows})

def sale_create(request):
    try:
        customers = services.customer_all()
        products = services.product_all()
    except DatabaseError as exc:
        customers, products = [], []
        messages.error(request, db_error_message(exc))

    form = SaleForm(
        request.POST or None,
        customers=customers,
        products=products,
    )

    if request.method == "POST" and form.is_valid():
        try:
            sale_id = services.sale_create(**form.cleaned_data)
            messages.success(
                request,
                f"Transaksi berhasil dibuat. ID transaksi: {sale_id}",
            )
            return redirect("sale_list")
        except DatabaseError as exc:
            messages.error(request, db_error_message(exc))

    return render(
        request,
        "sales/form.html",
        {"form": form, "title": "Transaksi Baru", "back_url": reverse("sale_list")},
    )

def sale_detail(request, sale_id):
    try:
        rows = services.sale_detail(sale_id)
    except DatabaseError as exc:
        rows = []
        messages.error(request, db_error_message(exc))

    return render(
        request,
        "sales/sale_detail.html",
        {"rows": rows, "sale_id": sale_id},
    )

def sale_cancel(request, sale_id):
    if request.method == "POST":
        try:
            services.sale_cancel(sale_id)
            messages.success(request, "Transaksi berhasil dibatalkan dan stok dikembalikan.")
        except DatabaseError as exc:
            messages.error(request, db_error_message(exc))
    return redirect("sale_list")

# ---------------- Reports ----------------

def report(request):
    start_date = request.GET.get("start_date", "")
    end_date = request.GET.get("end_date", "")

    try:
        sales_rows = services.sales_report(
            start_date or None,
            end_date or None,
        )
        stock_rows = services.product_stock_report()
    except DatabaseError as exc:
        sales_rows, stock_rows = [], []
        messages.error(request, db_error_message(exc))

    return render(
        request,
        "sales/report.html",
        {
            "sales_rows": sales_rows,
            "stock_rows": stock_rows,
            "start_date": start_date,
            "end_date": end_date,
        },
    )

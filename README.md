# Aplikasi Pengelolaan Data Penjualan

Stack:
- Python
- Django
- PostgreSQL
- pgAdmin 4

Aplikasi dibuat sederhana untuk kebutuhan asesmen. CRUD dan business logic utama
dijalankan melalui PostgreSQL function/procedure, bukan INSERT/UPDATE/DELETE langsung
dari Django.

## 1. Import database

Di pgAdmin 4, jalankan file SQL di folder `database` secara berurutan:

1. `01_schema_penjualan.sql`
2. `02_functions.sql`
3. `03_transaction.sql`
4. `04_triggers.sql`
5. `05_views.sql`
6. `06_roles_security.sql`
7. `07_testing.sql` (khusus pengujian)

Database yang digunakan: `db_penjualan`.

## 2. Siapkan Python

### Windows

```bat
python -m venv venv
venv\Scripts\activate
pip install -r requirements.txt
```

### Linux/macOS

```bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

## 3. Buat file .env

Salin `.env.example` menjadi `.env`.

Windows:

```bat
copy .env.example .env
```

Linux/macOS:

```bash
cp .env.example .env
```

Konfigurasi default:

```env
DB_NAME=db_penjualan
DB_USER=django_app_user
DB_PASSWORD=DjangoPenjualan_123!
DB_HOST=127.0.0.1
DB_PORT=5432
```

## 4. Jalankan Django

```bash
python manage.py runserver
```

Buka:

`http://127.0.0.1:8000/`

## Catatan penting

Project sengaja tidak memakai Django ORM untuk business data utama. File
`sales/services.py` memanggil function/procedure/view PostgreSQL menggunakan
`django.db.connection`.

UI transaksi dibuat sederhana: satu produk per submit. Function PostgreSQL
`fn_create_sale()` sendiri tetap mendukung banyak produk sekaligus dalam JSONB,
dan hal tersebut diuji di `07_testing.sql`.

## Halaman

- Dashboard
- Pelanggan
- Produk
- Transaksi
- Laporan

## Jika koneksi database gagal

Periksa:
- PostgreSQL sedang berjalan.
- `db_penjualan` sudah ada.
- `06_roles_security.sql` berhasil dijalankan.
- username/password pada `.env` sesuai.
- port PostgreSQL sesuai, umumnya `5432`.

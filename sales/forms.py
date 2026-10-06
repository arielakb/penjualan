from django import forms

class CustomerForm(forms.Form):
    name = forms.CharField(label="Nama", max_length=100)
    phone = forms.CharField(label="Telepon", max_length=20, required=False)
    address = forms.CharField(
        label="Alamat",
        required=False,
        widget=forms.Textarea(attrs={"rows": 3}),
    )

class ProductForm(forms.Form):
    name = forms.CharField(label="Nama Produk", max_length=100)
    price = forms.DecimalField(label="Harga", min_value=0, max_digits=12, decimal_places=2)
    stock = forms.IntegerField(label="Stok", min_value=0)

class SaleForm(forms.Form):
    customer_id = forms.ChoiceField(label="Pelanggan")
    product_id = forms.ChoiceField(label="Produk")
    quantity = forms.IntegerField(label="Jumlah", min_value=1)

    def __init__(self, *args, customers=None, products=None, **kwargs):
        super().__init__(*args, **kwargs)
        customers = customers or []
        products = products or []

        self.fields["customer_id"].choices = [
            (row["customer_id"], row["name"]) for row in customers
        ]
        self.fields["product_id"].choices = [
            (
                row["product_id"],
                f'{row["name"]} — stok {row["stock"]} — Rp {row["price"]:,.0f}',
            )
            for row in products
        ]

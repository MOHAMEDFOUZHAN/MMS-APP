import os
import psycopg2

PROJECT_REF = 'japxiaxyabhhhclphbqr'
PASSWORD = os.environ.get("SUPABASE_DB_PASSWORD", "")
HOST = 'aws-0-ap-northeast-1.pooler.supabase.com'
PORT = 5432
USER = f'postgres.{PROJECT_REF}'
DBNAME = 'postgres'

# Authoritative list extracted from both reference images
REFERENCE_PRODUCTS = [
    # Image 1 (17 items)
    "RASPEEEY RUBY",
    "RED WINE TRUFFLE",
    "ROASTED HAZELNUTS TRUFFLES",
    "ROYAL PISTACHIO KUNAFA CHOCOLATE",
    "RUM AND RAISIN TRUFFLES",
    "SALTED CARAMEL CREAM TRUFFLES",
    "STRAWBERRY SWIRL",
    "STRAWBERRY TRUFFLE",
    "SUGAR FREE CHO",
    "TROPICAL MANGAO DELIGHT",
    "VALANTINE SIGNATURE CHOCOLATE",
    "VENEZUELA",
    "WALNUT COCOA CRUNCH",
    "WHITE CRUNCH CHOCO",
    "WHITE HEART MILK CHOCOLATE",
    "WHITE RAISINS",
    "cutting and truffle sample",
    # Image 2 (61 items)
    "CLASSIC MILK CHOCOLATE",
    "MAPLE GLAZED ALMOND CHOCOLATE",
    "SINGLE ORIGIN ESTATE DARK 70 PERCENT",
    "3 IN 1 CHOCO",
    "46 PERCENT DARK CHOCOLATE",
    "ALMOND RAISINS BLISS",
    "ALMOND SILK",
    "ALMOND WITH BISCUIT CHOCO",
    "ALTO EL SOL",
    "ALUNGA CHOCOLATE",
    "AMARETTO ALMOND TRUFFLES",
    "ARABIAN DATES DELIGHT CHOCOLATE",
    "BAR",
    "BENCHMARK GRAND ASSORTED 250G",
    "BERRY CHOCO",
    "BLACK FOREST INDULGENCE TRUFFLE",
    "BLUE BERRY ROYALE TRUFFLE",
    "BLUEBERRY BLISS",
    "BRANDY PLUM CHOCOLATE DELIGHT",
    "BUTTER SCOTCH 100GMS",
    "BUTTER SCOTCH VELVET TRUFFLES",
    "BUTTERSCOTCH CHOCOLATE CRUNCH",
    "CARRY BAG SMALL",
    "CASHEW MILK ROYALE",
    "CHILLI DARK TRUFFLES",
    "CLASSIC DARK CHOCOLATE",
    "CLASSIC DARK TRUFFLE",
    "CLASSIC WHITE CHOCOLATE",
    "COCONUT CREAM TRUFFLES",
    "CRANBERRY RUBY TRUFFLES",
    "CRISPY COCOA CRUNCH TRUFFLES",
    "DARK 2 IN 1 CRUNCH",
    "DARK CRUNCH CHOCO",
    "DARK FRUIT AND NUT RESERVE",
    "DARK HAZELNUT LUXE",
    "DARK PEANUTS",
    "ECUADOR CHOCOLATE",
    "ESPRESSO COFFEE TRUFFLES",
    "EXCELLENCE",
    "FRUIT AND NUT HARMONY",
    "FUDGE",
    "GAHANA",
    "GOLDEN HONEY FIG TRUFFLE",
    "HAZELNUTS DARK",
    "HONEY FIG DELIGHT CHOCOLATE",
    "INAYA CHOCOLATE",
    "MALAGA",
    "MANGO PASSION FRUIT",
    "MILK 2 IN 1 CRUNCH CHOCO",
    "MILK CRUNCH CHOCO",
    "MILK HAZELNUTS CREAM",
    "MILK PEANUTS",
    "MILK TRUFFLE",
    "MINT TRUFFLES",
    "NUTRIBON ELITE",
    "NUTTIES",
    "PEANUT TRUFFLE",
    "PINEAPPLE TRUFFELS",
    "PISTACHIO CHOCO",
    "RASPBERRY VELVET",
    "RASPBERRY ROSE TRUFFLE",
]

def reconcile():
    print(f"Total reference products in supplied images: {len(REFERENCE_PRODUCTS)}")
    assert len(REFERENCE_PRODUCTS) == 78, f"Expected 78 products, got {len(REFERENCE_PRODUCTS)}"

    conn = psycopg2.connect(
        host=HOST, port=PORT, user=USER, password=PASSWORD, dbname=DBNAME, connect_timeout=15
    )
    cur = conn.cursor()

    cur.execute("SELECT product_code, product_name, category, uom FROM storage_products ORDER BY product_name;")
    existing = cur.fetchall()
    print(f"\nExisting storage_products ({len(existing)}):")
    existing_map = {}
    for r in existing:
        print(f"  - [{r[0]}] {r[1]} ({r[2]}, {r[3]})")
        existing_map[r[1].lower().strip()] = r

    to_add = []
    already_present = []

    for name in REFERENCE_PRODUCTS:
        norm = name.lower().strip()
        if norm in existing_map:
            already_present.append((name, existing_map[norm]))
        else:
            to_add.append(name)

    print(f"\nAlready present in DB storage_products: {len(already_present)}")
    for name, r in already_present:
        print(f"  ✓ {name} -> Code: {r[0]}")

    print(f"\nNew products from reference images not yet in storage_products: {len(to_add)}")
    for name in to_add:
        code = "TRAY-" + "".join([c if c.isalnum() else "-" for c in name.upper()]).strip("-")
        while "--" in code:
            code = code.replace("--", "-")
        print(f"  + {name} => {code}")

    conn.close()

if __name__ == '__main__':
    reconcile()

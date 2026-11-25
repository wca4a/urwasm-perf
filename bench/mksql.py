#!/usr/bin/env python3
"""mksql.py: write sql-work.txt, one request (one or more SQL statements) per line. Deterministic."""
import random
R = random.Random(20261125)
first = "Ada Grace Alan Linus Barbara Ken Dennis Margaret Edsger Donald Radia Tim Hedy Claude John Frances Jean Kay Guido Bjarne".split()
last = "Lovelace Hopper Turing Torvalds Liskov Thompson Ritchie Hamilton Dijkstra Knuth Perlman Lee Lamarr Shannon Backus Allen Bartik McNulty Rossum Stroustrup".split()
cities = "Lisbon Austin Kyoto Oslo Nairobi Lima Tallinn Denver Hanoi Zürich".split()
things = "kettle lamp notebook keyboard chair desk backpack bottle headphones monitor cable charger mug plant stool shelf rug clock fan pen".split()
adj = "red small oak steel quiet bright folding heavy tiny smart".split()
L = []
def q(s): L.append(" ".join(s.split()))
def s(x): return "'" + x.replace("'", "''") + "'"
q("""CREATE TABLE customers(id INTEGER PRIMARY KEY, name TEXT NOT NULL, email TEXT UNIQUE, city TEXT, joined TEXT, profile TEXT);
     CREATE TABLE products(id INTEGER PRIMARY KEY, name TEXT NOT NULL, price_cents INTEGER NOT NULL CHECK(price_cents > 0), stock INTEGER NOT NULL DEFAULT 0, description TEXT);
     CREATE TABLE orders(id INTEGER PRIMARY KEY, customer_id INTEGER NOT NULL REFERENCES customers(id), placed TEXT NOT NULL, status TEXT NOT NULL);
     CREATE TABLE order_items(order_id INTEGER NOT NULL REFERENCES orders(id), product_id INTEGER NOT NULL REFERENCES products(id), qty INTEGER NOT NULL, PRIMARY KEY(order_id, product_id)) WITHOUT ROWID;
     CREATE INDEX orders_by_customer ON orders(customer_id); CREATE INDEX orders_by_day ON orders(placed);
     CREATE TABLE audit(at TEXT, what TEXT);
     CREATE TRIGGER stock_watch AFTER UPDATE OF stock ON products WHEN new.stock < 5 BEGIN INSERT INTO audit VALUES('fixed', 'low stock: ' || new.name); END;
     CREATE VIRTUAL TABLE product_search USING fts5(name, description);
     PRAGMA foreign_keys = ON;""")
NC, NP, NO = 600, 200, 3000
for b in range(0, NC, 50):
    rows = []
    for i in range(b + 1, b + 51):
        f, l = R.choice(first), R.choice(last)
        prof = '{"vip":%s,"age":%d,"likes":["%s","%s"]}' % (R.choice(["true", "false"]), R.randint(18, 80), R.choice(things), R.choice(things))
        rows.append(f"({i},{s(f+' '+l)},{s(f'{f}.{l}{i}@example.com'.lower())},{s(R.choice(cities))},{s('20%02d-%02d-%02d' % (R.randint(18,26), R.randint(1,12), R.randint(1,28)))},{s(prof)})")
    q("INSERT INTO customers VALUES " + ",".join(rows))
for b in range(0, NP, 50):
    rows = []
    for i in range(b + 1, b + 51):
        n = f"{R.choice(adj)} {R.choice(things)}"; d = " ".join(R.choice(adj + things) for _ in range(R.randint(8, 30)))
        rows.append(f"({i},{s(n)},{R.randint(199, 49999)},{R.randint(0, 300)},{s(d)})")
    q("BEGIN; INSERT INTO products VALUES " + ",".join(rows) + f"; INSERT INTO product_search(rowid, name, description) SELECT id, name, description FROM products WHERE id > {b}; COMMIT")
for b in range(0, NO, 100):
    o, it = [], []
    for i in range(b + 1, b + 101):
        o.append(f"({i},{R.randint(1, NC)},{s('2026-%02d-%02d' % (R.randint(1,11), R.randint(1,28)))},{s(R.choice(['paid','paid','paid','shipped','refunded','open']))})")
        for p in R.sample(range(1, NP + 1), R.randint(1, 5)): it.append(f"({i},{p},{R.randint(1, 4)})")
    q("BEGIN; INSERT INTO orders VALUES " + ",".join(o) + "; INSERT INTO order_items VALUES " + ",".join(it) + "; COMMIT")
q("SELECT (SELECT count(*) FROM customers) AS customers, (SELECT count(*) FROM products) AS products, (SELECT count(*) FROM orders) AS orders, (SELECT count(*) FROM order_items) AS items")
q("CREATE VIEW order_totals AS SELECT o.id, o.customer_id, o.placed, o.status, sum(i.qty * p.price_cents) AS cents FROM orders o JOIN order_items i ON i.order_id = o.id JOIN products p ON p.id = i.product_id GROUP BY o.id")
reads = [
 lambda: f"SELECT * FROM customers WHERE id = {R.randint(1, NC)}",
 lambda: f"SELECT o.id, o.placed, o.status, t.cents FROM orders o JOIN order_totals t ON t.id = o.id WHERE o.customer_id = {R.randint(1, NC)} ORDER BY o.placed DESC",
 lambda: f"SELECT p.name, i.qty, p.price_cents, i.qty * p.price_cents AS line FROM order_items i JOIN products p ON p.id = i.product_id WHERE i.order_id = {R.randint(1, NO)}",
 lambda: f"SELECT city, count(*) AS n, round(avg(json_extract(profile, '$.age')), 2) AS avg_age FROM customers GROUP BY city ORDER BY n DESC, city",
 lambda: f"SELECT name, price_cents FROM products WHERE name LIKE {s('%' + R.choice(things) + '%')} ORDER BY price_cents LIMIT 20",
 lambda: f"SELECT rowid, name, snippet(product_search, 1, '[', ']', '...', 6) AS hit FROM product_search WHERE product_search MATCH {s(R.choice(things) + ' OR ' + R.choice(adj))} ORDER BY rank LIMIT 10",
 lambda: f"SELECT placed, count(*) AS orders FROM orders WHERE placed BETWEEN '2026-{R.randint(1,6):02d}-01' AND '2026-{R.randint(7,11):02d}-28' GROUP BY placed ORDER BY orders DESC, placed LIMIT 15",
 lambda: f"SELECT c.name, sum(t.cents) / 100.0 AS spent, rank() OVER (ORDER BY sum(t.cents) DESC) AS place FROM order_totals t JOIN customers c ON c.id = t.customer_id WHERE t.status <> 'refunded' AND c.city = {s(R.choice(cities))} GROUP BY c.id ORDER BY place LIMIT 10",
 lambda: f"WITH monthly AS (SELECT substr(placed, 1, 7) AS month, sum(cents) AS cents FROM order_totals GROUP BY 1) SELECT month, cents, sum(cents) OVER (ORDER BY month) AS running, round(100.0 * cents / sum(cents) OVER (), 2) AS pct FROM monthly",
 lambda: f"SELECT json_group_array(json_object('id', id, 'name', name)) AS j FROM (SELECT id, name FROM products ORDER BY stock LIMIT {R.randint(3, 12)})",
 lambda: f"WITH RECURSIVE fib(n, a, b) AS (SELECT 1, 0, 1 UNION ALL SELECT n + 1, b, a + b FROM fib WHERE n < {R.randint(20, 80)}) SELECT n, a FROM fib ORDER BY n DESC LIMIT 5",
 lambda: f"SELECT round(sqrt({R.randint(2, 9999)}), 6) AS root, round(ln({R.randint(2, 9999)}), 6) AS ln, pi() AS pi, {R.randint(1, 10**9)} * {R.randint(1, 10**9)} AS big, 1.0 / {R.randint(3, 97)} AS frac, hex(zeroblob(4)) AS z, upper('straße ünï 東京') AS up",
 lambda: f"SELECT p.name, sum(i.qty) AS sold FROM order_items i JOIN products p ON p.id = i.product_id GROUP BY p.id HAVING sold > {R.randint(40, 70)} ORDER BY sold DESC, p.name LIMIT 10",
 lambda: f"EXPLAIN QUERY PLAN SELECT * FROM orders WHERE customer_id = {R.randint(1, NC)} AND placed > '2026-06-01'",
 lambda: f"SELECT c.id, c.name FROM customers c WHERE NOT EXISTS (SELECT 1 FROM orders o WHERE o.customer_id = c.id) ORDER BY c.id LIMIT 10",
 lambda: f"SELECT * FROM order_totals ORDER BY cents DESC LIMIT {R.randint(600, 900)}",
]
writes = [
 lambda: f"UPDATE products SET stock = stock - {R.randint(1, 60)} WHERE id = {R.randint(1, NP)} AND stock >= 60; SELECT changes() AS changed, (SELECT count(*) FROM audit) AS audit_rows",
 lambda: f"UPDATE products SET stock = {R.randint(0, 4)} WHERE id = {R.randint(1, NP)}",
 lambda: f"UPDATE orders SET status = 'shipped' WHERE status = 'paid' AND placed < '2026-{R.randint(1,11):02d}-15'",
 lambda: f"BEGIN; DELETE FROM order_items WHERE order_id = {R.randint(1, NO)}; SELECT count(*) AS left FROM order_items; ROLLBACK; SELECT count(*) AS after_rollback FROM order_items",
 lambda: f"INSERT INTO customers(name, email, city, joined, profile) VALUES ({s(R.choice(first) + ' ' + R.choice(last))}, {s('new%d@example.com' % R.randint(1, 10**9))}, {s(R.choice(cities))}, '2026-11-25', '{{}}') RETURNING id, name",
 lambda: f"DELETE FROM audit WHERE rowid IN (SELECT rowid FROM audit ORDER BY rowid LIMIT {R.randint(1, 3)})",
]
host = [  # these need the ship: the clock and random numbers
 lambda: "SELECT datetime('now') AS now, date('now', '+7 days') AS next_week, strftime('%s', 'now') AS unix, julianday('now') AS jd",
 lambda: f"INSERT INTO audit VALUES (datetime('now'), 'checked {R.randint(1, 999)}') RETURNING *",
 lambda: "SELECT random() AS r, abs(random()) % 100 AS dice, hex(randomblob(8)) AS blob",
 lambda: "SELECT id, name FROM products ORDER BY random() LIMIT 3",
]
bad = ["SELEC * FROM customers", "SELECT * FROM nowhere", "INSERT INTO products VALUES (1, 'dup', 100, 1, 'x')", "INSERT INTO products(name, price_cents) VALUES ('free', 0)",
       "INSERT INTO orders VALUES (999999, 999999, '2026-01-01', 'paid')", "SELECT 1; SELECT 2; SELECT * FROM missing; SELECT 4", "   -- only a comment", "SELECT 1 / 0 AS div, NULL AS nothing, x'00ff' AS blob, 1e999 AS inf"]
for i in range(300):
    k = R.random()
    q((R.choice(reads) if k < .70 else R.choice(writes) if k < .88 else R.choice(host))())
    if i % 40 == 7: q(bad[(i // 40) % len(bad)])
for b in bad: q(b)
q("PRAGMA integrity_check; PRAGMA foreign_key_check; SELECT count(*) AS audit_rows FROM audit; SELECT sqlite_version() AS version")
q("SELECT 'customers' AS t, count(*) AS n, sum(length(name)) AS chk FROM customers UNION ALL SELECT 'orders', count(*), sum(customer_id) FROM orders UNION ALL SELECT 'items', count(*), sum(qty) FROM order_items UNION ALL SELECT 'products', count(*), sum(stock) FROM products")
open("sql-work.txt", "w").write("\n".join(L) + "\n")
print(len(L), "requests,", sum(len(x) for x in L), "bytes")

# K2 Aero Services Corp. database

This repository describes how K2 Aero Services Corp. stores its data. It holds a
PostgreSQL 16 schema in plain SQL and a way to run it locally. There is no
application code and no demo data.

## Run it

You need Docker.

```
make up        # start PostgreSQL 16 on localhost:5433
make migrate   # create the schema
make check     # confirm the rules hold
make psql      # open a prompt
make down      # stop (data is kept)
make reset     # remove all data and start empty
```

Connection: host `localhost`, port `5433`, database `k2`, user `k2`, password `k2`.

## Files

- `migrations/0001_schema_and_helpers.sql`: schema `k2` and two trigger functions
- `migrations/0002_tables.sql`: every table, its keys and its rules
- `migrations/0003_indexes.sql`: indexes
- `migrations/0004_triggers.sql`: `updated_at` and append-only triggers
- `checks/checks.sql`: checks that the rules are enforced

`make migrate` runs each file once, in order, in one transaction, and records it
in `public.schema_migrations`.

## What is stored

All tables live in schema `k2`.

| Area | Tables |
| --- | --- |
| People and companies | users, customers, suppliers, contacts, addresses |
| Parts | parts, part_revisions, part_operations |
| Sales | rfqs, rfq_lines, quotes, quote_lines, customer_pos, sales_orders, sales_order_lines |
| Production | work_orders, work_order_operations |
| Purchasing and stock | materials, locations, purchase_orders, purchase_order_lines, lots, inventory_transactions |
| Quality | inspections, ncrs |
| Shipping and invoicing | shipments, shipment_lines, invoices, invoice_lines |
| Files and history | documents, audit_log |

How the main records connect:

- A customer owns parts. A part has revisions; only one can be released at a time.
  A revision lists its operations in sequence.
- An RFQ leads to a quote. A customer PO may refer to a quote. A sales order is
  opened against a customer PO.
- A work order makes a part revision, usually for a sales order line. It has its
  own list of operations.
- Purchase orders buy material from suppliers. Received material becomes a lot.
  Stock is the sum of inventory transactions for a lot at a location.
- Inspections and NCRs refer to a work order, an operation or a lot.
- Shipments send sales order lines. Invoices bill shipment lines.
- Documents point to any record by `record_type` and `record_id`. The file itself
  is kept outside the database.

## Rules

- Every table has `id` (uuid), `created_at` and `updated_at`. A trigger keeps
  `updated_at` current. `audit_log` is the exception: it has a numeric `id` and no
  `updated_at`.
- Human numbers (Q-2026-0001, WO-2026-0001) are their own columns and must be
  unique. Nothing generates them yet.
- Status and kind columns are text with a fixed list of allowed values.
- Money and quantities are `numeric(18,6)` and cannot be negative. The exception is
  `inventory_transactions.quantity`: positive adds stock, negative removes it, and
  zero is not allowed.
- A calendar day is a `date`; a moment in time is a `timestamptz`.
- A row that other rows depend on cannot be deleted. Lines are deleted with their
  header.
- A contact or address belongs to exactly one customer or one supplier.
- `inventory_transactions` and `audit_log` are append-only: rows can be added but
  never changed or deleted.
- Nothing writes to `audit_log` automatically yet.

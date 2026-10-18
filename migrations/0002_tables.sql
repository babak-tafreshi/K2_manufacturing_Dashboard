-- 0002: all tables, in dependency order.
-- Every table except audit_log has id, created_at and updated_at.

set search_path = k2;

------------------------------------------------------------------------
-- People and companies
------------------------------------------------------------------------

create table users (
    id          uuid not null default gen_random_uuid(),
    created_at  timestamptz not null default now(),
    updated_at  timestamptz not null default now(),
    username    varchar not null,
    full_name   varchar not null,
    email       varchar,
    is_active   boolean not null default true,
    constraint pk_users primary key (id),
    constraint uq_users_username unique (username)
);

create table customers (
    id             uuid not null default gen_random_uuid(),
    created_at     timestamptz not null default now(),
    updated_at     timestamptz not null default now(),
    code           varchar not null,
    name           varchar not null,
    status         varchar not null,
    currency       char(3) not null default 'CAD',
    payment_terms  varchar,
    notes          text,
    constraint pk_customers primary key (id),
    constraint uq_customers_code unique (code),
    constraint ck_customers_status check (status in ('active', 'inactive'))
);

create table suppliers (
    id          uuid not null default gen_random_uuid(),
    created_at  timestamptz not null default now(),
    updated_at  timestamptz not null default now(),
    code        varchar not null,
    name        varchar not null,
    status      varchar not null,
    notes       text,
    constraint pk_suppliers primary key (id),
    constraint uq_suppliers_code unique (code),
    constraint ck_suppliers_status check (status in ('pending', 'approved', 'inactive'))
);

create table contacts (
    id           uuid not null default gen_random_uuid(),
    created_at   timestamptz not null default now(),
    updated_at   timestamptz not null default now(),
    customer_id  uuid,
    supplier_id  uuid,
    name         varchar not null,
    email        varchar,
    phone        varchar,
    job_title    varchar,
    constraint pk_contacts primary key (id),
    constraint fk_contacts_customer_id foreign key (customer_id) references customers (id) on delete restrict,
    constraint fk_contacts_supplier_id foreign key (supplier_id) references suppliers (id) on delete restrict,
    constraint ck_contacts_one_owner check (num_nonnulls(customer_id, supplier_id) = 1)
);

create table addresses (
    id           uuid not null default gen_random_uuid(),
    created_at   timestamptz not null default now(),
    updated_at   timestamptz not null default now(),
    customer_id  uuid,
    supplier_id  uuid,
    kind         varchar not null,
    line1        varchar not null,
    line2        varchar,
    city         varchar not null,
    province     varchar,
    postal_code  varchar,
    country      varchar not null,
    constraint pk_addresses primary key (id),
    constraint fk_addresses_customer_id foreign key (customer_id) references customers (id) on delete restrict,
    constraint fk_addresses_supplier_id foreign key (supplier_id) references suppliers (id) on delete restrict,
    constraint ck_addresses_one_owner check (num_nonnulls(customer_id, supplier_id) = 1),
    constraint ck_addresses_kind check (kind in ('billing', 'shipping'))
);

------------------------------------------------------------------------
-- Parts
------------------------------------------------------------------------

create table parts (
    id           uuid not null default gen_random_uuid(),
    created_at   timestamptz not null default now(),
    updated_at   timestamptz not null default now(),
    customer_id  uuid not null,
    part_number  varchar not null,
    description  varchar,
    constraint pk_parts primary key (id),
    constraint fk_parts_customer_id foreign key (customer_id) references customers (id) on delete restrict,
    constraint uq_parts_customer_id_part_number unique (customer_id, part_number)
);

create table part_revisions (
    id           uuid not null default gen_random_uuid(),
    created_at   timestamptz not null default now(),
    updated_at   timestamptz not null default now(),
    part_id      uuid not null,
    revision     varchar not null,
    status       varchar not null,
    released_at  timestamptz,
    constraint pk_part_revisions primary key (id),
    constraint fk_part_revisions_part_id foreign key (part_id) references parts (id) on delete restrict,
    constraint uq_part_revisions_part_id_revision unique (part_id, revision),
    constraint ck_part_revisions_status check (status in ('draft', 'released', 'obsolete'))
);
-- One released revision per part: see uq_part_revisions_part_id_released in 0003.

create table part_operations (
    id                uuid not null default gen_random_uuid(),
    created_at        timestamptz not null default now(),
    updated_at        timestamptz not null default now(),
    part_revision_id  uuid not null,
    sequence          int not null,
    name              varchar not null,
    work_centre       varchar,
    process_spec      varchar,
    is_outside        boolean not null default false,
    constraint pk_part_operations primary key (id),
    constraint fk_part_operations_part_revision_id foreign key (part_revision_id) references part_revisions (id) on delete cascade,
    constraint uq_part_operations_part_revision_id_sequence unique (part_revision_id, sequence)
);

------------------------------------------------------------------------
-- Sales
------------------------------------------------------------------------

create table rfqs (
    id           uuid not null default gen_random_uuid(),
    created_at   timestamptz not null default now(),
    updated_at   timestamptz not null default now(),
    rfq_number   varchar not null,
    customer_id  uuid not null,
    received_on  date not null,
    due_on       date,
    status       varchar not null,
    constraint pk_rfqs primary key (id),
    constraint uq_rfqs_rfq_number unique (rfq_number),
    constraint fk_rfqs_customer_id foreign key (customer_id) references customers (id) on delete restrict,
    constraint ck_rfqs_status check (status in ('open', 'quoted', 'declined', 'closed'))
);

create table rfq_lines (
    id          uuid not null default gen_random_uuid(),
    created_at  timestamptz not null default now(),
    updated_at  timestamptz not null default now(),
    rfq_id      uuid not null,
    line_no     int not null,
    part_id     uuid not null,
    quantity    numeric(18,6) not null,
    constraint pk_rfq_lines primary key (id),
    constraint fk_rfq_lines_rfq_id foreign key (rfq_id) references rfqs (id) on delete cascade,
    constraint fk_rfq_lines_part_id foreign key (part_id) references parts (id) on delete restrict,
    constraint uq_rfq_lines_rfq_id_line_no unique (rfq_id, line_no),
    constraint ck_rfq_lines_quantity_not_negative check (quantity >= 0)
);

create table quotes (
    id            uuid not null default gen_random_uuid(),
    created_at    timestamptz not null default now(),
    updated_at    timestamptz not null default now(),
    quote_number  varchar not null,
    customer_id   uuid not null,
    rfq_id        uuid,
    status        varchar not null,
    valid_until   date,
    currency      char(3) not null default 'CAD',
    constraint pk_quotes primary key (id),
    constraint uq_quotes_quote_number unique (quote_number),
    constraint fk_quotes_customer_id foreign key (customer_id) references customers (id) on delete restrict,
    constraint fk_quotes_rfq_id foreign key (rfq_id) references rfqs (id) on delete restrict,
    constraint ck_quotes_status check (status in ('draft', 'sent', 'won', 'lost', 'expired'))
);

create table quote_lines (
    id                uuid not null default gen_random_uuid(),
    created_at        timestamptz not null default now(),
    updated_at        timestamptz not null default now(),
    quote_id          uuid not null,
    line_no           int not null,
    part_revision_id  uuid not null,
    quantity          numeric(18,6) not null,
    unit_price        numeric(18,6) not null,
    lead_time_days    int,
    constraint pk_quote_lines primary key (id),
    constraint fk_quote_lines_quote_id foreign key (quote_id) references quotes (id) on delete cascade,
    constraint fk_quote_lines_part_revision_id foreign key (part_revision_id) references part_revisions (id) on delete restrict,
    constraint uq_quote_lines_quote_id_line_no unique (quote_id, line_no),
    constraint ck_quote_lines_quantity_not_negative check (quantity >= 0),
    constraint ck_quote_lines_unit_price_not_negative check (unit_price >= 0)
);

create table customer_pos (
    id           uuid not null default gen_random_uuid(),
    created_at   timestamptz not null default now(),
    updated_at   timestamptz not null default now(),
    customer_id  uuid not null,
    po_number    varchar not null,
    quote_id     uuid,
    received_on  date not null,
    constraint pk_customer_pos primary key (id),
    constraint fk_customer_pos_customer_id foreign key (customer_id) references customers (id) on delete restrict,
    constraint fk_customer_pos_quote_id foreign key (quote_id) references quotes (id) on delete restrict,
    constraint uq_customer_pos_customer_id_po_number unique (customer_id, po_number)
);

create table sales_orders (
    id              uuid not null default gen_random_uuid(),
    created_at      timestamptz not null default now(),
    updated_at      timestamptz not null default now(),
    so_number       varchar not null,
    customer_id     uuid not null,
    customer_po_id  uuid not null,
    status          varchar not null,
    constraint pk_sales_orders primary key (id),
    constraint uq_sales_orders_so_number unique (so_number),
    constraint fk_sales_orders_customer_id foreign key (customer_id) references customers (id) on delete restrict,
    constraint fk_sales_orders_customer_po_id foreign key (customer_po_id) references customer_pos (id) on delete restrict,
    constraint ck_sales_orders_status check (status in ('open', 'in_production', 'shipped', 'closed', 'cancelled'))
);

create table sales_order_lines (
    id                uuid not null default gen_random_uuid(),
    created_at        timestamptz not null default now(),
    updated_at        timestamptz not null default now(),
    sales_order_id    uuid not null,
    line_no           int not null,
    part_revision_id  uuid not null,
    quantity          numeric(18,6) not null,
    unit_price        numeric(18,6) not null,
    due_on            date,
    constraint pk_sales_order_lines primary key (id),
    constraint fk_sales_order_lines_sales_order_id foreign key (sales_order_id) references sales_orders (id) on delete cascade,
    constraint fk_sales_order_lines_part_revision_id foreign key (part_revision_id) references part_revisions (id) on delete restrict,
    constraint uq_sales_order_lines_sales_order_id_line_no unique (sales_order_id, line_no),
    constraint ck_sales_order_lines_quantity_not_negative check (quantity >= 0),
    constraint ck_sales_order_lines_unit_price_not_negative check (unit_price >= 0)
);

------------------------------------------------------------------------
-- Production
------------------------------------------------------------------------

create table work_orders (
    id                   uuid not null default gen_random_uuid(),
    created_at           timestamptz not null default now(),
    updated_at           timestamptz not null default now(),
    wo_number            varchar not null,
    sales_order_line_id  uuid,
    part_revision_id     uuid not null,
    quantity             numeric(18,6) not null,
    status               varchar not null,
    due_on               date,
    constraint pk_work_orders primary key (id),
    constraint uq_work_orders_wo_number unique (wo_number),
    constraint fk_work_orders_sales_order_line_id foreign key (sales_order_line_id) references sales_order_lines (id) on delete restrict,
    constraint fk_work_orders_part_revision_id foreign key (part_revision_id) references part_revisions (id) on delete restrict,
    constraint ck_work_orders_quantity_not_negative check (quantity >= 0),
    constraint ck_work_orders_status check (status in ('planned', 'released', 'in_progress', 'on_hold', 'complete', 'closed'))
);

create table work_order_operations (
    id             uuid not null default gen_random_uuid(),
    created_at     timestamptz not null default now(),
    updated_at     timestamptz not null default now(),
    work_order_id  uuid not null,
    sequence       int not null,
    name           varchar not null,
    status         varchar not null,
    completed_by   uuid,
    completed_at   timestamptz,
    constraint pk_work_order_operations primary key (id),
    constraint fk_work_order_operations_work_order_id foreign key (work_order_id) references work_orders (id) on delete cascade,
    constraint fk_work_order_operations_completed_by foreign key (completed_by) references users (id) on delete restrict,
    constraint uq_work_order_operations_work_order_id_sequence unique (work_order_id, sequence),
    constraint ck_work_order_operations_status check (status in ('pending', 'in_progress', 'done', 'skipped'))
);

------------------------------------------------------------------------
-- Purchasing and stock
------------------------------------------------------------------------

create table materials (
    id             uuid not null default gen_random_uuid(),
    created_at     timestamptz not null default now(),
    updated_at     timestamptz not null default now(),
    code           varchar not null,
    description    varchar not null,
    unit           varchar not null,
    specification  varchar,
    constraint pk_materials primary key (id),
    constraint uq_materials_code unique (code),
    constraint ck_materials_unit check (unit in ('ea', 'kg', 'g', 'l', 'ml', 'm', 'ft', 'in'))
);

create table locations (
    id          uuid not null default gen_random_uuid(),
    created_at  timestamptz not null default now(),
    updated_at  timestamptz not null default now(),
    code        varchar not null,
    name        varchar not null,
    building    varchar,
    constraint pk_locations primary key (id),
    constraint uq_locations_code unique (code)
);

create table purchase_orders (
    id           uuid not null default gen_random_uuid(),
    created_at   timestamptz not null default now(),
    updated_at   timestamptz not null default now(),
    po_number    varchar not null,
    supplier_id  uuid not null,
    status       varchar not null,
    ordered_on   date,
    constraint pk_purchase_orders primary key (id),
    constraint uq_purchase_orders_po_number unique (po_number),
    constraint fk_purchase_orders_supplier_id foreign key (supplier_id) references suppliers (id) on delete restrict,
    constraint ck_purchase_orders_status check (status in ('draft', 'sent', 'partly_received', 'received', 'closed', 'cancelled'))
);

create table purchase_order_lines (
    id                 uuid not null default gen_random_uuid(),
    created_at         timestamptz not null default now(),
    updated_at         timestamptz not null default now(),
    purchase_order_id  uuid not null,
    line_no            int not null,
    material_id        uuid,
    work_order_id      uuid,
    description        varchar not null,
    quantity           numeric(18,6) not null,
    unit_price         numeric(18,6) not null,
    constraint pk_purchase_order_lines primary key (id),
    constraint fk_purchase_order_lines_purchase_order_id foreign key (purchase_order_id) references purchase_orders (id) on delete cascade,
    constraint fk_purchase_order_lines_material_id foreign key (material_id) references materials (id) on delete restrict,
    constraint fk_purchase_order_lines_work_order_id foreign key (work_order_id) references work_orders (id) on delete restrict,
    constraint uq_purchase_order_lines_purchase_order_id_line_no unique (purchase_order_id, line_no),
    constraint ck_purchase_order_lines_quantity_not_negative check (quantity >= 0),
    constraint ck_purchase_order_lines_unit_price_not_negative check (unit_price >= 0)
);

create table lots (
    id                      uuid not null default gen_random_uuid(),
    created_at              timestamptz not null default now(),
    updated_at              timestamptz not null default now(),
    lot_number              varchar not null,
    material_id             uuid not null,
    supplier_id             uuid,
    purchase_order_line_id  uuid,
    heat_number             varchar,
    cert_received           boolean not null default false,
    status                  varchar not null,
    received_on             date,
    expires_on              date,
    constraint pk_lots primary key (id),
    constraint uq_lots_lot_number unique (lot_number),
    constraint fk_lots_material_id foreign key (material_id) references materials (id) on delete restrict,
    constraint fk_lots_supplier_id foreign key (supplier_id) references suppliers (id) on delete restrict,
    constraint fk_lots_purchase_order_line_id foreign key (purchase_order_line_id) references purchase_order_lines (id) on delete restrict,
    constraint ck_lots_status check (status in ('quarantine', 'accepted', 'rejected'))
);

-- Append-only: rows are never changed or removed (see 0004).
-- quantity is signed: positive adds stock, negative removes it.
create table inventory_transactions (
    id             uuid not null default gen_random_uuid(),
    created_at     timestamptz not null default now(),
    updated_at     timestamptz not null default now(),
    lot_id         uuid not null,
    location_id    uuid not null,
    kind           varchar not null,
    quantity       numeric(18,6) not null,
    work_order_id  uuid,
    user_id        uuid not null,
    occurred_at    timestamptz not null default now(),
    note           text,
    constraint pk_inventory_transactions primary key (id),
    constraint fk_inventory_transactions_lot_id foreign key (lot_id) references lots (id) on delete restrict,
    constraint fk_inventory_transactions_location_id foreign key (location_id) references locations (id) on delete restrict,
    constraint fk_inventory_transactions_work_order_id foreign key (work_order_id) references work_orders (id) on delete restrict,
    constraint fk_inventory_transactions_user_id foreign key (user_id) references users (id) on delete restrict,
    constraint ck_inventory_transactions_kind check (kind in ('receive', 'issue', 'move_in', 'move_out', 'adjust', 'return', 'scrap')),
    constraint ck_inventory_transactions_quantity_not_zero check (quantity <> 0)
);

------------------------------------------------------------------------
-- Quality
------------------------------------------------------------------------

create table inspections (
    id                         uuid not null default gen_random_uuid(),
    created_at                 timestamptz not null default now(),
    updated_at                 timestamptz not null default now(),
    work_order_id              uuid,
    work_order_operation_id    uuid,
    lot_id                     uuid,
    kind                       varchar not null,
    result                     varchar not null,
    inspected_by               uuid not null,
    inspected_at               timestamptz not null,
    notes                      text,
    constraint pk_inspections primary key (id),
    constraint fk_inspections_work_order_id foreign key (work_order_id) references work_orders (id) on delete restrict,
    constraint fk_inspections_work_order_operation_id foreign key (work_order_operation_id) references work_order_operations (id) on delete restrict,
    constraint fk_inspections_lot_id foreign key (lot_id) references lots (id) on delete restrict,
    constraint fk_inspections_inspected_by foreign key (inspected_by) references users (id) on delete restrict,
    constraint ck_inspections_kind check (kind in ('receiving', 'in_process', 'final', 'first_article')),
    constraint ck_inspections_result check (result in ('pass', 'fail'))
);

create table ncrs (
    id             uuid not null default gen_random_uuid(),
    created_at     timestamptz not null default now(),
    updated_at     timestamptz not null default now(),
    ncr_number     varchar not null,
    work_order_id  uuid,
    lot_id         uuid,
    description    text not null,
    disposition    varchar,
    status         varchar not null,
    raised_by      uuid not null,
    constraint pk_ncrs primary key (id),
    constraint uq_ncrs_ncr_number unique (ncr_number),
    constraint fk_ncrs_work_order_id foreign key (work_order_id) references work_orders (id) on delete restrict,
    constraint fk_ncrs_lot_id foreign key (lot_id) references lots (id) on delete restrict,
    constraint fk_ncrs_raised_by foreign key (raised_by) references users (id) on delete restrict,
    constraint ck_ncrs_disposition check (disposition in ('use_as_is', 'rework', 'scrap', 'return_to_supplier')),
    constraint ck_ncrs_status check (status in ('open', 'dispositioned', 'closed'))
);

------------------------------------------------------------------------
-- Shipping and invoicing
------------------------------------------------------------------------

create table shipments (
    id               uuid not null default gen_random_uuid(),
    created_at       timestamptz not null default now(),
    updated_at       timestamptz not null default now(),
    shipment_number  varchar not null,
    customer_id      uuid not null,
    sales_order_id   uuid not null,
    status           varchar not null,
    shipped_on       date,
    carrier          varchar,
    tracking_number  varchar,
    constraint pk_shipments primary key (id),
    constraint uq_shipments_shipment_number unique (shipment_number),
    constraint fk_shipments_customer_id foreign key (customer_id) references customers (id) on delete restrict,
    constraint fk_shipments_sales_order_id foreign key (sales_order_id) references sales_orders (id) on delete restrict,
    constraint ck_shipments_status check (status in ('draft', 'packed', 'shipped', 'delivered'))
);

create table shipment_lines (
    id                   uuid not null default gen_random_uuid(),
    created_at           timestamptz not null default now(),
    updated_at           timestamptz not null default now(),
    shipment_id          uuid not null,
    sales_order_line_id  uuid not null,
    work_order_id        uuid,
    quantity             numeric(18,6) not null,
    constraint pk_shipment_lines primary key (id),
    constraint fk_shipment_lines_shipment_id foreign key (shipment_id) references shipments (id) on delete cascade,
    constraint fk_shipment_lines_sales_order_line_id foreign key (sales_order_line_id) references sales_order_lines (id) on delete restrict,
    constraint fk_shipment_lines_work_order_id foreign key (work_order_id) references work_orders (id) on delete restrict,
    constraint ck_shipment_lines_quantity_not_negative check (quantity >= 0)
);

create table invoices (
    id              uuid not null default gen_random_uuid(),
    created_at      timestamptz not null default now(),
    updated_at      timestamptz not null default now(),
    invoice_number  varchar not null,
    customer_id     uuid not null,
    sales_order_id  uuid,
    status          varchar not null,
    issued_on       date,
    due_on          date,
    currency        char(3) not null default 'CAD',
    subtotal        numeric(18,6) not null default 0,
    tax             numeric(18,6) not null default 0,
    total           numeric(18,6) not null default 0,
    constraint pk_invoices primary key (id),
    constraint uq_invoices_invoice_number unique (invoice_number),
    constraint fk_invoices_customer_id foreign key (customer_id) references customers (id) on delete restrict,
    constraint fk_invoices_sales_order_id foreign key (sales_order_id) references sales_orders (id) on delete restrict,
    constraint ck_invoices_status check (status in ('draft', 'issued', 'paid', 'void'))
);

create table invoice_lines (
    id                uuid not null default gen_random_uuid(),
    created_at        timestamptz not null default now(),
    updated_at        timestamptz not null default now(),
    invoice_id        uuid not null,
    line_no           int not null,
    shipment_line_id  uuid,
    description       varchar not null,
    quantity          numeric(18,6) not null,
    unit_price        numeric(18,6) not null,
    amount            numeric(18,6) not null,
    constraint pk_invoice_lines primary key (id),
    constraint fk_invoice_lines_invoice_id foreign key (invoice_id) references invoices (id) on delete cascade,
    constraint fk_invoice_lines_shipment_line_id foreign key (shipment_line_id) references shipment_lines (id) on delete restrict,
    constraint uq_invoice_lines_invoice_id_line_no unique (invoice_id, line_no),
    constraint ck_invoice_lines_quantity_not_negative check (quantity >= 0),
    constraint ck_invoice_lines_unit_price_not_negative check (unit_price >= 0)
);

------------------------------------------------------------------------
-- Files and history
------------------------------------------------------------------------

-- The file itself lives outside the database; storage_key says where.
-- record_type and record_id point at the row the file belongs to (any table).
create table documents (
    id           uuid not null default gen_random_uuid(),
    created_at   timestamptz not null default now(),
    updated_at   timestamptz not null default now(),
    title        varchar not null,
    file_name    varchar not null,
    storage_key  varchar not null,
    mime_type    varchar,
    size_bytes   bigint,
    uploaded_by  uuid not null,
    record_type  varchar not null,
    record_id    uuid not null,
    constraint pk_documents primary key (id),
    constraint fk_documents_uploaded_by foreign key (uploaded_by) references users (id) on delete restrict
);

-- Append-only (see 0004). No updated_at.
create table audit_log (
    id           bigint generated always as identity,
    occurred_at  timestamptz not null default now(),
    user_id      uuid,
    table_name   varchar not null,
    record_id    uuid not null,
    action       varchar not null,
    before       jsonb,
    after        jsonb,
    constraint pk_audit_log primary key (id),
    constraint fk_audit_log_user_id foreign key (user_id) references users (id) on delete restrict,
    constraint ck_audit_log_action check (action in ('insert', 'update', 'delete'))
);

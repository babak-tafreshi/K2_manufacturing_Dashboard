-- 0003: indexes.
-- One index on every foreign key column, plus the two indexes the design calls for.

set search_path = k2;

create index ix_contacts_customer_id on contacts (customer_id);
create index ix_contacts_supplier_id on contacts (supplier_id);

create index ix_addresses_customer_id on addresses (customer_id);
create index ix_addresses_supplier_id on addresses (supplier_id);

create index ix_parts_customer_id on parts (customer_id);

create index ix_part_revisions_part_id on part_revisions (part_id);

create index ix_part_operations_part_revision_id on part_operations (part_revision_id);

create index ix_rfqs_customer_id on rfqs (customer_id);

create index ix_rfq_lines_rfq_id on rfq_lines (rfq_id);
create index ix_rfq_lines_part_id on rfq_lines (part_id);

create index ix_quotes_customer_id on quotes (customer_id);
create index ix_quotes_rfq_id on quotes (rfq_id);

create index ix_quote_lines_quote_id on quote_lines (quote_id);
create index ix_quote_lines_part_revision_id on quote_lines (part_revision_id);

create index ix_customer_pos_customer_id on customer_pos (customer_id);
create index ix_customer_pos_quote_id on customer_pos (quote_id);

create index ix_sales_orders_customer_id on sales_orders (customer_id);
create index ix_sales_orders_customer_po_id on sales_orders (customer_po_id);

create index ix_sales_order_lines_sales_order_id on sales_order_lines (sales_order_id);
create index ix_sales_order_lines_part_revision_id on sales_order_lines (part_revision_id);

create index ix_work_orders_sales_order_line_id on work_orders (sales_order_line_id);
create index ix_work_orders_part_revision_id on work_orders (part_revision_id);

create index ix_work_order_operations_work_order_id on work_order_operations (work_order_id);
create index ix_work_order_operations_completed_by on work_order_operations (completed_by);

create index ix_purchase_orders_supplier_id on purchase_orders (supplier_id);

create index ix_purchase_order_lines_purchase_order_id on purchase_order_lines (purchase_order_id);
create index ix_purchase_order_lines_material_id on purchase_order_lines (material_id);
create index ix_purchase_order_lines_work_order_id on purchase_order_lines (work_order_id);

create index ix_lots_material_id on lots (material_id);
create index ix_lots_supplier_id on lots (supplier_id);
create index ix_lots_purchase_order_line_id on lots (purchase_order_line_id);

create index ix_inventory_transactions_lot_id on inventory_transactions (lot_id);
create index ix_inventory_transactions_location_id on inventory_transactions (location_id);
create index ix_inventory_transactions_work_order_id on inventory_transactions (work_order_id);
create index ix_inventory_transactions_user_id on inventory_transactions (user_id);

create index ix_inspections_work_order_id on inspections (work_order_id);
create index ix_inspections_work_order_operation_id on inspections (work_order_operation_id);
create index ix_inspections_lot_id on inspections (lot_id);
create index ix_inspections_inspected_by on inspections (inspected_by);

create index ix_ncrs_work_order_id on ncrs (work_order_id);
create index ix_ncrs_lot_id on ncrs (lot_id);
create index ix_ncrs_raised_by on ncrs (raised_by);

create index ix_shipments_customer_id on shipments (customer_id);
create index ix_shipments_sales_order_id on shipments (sales_order_id);

create index ix_shipment_lines_shipment_id on shipment_lines (shipment_id);
create index ix_shipment_lines_sales_order_line_id on shipment_lines (sales_order_line_id);
create index ix_shipment_lines_work_order_id on shipment_lines (work_order_id);

create index ix_invoices_customer_id on invoices (customer_id);
create index ix_invoices_sales_order_id on invoices (sales_order_id);

create index ix_invoice_lines_invoice_id on invoice_lines (invoice_id);
create index ix_invoice_lines_shipment_line_id on invoice_lines (shipment_line_id);

create index ix_documents_uploaded_by on documents (uploaded_by);

create index ix_audit_log_user_id on audit_log (user_id);

-- One released revision per part.
create unique index uq_part_revisions_part_id_released on part_revisions (part_id) where status = 'released';

-- Find the documents attached to a record.
create index ix_documents_record_type_record_id on documents (record_type, record_id);

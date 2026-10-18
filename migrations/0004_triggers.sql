-- 0004: triggers.

set search_path = k2;

-- updated_at triggers: every table except audit_log, which has no updated_at.
create trigger trg_users_set_updated_at before update on users for each row execute function set_updated_at();
create trigger trg_customers_set_updated_at before update on customers for each row execute function set_updated_at();
create trigger trg_suppliers_set_updated_at before update on suppliers for each row execute function set_updated_at();
create trigger trg_contacts_set_updated_at before update on contacts for each row execute function set_updated_at();
create trigger trg_addresses_set_updated_at before update on addresses for each row execute function set_updated_at();
create trigger trg_parts_set_updated_at before update on parts for each row execute function set_updated_at();
create trigger trg_part_revisions_set_updated_at before update on part_revisions for each row execute function set_updated_at();
create trigger trg_part_operations_set_updated_at before update on part_operations for each row execute function set_updated_at();
create trigger trg_rfqs_set_updated_at before update on rfqs for each row execute function set_updated_at();
create trigger trg_rfq_lines_set_updated_at before update on rfq_lines for each row execute function set_updated_at();
create trigger trg_quotes_set_updated_at before update on quotes for each row execute function set_updated_at();
create trigger trg_quote_lines_set_updated_at before update on quote_lines for each row execute function set_updated_at();
create trigger trg_customer_pos_set_updated_at before update on customer_pos for each row execute function set_updated_at();
create trigger trg_sales_orders_set_updated_at before update on sales_orders for each row execute function set_updated_at();
create trigger trg_sales_order_lines_set_updated_at before update on sales_order_lines for each row execute function set_updated_at();
create trigger trg_work_orders_set_updated_at before update on work_orders for each row execute function set_updated_at();
create trigger trg_work_order_operations_set_updated_at before update on work_order_operations for each row execute function set_updated_at();
create trigger trg_materials_set_updated_at before update on materials for each row execute function set_updated_at();
create trigger trg_locations_set_updated_at before update on locations for each row execute function set_updated_at();
create trigger trg_purchase_orders_set_updated_at before update on purchase_orders for each row execute function set_updated_at();
create trigger trg_purchase_order_lines_set_updated_at before update on purchase_order_lines for each row execute function set_updated_at();
create trigger trg_lots_set_updated_at before update on lots for each row execute function set_updated_at();
create trigger trg_inventory_transactions_set_updated_at before update on inventory_transactions for each row execute function set_updated_at();
create trigger trg_inspections_set_updated_at before update on inspections for each row execute function set_updated_at();
create trigger trg_ncrs_set_updated_at before update on ncrs for each row execute function set_updated_at();
create trigger trg_shipments_set_updated_at before update on shipments for each row execute function set_updated_at();
create trigger trg_shipment_lines_set_updated_at before update on shipment_lines for each row execute function set_updated_at();
create trigger trg_invoices_set_updated_at before update on invoices for each row execute function set_updated_at();
create trigger trg_invoice_lines_set_updated_at before update on invoice_lines for each row execute function set_updated_at();
create trigger trg_documents_set_updated_at before update on documents for each row execute function set_updated_at();

-- Append-only tables: UPDATE and DELETE are refused.
create trigger trg_inventory_transactions_append_only before update or delete on inventory_transactions for each row execute function refuse_change();
create trigger trg_audit_log_append_only before update or delete on audit_log for each row execute function refuse_change();

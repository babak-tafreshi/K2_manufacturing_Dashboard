-- Checks for the rules in the schema.
-- Each check runs in its own transaction and is rolled back, so the database stays empty.
-- A check that finds a broken rule raises an exception and stops the run.

set search_path = k2;

-- 1. A negative quote_lines.quantity is refused.
begin;
do $$
declare
    v_customer uuid;
    v_part     uuid;
    v_rev      uuid;
    v_quote    uuid;
begin
    insert into customers (code, name, status) values ('CHK', 'Check customer', 'active') returning id into v_customer;
    insert into parts (customer_id, part_number) values (v_customer, 'P-1') returning id into v_part;
    insert into part_revisions (part_id, revision, status) values (v_part, 'A', 'draft') returning id into v_rev;
    insert into quotes (quote_number, customer_id, status) values ('Q-CHK-0001', v_customer, 'draft') returning id into v_quote;
    begin
        insert into quote_lines (quote_id, line_no, part_revision_id, quantity, unit_price)
        values (v_quote, 1, v_rev, -1, 10);
        raise exception 'FAIL: negative quote_lines.quantity was accepted';
    exception when check_violation then
        raise notice 'pass: negative quote_lines.quantity is refused';
    end;
end $$;
rollback;

-- 2. A second released revision for the same part is refused.
begin;
do $$
declare
    v_customer uuid;
    v_part     uuid;
begin
    insert into customers (code, name, status) values ('CHK', 'Check customer', 'active') returning id into v_customer;
    insert into parts (customer_id, part_number) values (v_customer, 'P-1') returning id into v_part;
    insert into part_revisions (part_id, revision, status, released_at) values (v_part, 'A', 'released', now());
    begin
        insert into part_revisions (part_id, revision, status, released_at) values (v_part, 'B', 'released', now());
        raise exception 'FAIL: a second released revision was accepted';
    exception when unique_violation then
        raise notice 'pass: a second released revision for the same part is refused';
    end;
end $$;
rollback;

-- 3. UPDATE and DELETE on inventory_transactions and audit_log are refused.
begin;
do $$
declare
    v_user     uuid;
    v_material uuid;
    v_lot      uuid;
    v_location uuid;
begin
    insert into users (username, full_name) values ('check', 'Check user') returning id into v_user;
    insert into materials (code, description, unit) values ('MAT-CHK', 'Check material', 'kg') returning id into v_material;
    insert into lots (lot_number, material_id, status) values ('LOT-CHK', v_material, 'accepted') returning id into v_lot;
    insert into locations (code, name) values ('LOC-CHK', 'Check location') returning id into v_location;
    insert into inventory_transactions (lot_id, location_id, kind, quantity, user_id)
    values (v_lot, v_location, 'receive', 5, v_user);
    insert into audit_log (user_id, table_name, record_id, action, after)
    values (v_user, 'lots', v_lot, 'insert', '{}'::jsonb);

    begin
        update inventory_transactions set note = 'changed';
        raise exception 'FAIL: UPDATE on inventory_transactions was accepted';
    exception when raise_exception then
        if sqlerrm not like '%append-only%' then raise; end if;
        raise notice 'pass: UPDATE on inventory_transactions is refused';
    end;

    begin
        delete from inventory_transactions;
        raise exception 'FAIL: DELETE on inventory_transactions was accepted';
    exception when raise_exception then
        if sqlerrm not like '%append-only%' then raise; end if;
        raise notice 'pass: DELETE on inventory_transactions is refused';
    end;

    begin
        update audit_log set table_name = 'changed';
        raise exception 'FAIL: UPDATE on audit_log was accepted';
    exception when raise_exception then
        if sqlerrm not like '%append-only%' then raise; end if;
        raise notice 'pass: UPDATE on audit_log is refused';
    end;

    begin
        delete from audit_log;
        raise exception 'FAIL: DELETE on audit_log was accepted';
    exception when raise_exception then
        if sqlerrm not like '%append-only%' then raise; end if;
        raise notice 'pass: DELETE on audit_log is refused';
    end;
end $$;
rollback;

-- 4. A contact with both customer_id and supplier_id, or neither, is refused.
begin;
do $$
declare
    v_customer uuid;
    v_supplier uuid;
begin
    insert into customers (code, name, status) values ('CHK', 'Check customer', 'active') returning id into v_customer;
    insert into suppliers (code, name, status) values ('CHK', 'Check supplier', 'approved') returning id into v_supplier;

    begin
        insert into contacts (customer_id, supplier_id, name) values (v_customer, v_supplier, 'Both');
        raise exception 'FAIL: a contact with both customer_id and supplier_id was accepted';
    exception when check_violation then
        raise notice 'pass: a contact with both customer_id and supplier_id is refused';
    end;

    begin
        insert into contacts (name) values ('Neither');
        raise exception 'FAIL: a contact with neither customer_id nor supplier_id was accepted';
    exception when check_violation then
        raise notice 'pass: a contact with neither customer_id nor supplier_id is refused';
    end;
end $$;
rollback;

-- 5. Deleting a customer that has parts is refused.
begin;
do $$
declare
    v_customer uuid;
begin
    insert into customers (code, name, status) values ('CHK', 'Check customer', 'active') returning id into v_customer;
    insert into parts (customer_id, part_number) values (v_customer, 'P-1');
    begin
        delete from customers where id = v_customer;
        raise exception 'FAIL: a customer with parts was deleted';
    exception when foreign_key_violation or restrict_violation then
        raise notice 'pass: deleting a customer that has parts is refused';
    end;
end $$;
rollback;

-- 6. updated_at changes on an update.
-- now() is fixed for the whole transaction, so the row starts with an old updated_at.
begin;
do $$
declare
    v_customer uuid;
    v_updated  timestamptz;
begin
    insert into customers (code, name, status, updated_at)
    values ('CHK', 'Check customer', 'active', '2000-01-01 00:00:00+00')
    returning id into v_customer;
    update customers set name = 'Check customer renamed' where id = v_customer;
    select updated_at into v_updated from customers where id = v_customer;
    if v_updated = '2000-01-01 00:00:00+00' then
        raise exception 'FAIL: updated_at did not change on update';
    end if;
    raise notice 'pass: updated_at changes on an update';
end $$;
rollback;

-- The database must still be empty.
do $$
declare
    v_rows bigint;
begin
    select (select count(*) from customers) + (select count(*) from users) + (select count(*) from audit_log)
    into v_rows;
    if v_rows <> 0 then
        raise exception 'FAIL: checks left % rows behind', v_rows;
    end if;
    raise notice 'pass: database is still empty';
end $$;

-- 0001: schema and helper functions for K2 Aero Services Corp.
-- gen_random_uuid() is built into PostgreSQL 13 and later, so pgcrypto is not needed.

create schema k2;

-- Keeps updated_at current on every UPDATE.
create function k2.set_updated_at() returns trigger
language plpgsql as $$
begin
    new.updated_at := now();
    return new;
end;
$$;

-- Refuses UPDATE and DELETE on append-only tables.
create function k2.refuse_change() returns trigger
language plpgsql as $$
begin
    raise exception '% is append-only: % is not allowed', tg_table_name, tg_op;
end;
$$;

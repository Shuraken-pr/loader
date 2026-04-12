CREATE OR REPLACE FUNCTION schemaname.trg_tablename_fill_log()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO schemaname.tablename_log (orig_id, columnsname, operation, date_write)
    VALUES (NEW.id, newcolumns, 'I', now());
    RETURN NEW;

  ELSIF TG_OP = 'UPDATE' THEN
    INSERT INTO schemaname.tablename_log (orig_id, columnsname, operation, date_write)
    VALUES (NEW.id, newcolumns, 'U', now());
    RETURN NEW;

  ELSIF TG_OP = 'DELETE' THEN
    INSERT INTO schemaname.tablename_log (orig_id, columnsname, operation, date_write)
    VALUES (OLD.id, oldcolumns, 'D', now());
    RETURN OLD;
  END IF;

  RETURN NULL; -- на всякий случай
END;
$$;

CREATE TRIGGER trg_tablename_fill_log
AFTER INSERT OR UPDATE OR DELETE ON schemaname.tablename
FOR EACH ROW
EXECUTE FUNCTION schemaname.trg_tablename_fill_log();
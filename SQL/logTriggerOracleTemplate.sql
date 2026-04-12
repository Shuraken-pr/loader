CREATE OR REPLACE TRIGGER trg_tablename_fill_log
AFTER INSERT OR UPDATE OR DELETE ON tablename
FOR EACH ROW
BEGIN
  IF INSERTING THEN
    INSERT INTO tablename_log (orig_id, columnsname, operation, date_write)
    VALUES (:NEW.id, newcolumns, 'I', SYSTIMESTAMP);

  ELSIF UPDATING THEN
    INSERT INTO tablename_log (orig_id, columnsname, operation, date_write)
    VALUES (:NEW.id, newcolumns, 'U', SYSTIMESTAMP);

  ELSIF DELETING THEN
    INSERT INTO tablename_log (orig_id, columnsname, operation, date_write)
    VALUES (:OLD.id, oldcolumns, 'D', SYSTIMESTAMP);
  END IF;
END trg_tablename_fill_log;
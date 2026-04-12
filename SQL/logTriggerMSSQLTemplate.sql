CREATE TRIGGER schemaname.trg_tablename_fill_log
ON schemaname.tablename
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    -- INSERT: строки, которые есть в inserted, но не в deleted
    INSERT INTO schemaname.tablename_log (orig_id, columnsname, operation, date_write)
    SELECT i.id, newcolumns, 'I', GetDate()
    FROM inserted i
    LEFT JOIN deleted d ON d.id = i.id
    WHERE d.id IS NULL;

    -- DELETE: строки, которые есть в deleted, но не в inserted
    INSERT INTO schemaname.tablename_log (orig_id, columnsname, operation, date_write)
    SELECT d.id, oldcolumns, 'D', GetDate()
    FROM deleted d
    LEFT JOIN inserted i ON i.id = d.id
    WHERE i.id IS NULL;

    -- UPDATE: строки, которые присутствуют и в inserted, и в deleted
    INSERT INTO schemaname.tablename_log (orig_id, columnsname, operation, date_write)
    SELECT i.id, newcolumns, 'U', GetDate()
    FROM inserted i
    INNER JOIN deleted d ON d.id = i.id;
END;
GO
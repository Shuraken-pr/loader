CREATE TABLE schemaname.tablename (
    id          NUMBER GENERATED ALWAYS AS IDENTITY NOT NULL,
	orig_id NUMBER,
    columnsname,
	operation varchar2(1),
	date_write datetime,
    CONSTRAINT PK_tablename PRIMARY KEY (id)
);
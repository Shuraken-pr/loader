CREATE TABLE if not exists schemaname.tablename (
	id int4 GENERATED ALWAYS AS IDENTITY( INCREMENT BY 1 MINVALUE 1 MAXVALUE 2147483647 START 1 CACHE 1 NO CYCLE) NOT NULL,
	orig_id int4,
	columnsname,
	operation varchar,
	date_write timestamp,
	CONSTRAINT tablename_pk PRIMARY KEY (id)
);

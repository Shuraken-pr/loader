create TABLE [schemaname].[tablename](
[id] [int] IDENTITY(1,1) NOT NULL,
[orig_id] [int],
columnsname,
operation varchar(1),
date_write datetime
CONSTRAINT [PK_tablename] PRIMARY KEY CLUSTERED
(
[id] ASC
)
)

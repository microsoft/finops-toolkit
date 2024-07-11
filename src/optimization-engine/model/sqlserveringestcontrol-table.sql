SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sysobjects WHERE id = object_id(N'[dbo].[SqlServerIngestControl]')
AND OBJECTPROPERTY(id, N'IsUserTable') = 1)
BEGIN
	CREATE TABLE [dbo].[SqlServerIngestControl](
		[StorageContainerName] [varchar](50) NOT NULL,
		[LastProcessedDateTime] [datetime] NULL,
		[LastProcessedLine] [int] NULL,
		[SqlTableName] [varchar](50) NOT NULL
	)
	ALTER TABLE [dbo].[SqlServerIngestControl] ADD PRIMARY KEY CLUSTERED 
	(
		[StorageContainerName] ASC
	)WITH (STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF) ON [PRIMARY]
END
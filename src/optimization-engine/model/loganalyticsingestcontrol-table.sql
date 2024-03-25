SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sysobjects WHERE id = object_id(N'[dbo].[LogAnalyticsIngestControl]')
AND OBJECTPROPERTY(id, N'IsUserTable') = 1)
	BEGIN
		CREATE TABLE [dbo].[LogAnalyticsIngestControl](
			[StorageContainerName] [varchar](50) NOT NULL,
			[LastProcessedDateTime] [datetime] NULL,
			[LastProcessedLine] [int] NULL,
			[LogAnalyticsSuffix] [varchar](50) NOT NULL,
			[CollectedType] [varchar](50) NULL
		)

		ALTER TABLE [dbo].[LogAnalyticsIngestControl] ADD PRIMARY KEY CLUSTERED 
		(
			[StorageContainerName] ASC
		)WITH (STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF) ON [PRIMARY]
	END
ELSE
	BEGIN
		IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[LogAnalyticsIngestControl]') AND name = 'CollectedType'
)		BEGIN
			ALTER TABLE [dbo].[LogAnalyticsIngestControl] ADD [CollectedType] VARCHAR (50) NULL
		END
	END
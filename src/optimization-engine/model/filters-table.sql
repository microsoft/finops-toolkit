SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sysobjects WHERE id = object_id(N'[dbo].[Filters]') AND OBJECTPROPERTY(id, N'IsUserTable') = 1)
	BEGIN
		CREATE TABLE [dbo].[Filters](
			[FilterId] [uniqueidentifier] NOT NULL DEFAULT NEWID(),
			[RecommendationSubTypeId] [uniqueidentifier] NOT NULL,
			[FilterType] [varchar](20) NOT NULL,
			[InstanceId] [varchar](1000) NULL,
			[FilterStartDate] [datetime] NOT NULL,
			[FilterEndDate] [datetime] NULL,
			[Author] [varchar](50) NULL,
			[Notes] [nvarchar](max) NULL,
			[IsEnabled] [bit] NOT NULL
		)

		ALTER TABLE [dbo].[Filters] ADD PRIMARY KEY CLUSTERED 
		(
			[FilterId] ASC
		)WITH (STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF) ON [PRIMARY]
	END

SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sysobjects WHERE id = object_id(N'[dbo].[Recommendations]') AND OBJECTPROPERTY(id, N'IsUserTable') = 1)
	BEGIN
		CREATE TABLE [dbo].[Recommendations](
			[RecommendationId] [uniqueidentifier] NOT NULL DEFAULT NEWID(),
			[GeneratedDate] [datetime] NOT NULL,
			[Cloud] [varchar](20) NOT NULL,
			[Category] [varchar](50) NOT NULL,
			[ImpactedArea] [varchar](300) NOT NULL,
			[Impact] [varchar](20) NOT NULL,
			[RecommendationType] [varchar](50) NOT NULL,
			[RecommendationSubType] [varchar](50) NOT NULL,
			[RecommendationSubTypeId] [uniqueidentifier] NOT NULL,
			[RecommendationDescription] [nvarchar](1000) NULL,
			[RecommendationAction] [nvarchar](1000) NULL,
			[InstanceId] [varchar](1000) NULL,
			[InstanceName] [varchar](500) NULL,
			[AdditionalInfo] [nvarchar](max) NULL,
			[ResourceGroup] [varchar](200) NULL,
			[SubscriptionGuid] [varchar](50) NULL,
			[SubscriptionName] [varchar](250) NULL,
			[TenantGuid] [varchar](50) NULL,
			[FitScore] [real] NOT NULL,
			[Tags] [nvarchar](max) NULL,
			[DetailsUrl] [nvarchar](max) NULL
		)

		ALTER TABLE [dbo].[Recommendations] ADD PRIMARY KEY CLUSTERED 
		(
			[RecommendationId] ASC
		)WITH (STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF) ON [PRIMARY]

		CREATE INDEX IXC_Recommendations_SubTypeId ON [dbo].[Recommendations](RecommendationSubTypeId)

		CREATE INDEX IXC_Recommendations_GeneratedDate ON [dbo].[Recommendations](GeneratedDate)
	END
ELSE
	BEGIN
		ALTER TABLE [dbo].[Recommendations] ALTER COLUMN [RecommendationAction] VARCHAR (1000) NULL
		ALTER TABLE [dbo].[Recommendations] ALTER COLUMN [InstanceId] VARCHAR (1000) NULL
		ALTER TABLE [dbo].[Recommendations] ALTER COLUMN [InstanceName] VARCHAR (500) NULL
		ALTER TABLE [dbo].[Recommendations] ALTER COLUMN [ResourceGroup] VARCHAR (200) NULL
		ALTER TABLE [dbo].[Recommendations] ALTER COLUMN [ImpactedArea] VARCHAR (300) NULL
		IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[Recommendations]') AND name = 'FitScore')
		BEGIN
			EXEC sp_rename '[dbo].[Recommendations].ConfidenceScore', 'FitScore', 'COLUMN'
		END
		IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[Recommendations]') AND name = 'SubscriptionName')
		BEGIN
			ALTER TABLE [dbo].[Recommendations] ADD [SubscriptionName] VARCHAR (250) NULL
		END
		IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[Recommendations]') AND name = 'TenantGuid')
		BEGIN
			ALTER TABLE [dbo].[Recommendations] ADD [TenantGuid] VARCHAR (50) NULL
		END
		IF NOT EXISTS (SELECT * from sysindexes WHERE id=object_id('Recommendations') and name='IXC_Recommendations_SubTypeId')
		BEGIN
			CREATE INDEX IXC_Recommendations_SubTypeId ON [dbo].[Recommendations](RecommendationSubTypeId)
		END
		IF NOT EXISTS (SELECT * from sysindexes WHERE id=object_id('Recommendations') and name='IXC_Recommendations_GeneratedDate')
		BEGIN
			CREATE INDEX IXC_Recommendations_GeneratedDate ON [dbo].[Recommendations](GeneratedDate)
		END
	END
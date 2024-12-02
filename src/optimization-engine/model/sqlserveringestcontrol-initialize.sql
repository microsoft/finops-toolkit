IF NOT EXISTS (SELECT * FROM [dbo].[SqlServerIngestControl] WHERE StorageContainerName = 'recommendationsexports')
BEGIN
    INSERT INTO [dbo].[SqlServerIngestControl] 
    VALUES 
        ('recommendationsexports', '1901-01-01T00:00:00Z', -1, 'Recommendations')
END
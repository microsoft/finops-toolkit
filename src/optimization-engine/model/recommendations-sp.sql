IF OBJECT_ID ( N'[dbo].[GetRecommendations]', 'P' ) IS NOT NULL
BEGIN
    DROP PROCEDURE dbo.GetRecommendations
END
EXEC('CREATE PROCEDURE dbo.GetRecommendations   
    AS BEGIN
        SET NOCOUNT ON;  
        SELECT * FROM [dbo].[Recommendations] R
        WHERE GeneratedDate > GETDATE()-365 AND NOT EXISTS (
            SELECT * FROM [dbo].[Filters]
            WHERE FilterType IN (''Snooze'', ''Dismiss'') AND 
                  IsEnabled = 1 AND 
                  R.GeneratedDate > FilterStartDate AND
                  (FilterEndDate IS NULL OR FilterEndDate > GETDATE()) AND 
                  RecommendationSubTypeId = R.RecommendationSubTypeId AND 
                  (InstanceId IS NULL OR R.InstanceId LIKE ''%'' + InstanceId + ''%'')
        )  
    END
')

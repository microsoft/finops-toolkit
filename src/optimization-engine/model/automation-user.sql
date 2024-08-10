IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = '<automation-account-name>')
BEGIN
    CREATE USER [<automation-account-name>] FROM EXTERNAL PROVIDER
END

IF IS_ROLEMEMBER ('db_datareader','<automation-account-name>') = 0
BEGIN
    ALTER ROLE [db_datareader] ADD MEMBER [<automation-account-name>]
END

IF IS_ROLEMEMBER ('db_datawriter','<automation-account-name>') = 0
BEGIN
    ALTER ROLE [db_datawriter] ADD MEMBER [<automation-account-name>]
END
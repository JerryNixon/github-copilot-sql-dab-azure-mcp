IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Todos' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    CREATE TABLE [dbo].[Todos]
    (
        [TodoId] INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        [Title] NVARCHAR(200) NOT NULL,
        [DueDate] DATE NOT NULL,
        [Owner] NVARCHAR(100) NOT NULL,
        [Completed] BIT NOT NULL DEFAULT 0
    )
END

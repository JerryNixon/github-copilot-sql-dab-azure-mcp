CREATE TABLE [dbo].[Shops]
(
    [ShopId] INT NOT NULL IDENTITY(1,1),
    [Name] NVARCHAR(100) NOT NULL,
    [Location] NVARCHAR(200) NOT NULL,
    CONSTRAINT [PK_Shops] PRIMARY KEY ([ShopId])
);

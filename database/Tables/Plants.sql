CREATE TABLE [dbo].[Plants]
(
    [PlantId] INT NOT NULL IDENTITY(1,1),
    [Name] NVARCHAR(100) NOT NULL,
    [CategoryId] INT NOT NULL,
    [Quantity] INT NOT NULL,
    [Price] DECIMAL(10,2) NOT NULL,
    [ShopId] INT NOT NULL,
    CONSTRAINT [PK_Plants] PRIMARY KEY ([PlantId]),
    CONSTRAINT [FK_Plants_Categories] FOREIGN KEY ([CategoryId]) REFERENCES [dbo].[Categories]([CategoryId]),
    CONSTRAINT [FK_Plants_Shops] FOREIGN KEY ([ShopId]) REFERENCES [dbo].[Shops]([ShopId])
);

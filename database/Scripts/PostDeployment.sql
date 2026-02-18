-- Seed data for Flower Shop (only if tables are empty)

-- Shops
IF NOT EXISTS (SELECT 1 FROM [dbo].[Shops])
BEGIN
    SET IDENTITY_INSERT [dbo].[Shops] ON;
    INSERT INTO [dbo].[Shops] ([ShopId], [Name], [Location]) VALUES
    (1, N'Bloom & Petal Downtown', N'123 Main Street'),
    (2, N'Bloom & Petal Uptown', N'456 Oak Avenue');
    SET IDENTITY_INSERT [dbo].[Shops] OFF;
END

-- Categories
IF NOT EXISTS (SELECT 1 FROM [dbo].[Categories])
BEGIN
    SET IDENTITY_INSERT [dbo].[Categories] ON;
    INSERT INTO [dbo].[Categories] ([CategoryId], [Name]) VALUES
    (1, N'Roses'),
    (2, N'Succulents'),
    (3, N'Orchids'),
    (4, N'Ferns');
    SET IDENTITY_INSERT [dbo].[Categories] OFF;
END

-- Plants
IF NOT EXISTS (SELECT 1 FROM [dbo].[Plants])
BEGIN
    SET IDENTITY_INSERT [dbo].[Plants] ON;
    INSERT INTO [dbo].[Plants] ([PlantId], [Name], [CategoryId], [Quantity], [Price], [ShopId]) VALUES
    (1, N'Red Rose', 1, 50, 12.99, 1),
    (2, N'White Rose', 1, 30, 14.99, 1),
    (3, N'Echeveria', 2, 25, 8.50, 1),
    (4, N'Jade Plant', 2, 15, 10.00, 2),
    (5, N'Phalaenopsis Orchid', 3, 10, 24.99, 2),
    (6, N'Boston Fern', 4, 20, 15.00, 1),
    (7, N'Pink Rose', 1, 40, 13.50, 2),
    (8, N'Aloe Vera', 2, 35, 7.99, 2);
    SET IDENTITY_INSERT [dbo].[Plants] OFF;
END

/*
Post-Deployment Script
This script runs after database schema deployment and seeds initial data
*/

-- Clear existing data (for idempotent deployments)
DELETE FROM [dbo].[Todos];

-- Reset identity seed
DBCC CHECKIDENT ('[dbo].[Todos]', RESEED, 0);

-- Insert sample data
INSERT INTO [dbo].[Todos] ([Title], [DueDate], [Owner], [Completed])
VALUES
    ('Review pull requests', '2026-02-10', 'sarah.chen@example.com', 0),
    ('Update documentation', '2026-02-09', 'mike.johnson@example.com', 1),
    ('Deploy to production', '2026-02-12', 'sarah.chen@example.com', 0),
    ('Fix login bug', '2026-02-08', 'alex.kumar@example.com', 1),
    ('Design new feature mockups', '2026-02-15', 'sarah.chen@example.com', 0),
    ('Code review session', '2026-02-11', 'todo-testuser@jerrynixoncorp.onmicrosoft.com', 0),
    ('Update dependencies', '2026-02-13', 'todo-testuser@jerrynixoncorp.onmicrosoft.com', 0);

PRINT 'Sample data seeded successfully';

-- 🔹 Drop the table if it already exists
IF OBJECT_ID('dbo.StatsDump', 'U') IS NOT NULL
    DROP TABLE dbo.StatsDump;
GO

-- 🔹 Create the table
CREATE TABLE dbo.StatsDump (
    [StatID] NVARCHAR(100),
    [OwnerType] NVARCHAR(100),
    [ItemName] NVARCHAR(100),
    [StatName] NVARCHAR(100),
    [OwningComputer] NVARCHAR(100),
    [CompID] INT,
    [StatType] INT,
    [ItemAlias] NVARCHAR(100),
    [Unit] INT,
    [UnitStr] NVARCHAR(100),
    [Name] NVARCHAR(100)
);
GO
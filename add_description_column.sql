-- Add Description column to existing Properties table
-- Run this if your Properties table already exists without the Description column

-- Check if Description column exists
IF NOT EXISTS (
    SELECT * FROM INFORMATION_SCHEMA.COLUMNS 
    WHERE TABLE_NAME = 'Properties' AND COLUMN_NAME = 'Description'
)
BEGIN
    PRINT 'Adding Description column to Properties table...'
    ALTER TABLE Properties 
    ADD Description NVARCHAR(MAX) NULL;
    PRINT 'Description column added successfully!'
END
ELSE
BEGIN
    PRINT 'Description column already exists in Properties table'
END

-- Verify the column was added
SELECT 'Properties Table Structure After Migration:' as Info;
SELECT 
    COLUMN_NAME,
    DATA_TYPE,
    CHARACTER_MAXIMUM_LENGTH,
    IS_NULLABLE,
    COLUMN_DEFAULT
FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_NAME = 'Properties'
ORDER BY ORDINAL_POSITION;
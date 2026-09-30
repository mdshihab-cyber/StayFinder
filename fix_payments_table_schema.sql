-- ============================================
-- Fix Payments Table Schema for Host Earnings
-- ============================================

PRINT '?? Fixing Payments table schema for host earnings functionality...';

-- Check if RemainingAmount column exists, if not add it
IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Payments' AND COLUMN_NAME = 'RemainingAmount')
BEGIN
    ALTER TABLE Payments ADD RemainingAmount AS (TotalAmount - AmountPaid) PERSISTED;
    PRINT '? Added computed RemainingAmount column';
END
ELSE
BEGIN
    PRINT '? RemainingAmount column already exists';
END

-- Check if PaymentDate has default value
IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Payments' AND COLUMN_NAME = 'PaymentDate' AND COLUMN_DEFAULT IS NOT NULL)
BEGIN
    ALTER TABLE Payments ADD CONSTRAINT DF_Payments_PaymentDate DEFAULT GETUTCDATE() FOR PaymentDate;
    PRINT '? Added default value for PaymentDate column';
END
ELSE
BEGIN
    PRINT '? PaymentDate default constraint already exists';
END

-- Ensure PaymentDate is not null for existing records
UPDATE Payments 
SET PaymentDate = GETUTCDATE() 
WHERE PaymentDate IS NULL;

PRINT '? Updated null PaymentDate values';

-- Add indexes for better performance on earnings queries
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Payments_BookingId_Status')
BEGIN
    CREATE INDEX IX_Payments_BookingId_Status ON Payments(BookingId, Status);
    PRINT '? Added index on BookingId and Status';
END

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Payments_PaymentDate')
BEGIN
    CREATE INDEX IX_Payments_PaymentDate ON Payments(PaymentDate);
    PRINT '? Added index on PaymentDate';
END

-- Verify table structure
PRINT '';
PRINT '?? CURRENT PAYMENTS TABLE STRUCTURE:';
PRINT '====================================';
SELECT 
    COLUMN_NAME,
    DATA_TYPE,
    IS_NULLABLE,
    COLUMN_DEFAULT,
    CASE WHEN COLUMNPROPERTY(OBJECT_ID('Payments'), COLUMN_NAME, 'IsComputed') = 1 THEN 'YES' ELSE 'NO' END AS IS_COMPUTED
FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_NAME = 'Payments'
ORDER BY ORDINAL_POSITION;

-- Show indexes
PRINT '';
PRINT '?? INDEXES ON PAYMENTS TABLE:';
PRINT '=============================';
SELECT 
    i.name AS IndexName,
    STRING_AGG(c.name, ', ') AS Columns
FROM sys.indexes i
JOIN sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
WHERE i.object_id = OBJECT_ID('Payments')
GROUP BY i.name, i.index_id
ORDER BY i.name;

PRINT '';
PRINT '? Payments table schema is ready for host earnings functionality!';
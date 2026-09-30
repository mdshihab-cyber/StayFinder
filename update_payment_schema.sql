-- Payment System Database Schema Update Script
-- This script updates the Payments table to support the new payment workflow

-- 1. First, check if the new columns already exist and backup existing data
IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Payments' AND COLUMN_NAME = 'TotalAmount')
BEGIN
    PRINT 'Adding new columns to Payments table...'
    
    -- Add new columns
    ALTER TABLE Payments ADD 
        TotalAmount DECIMAL(10,2) NOT NULL DEFAULT 0,
        PaymentType NVARCHAR(50) NOT NULL DEFAULT 'Initial Booking';
    
    -- Drop the old Amount column and rename AmountPaid if needed
    IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Payments' AND COLUMN_NAME = 'Amount')
    BEGIN
        -- Create AmountPaid column and copy data from Amount
        ALTER TABLE Payments ADD AmountPaid DECIMAL(10,2) NOT NULL DEFAULT 0;
        
        -- Copy existing amount data
        UPDATE Payments SET AmountPaid = Amount;
        
        -- Set TotalAmount based on existing data (assume these are initial payments of 10%)
        UPDATE Payments SET TotalAmount = AmountPaid * 10 WHERE PaymentType = 'Initial Booking';
        
        -- Drop the old Amount column
        ALTER TABLE Payments DROP COLUMN Amount;
    END
    ELSE IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Payments' AND COLUMN_NAME = 'AmountPaid')
    BEGIN
        -- Add AmountPaid column if it doesn't exist
        ALTER TABLE Payments ADD AmountPaid DECIMAL(10,2) NOT NULL DEFAULT 0;
    END
    
    -- Add computed column for RemainingAmount
    IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Payments' AND COLUMN_NAME = 'RemainingAmount')
    BEGIN
        ALTER TABLE Payments ADD RemainingAmount AS (TotalAmount - AmountPaid) PERSISTED;
    END
    
    PRINT 'Payments table schema updated successfully!'
END
ELSE
BEGIN
    PRINT 'Payments table already has the new schema.'
END

-- 2. Update existing payment records to have proper PaymentType
UPDATE Payments 
SET PaymentType = 'Initial Booking' 
WHERE PaymentType IS NULL OR PaymentType = '';

-- 3. Create some test data to verify the new payment workflow
PRINT 'Creating test data for payment workflow verification...'

-- Test Customer
IF NOT EXISTS (SELECT 1 FROM Customers WHERE Email = 'paymenttest@example.com')
BEGIN
    INSERT INTO Customers (FullName, Email, Phone, Password, Role, Rating)
    VALUES ('Payment Test User', 'paymenttest@example.com', '+1234567890', 'hashedpassword', 'Customer', 4.5);
END

-- Test Property
DECLARE @TestPropertyId INT
IF NOT EXISTS (SELECT 1 FROM Properties WHERE Name = 'Payment Test Property')
BEGIN
    INSERT INTO Properties (Name, Type, Location, PricePerDay, HostName, ImageUrl, Status)
    VALUES ('Payment Test Property', 'Apartment', 'Test City', 100.00, 'Test Host', 'test.jpg', 'active');
    SET @TestPropertyId = SCOPE_IDENTITY()
END
ELSE
BEGIN
    SELECT @TestPropertyId = Id FROM Properties WHERE Name = 'Payment Test Property';
END

-- Test Booking
DECLARE @TestCustomerId INT = (SELECT Id FROM Customers WHERE Email = 'paymenttest@example.com');
DECLARE @TestBookingId INT

IF NOT EXISTS (SELECT 1 FROM Bookings WHERE CustomerId = @TestCustomerId AND PropertyId = @TestPropertyId)
BEGIN
    INSERT INTO Bookings (PropertyId, CustomerId, BookingFrom, BookingTo, NumberOfGuests, TotalPrice, Status, PaymentStatus, CreatedAt)
    VALUES (@TestPropertyId, @TestCustomerId, DATEADD(day, 7, GETDATE()), DATEADD(day, 10, GETDATE()), 2, 300.00, 'confirmed', 'pending', GETDATE());
    SET @TestBookingId = SCOPE_IDENTITY()
END
ELSE
BEGIN
    SELECT @TestBookingId = Id FROM Bookings WHERE CustomerId = @TestCustomerId AND PropertyId = @TestPropertyId;
END

PRINT 'Test data created successfully!'

-- 4. Verify the schema and show sample data
PRINT 'Current Payments table schema:'
SELECT 
    COLUMN_NAME,
    DATA_TYPE,
    IS_NULLABLE,
    COLUMN_DEFAULT,
    COLUMNPROPERTY(OBJECT_ID('Payments'), COLUMN_NAME, 'IsComputed') as IsComputed
FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_NAME = 'Payments'
ORDER BY ORDINAL_POSITION;

-- Show sample payment data
PRINT 'Sample payment records:'
SELECT TOP 5 
    Id, BookingId, CustomerId, TotalAmount, AmountPaid, RemainingAmount,
    PaymentMethod, PaymentType, PaymentDate, Status
FROM Payments
ORDER BY PaymentDate DESC;

PRINT 'Database schema update completed successfully!'
PRINT 'You can now test the payment workflow with the following endpoints:'
PRINT '- POST /api/payments/confirm (for initial 10% payments)'
PRINT '- POST /api/payments/remaining (for remaining balance payments)'
PRINT '- GET /api/payments/history/{customerId} (for payment history)'
PRINT '- GET /api/payments/booking/{bookingId} (for booking-specific payments)'
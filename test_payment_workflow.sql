-- Test Payment Functionality
-- This script tests the complete payment workflow

-- First, let's verify our tables exist and have the correct structure
SELECT 'Properties Table' AS TableName;
SELECT TOP 1 * FROM Properties;

SELECT 'Bookings Table' AS TableName;
SELECT TOP 1 * FROM Bookings;

SELECT 'Payments Table' AS TableName;
SELECT TOP 1 * FROM Payments;

-- Create test data if needed (run only if tables are empty)

-- Test User (if not exists)
IF NOT EXISTS (SELECT 1 FROM Users WHERE Email = 'test.customer@example.com')
BEGIN
    INSERT INTO Users (FullName, Email, Phone, Role, Password, CreatedAt)
    VALUES ('Test Customer', 'test.customer@example.com', '01712345678', 'Customer', 'password123', GETDATE());
    
    DECLARE @NewUserId INT = SCOPE_IDENTITY();
    
    -- Create corresponding customer record
    INSERT INTO Customers (Id, Rating, SavedProperties)
    VALUES (@NewUserId, 0.0, '[]');
END

-- Test Host (if not exists)
IF NOT EXISTS (SELECT 1 FROM Users WHERE Email = 'test.host@example.com')
BEGIN
    INSERT INTO Users (FullName, Email, Phone, Role, Password, CreatedAt)
    VALUES ('Test Host', 'test.host@example.com', '01787654321', 'Host', 'password123', GETDATE());
END

-- Test Property (if not exists)
DECLARE @HostId INT = (SELECT TOP 1 Id FROM Users WHERE Role = 'Host');
IF @HostId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM Properties WHERE Name = 'Test Property for Payment')
BEGIN
    INSERT INTO Properties (HostId, Name, Type, PricePerDay, Location, Status, BookingStatus, Description, CreatedAt)
    VALUES (@HostId, 'Test Property for Payment', 'Apartment', 100.00, 'Dhaka, Bangladesh', 'active', 'not booked', 'Test property for payment workflow', GETDATE());
END

-- Test Booking (if not exists)
DECLARE @CustomerId INT = (SELECT TOP 1 Id FROM Users WHERE Email = 'test.customer@example.com');
DECLARE @PropertyId INT = (SELECT TOP 1 Id FROM Properties WHERE Name = 'Test Property for Payment');

IF @CustomerId IS NOT NULL AND @PropertyId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM Bookings WHERE CustomerId = @CustomerId AND PropertyId = @PropertyId)
BEGIN
    INSERT INTO Bookings (PropertyId, CustomerId, BookingFrom, BookingTo, NumberOfGuests, TotalPrice, Status, PaymentStatus, CreatedAt)
    VALUES (@PropertyId, @CustomerId, DATEADD(day, 1, GETDATE()), DATEADD(day, 4, GETDATE()), 2, 300.00, 'pending', 'unpaid', GETDATE());
END

-- Display test data
SELECT 'Test Data Created Successfully' AS Status;

SELECT 'Customer Data' AS DataType;
SELECT u.Id, u.FullName, u.Email, c.Rating FROM Users u 
JOIN Customers c ON u.Id = c.Id 
WHERE u.Email = 'test.customer@example.com';

SELECT 'Property Data' AS DataType;
SELECT Id, Name, Type, PricePerDay, Location, Status, BookingStatus FROM Properties WHERE Name = 'Test Property for Payment';

SELECT 'Booking Data' AS DataType;
SELECT Id, PropertyId, CustomerId, BookingFrom, BookingTo, TotalPrice, Status, PaymentStatus FROM Bookings 
WHERE CustomerId = (SELECT Id FROM Users WHERE Email = 'test.customer@example.com')
AND PropertyId = (SELECT Id FROM Properties WHERE Name = 'Test Property for Payment');

-- Test the payment confirmation process manually
-- This simulates what the API would do

DECLARE @TestBookingId INT = (SELECT TOP 1 Id FROM Bookings WHERE Status = 'pending' AND PaymentStatus = 'unpaid');
DECLARE @TestCustomerId INT = (SELECT CustomerId FROM Bookings WHERE Id = @TestBookingId);
DECLARE @TestPropertyId INT = (SELECT PropertyId FROM Bookings WHERE Id = @TestBookingId);
DECLARE @TestAmount DECIMAL(10,2) = 30.00; -- 10% advance of 300.00

IF @TestBookingId IS NOT NULL
BEGIN
    PRINT 'Testing payment confirmation for Booking ID: ' + CAST(@TestBookingId AS VARCHAR(10));
    
    BEGIN TRANSACTION;
    
    BEGIN TRY
        -- Insert payment
        INSERT INTO Payments (BookingId, CustomerId, Amount, PaymentMethod, Status)
        VALUES (@TestBookingId, @TestCustomerId, @TestAmount, 'bKash', 'paid');
        
        DECLARE @PaymentId INT = SCOPE_IDENTITY();
        
        -- Update booking
        UPDATE Bookings 
        SET PaymentStatus = 'paid', Status = 'confirmed', UpdatedAt = GETUTCDATE()
        WHERE Id = @TestBookingId;
        
        -- Update property
        UPDATE Properties 
        SET BookingStatus = 'booked', 
            BookingFrom = (SELECT BookingFrom FROM Bookings WHERE Id = @TestBookingId),
            BookingTo = (SELECT BookingTo FROM Bookings WHERE Id = @TestBookingId),
            UpdatedAt = GETUTCDATE()
        WHERE Id = @TestPropertyId;
        
        COMMIT;
        
        PRINT 'Payment confirmation successful! Payment ID: ' + CAST(@PaymentId AS VARCHAR(10));
        
        -- Display results
        SELECT 'Updated Booking' AS ResultType;
        SELECT Id, Status, PaymentStatus, UpdatedAt FROM Bookings WHERE Id = @TestBookingId;
        
        SELECT 'Created Payment' AS ResultType;
        SELECT * FROM Payments WHERE Id = @PaymentId;
        
        SELECT 'Updated Property' AS ResultType;
        SELECT Id, BookingStatus, BookingFrom, BookingTo, UpdatedAt FROM Properties WHERE Id = @TestPropertyId;
        
    END TRY
    BEGIN CATCH
        ROLLBACK;
        PRINT 'Payment confirmation failed: ' + ERROR_MESSAGE();
    END CATCH
END
ELSE
BEGIN
    PRINT 'No unpaid bookings found for testing';
END
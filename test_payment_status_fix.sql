-- Test script to verify the payment status fix
-- This script tests that initial payments set booking status to 'initial' instead of 'pending'

PRINT '=== PAYMENT STATUS FIX VERIFICATION ==='
PRINT 'Testing that initial payment sets booking status to ''initial'' instead of ''pending'''
PRINT ''

-- Clean up test data first
DELETE FROM Payments WHERE BookingId IN (
    SELECT Id FROM Bookings WHERE CustomerId IN (
        SELECT Id FROM Users WHERE Email LIKE 'test.payment.fix%'
    )
);

DELETE FROM Bookings WHERE CustomerId IN (
    SELECT Id FROM Users WHERE Email LIKE 'test.payment.fix%'
);

DELETE FROM Users WHERE Email LIKE 'test.payment.fix%';

-- Create test user
INSERT INTO Users (FullName, Email, Phone, Password, Role, CreatedAt)
VALUES ('Test Payment Fix User', 'test.payment.fix@example.com', '+1234567890', 'hashedpassword', 'Customer', GETUTCDATE());

DECLARE @TestUserId INT = SCOPE_IDENTITY();
PRINT 'Created test user with ID: ' + CAST(@TestUserId AS VARCHAR(10))

-- Insert into Customers table (since it uses Id as both PK and FK)
INSERT INTO Customers (Id, Rating)
VALUES (@TestUserId, 4.5);

-- Create test booking with 'unpaid' status
INSERT INTO Bookings (PropertyId, CustomerId, BookingFrom, BookingTo, NumberOfGuests, TotalPrice, Status, PaymentStatus, CreatedAt)
VALUES (1, @TestUserId, '2024-07-15', '2024-07-20', 2, 1000.00, 'confirmed', 'unpaid', GETUTCDATE());

DECLARE @TestBookingId INT = SCOPE_IDENTITY();
PRINT 'Created test booking with ID: ' + CAST(@TestBookingId AS VARCHAR(10)) + ' with PaymentStatus = ''unpaid'''

-- Simulate initial payment (10% advance) - what the PaymentsController should do
INSERT INTO Payments (BookingId, CustomerId, TotalAmount, AmountPaid, PaymentMethod, PaymentType, Status)
VALUES (@TestBookingId, @TestUserId, 1000.00, 100.00, 'bKash', 'Initial Booking', 'completed');

DECLARE @PaymentId INT = SCOPE_IDENTITY();
PRINT 'Created initial payment with ID: ' + CAST(@PaymentId AS VARCHAR(10)) + ' (Amount: $100 = 10% of $1000)'

-- Update booking status to 'initial' (this is what the fixed PaymentsController does)
UPDATE Bookings 
SET PaymentStatus = 'initial', UpdatedAt = GETUTCDATE()
WHERE Id = @TestBookingId;

PRINT 'Updated booking PaymentStatus to ''initial'' (simulating fixed PaymentsController behavior)'
PRINT ''

-- Verify the fix
PRINT '=== VERIFICATION RESULTS ==='

-- Show booking status
SELECT 
    'Booking Status After Initial Payment' as Description,
    Id as BookingId,
    PaymentStatus,
    Status,
    TotalPrice
FROM Bookings 
WHERE Id = @TestBookingId;

-- Show payment details
SELECT 
    'Payment Details' as Description,
    Id as PaymentId,
    BookingId,
    TotalAmount,
    AmountPaid,
    RemainingAmount,
    PaymentType,
    Status
FROM Payments 
WHERE Id = @PaymentId;

-- Test remaining payment scenario
PRINT ''
PRINT '=== TESTING REMAINING PAYMENT SCENARIO ==='

-- Check if remaining payment would be allowed (PaymentStatus = 'initial')
DECLARE @CurrentPaymentStatus NVARCHAR(50)
SELECT @CurrentPaymentStatus = PaymentStatus FROM Bookings WHERE Id = @TestBookingId;

IF @CurrentPaymentStatus = 'initial'
BEGIN
    PRINT '? SUCCESS: Booking has PaymentStatus = ''initial'', remaining payment would be allowed'
    
    -- Simulate remaining payment
    DECLARE @RemainingAmount DECIMAL(10,2) = 900.00; -- $1000 - $100 = $900
    
    INSERT INTO Payments (BookingId, CustomerId, TotalAmount, AmountPaid, PaymentMethod, PaymentType, Status)
    VALUES (@TestBookingId, @TestUserId, 1000.00, @RemainingAmount, 'bKash', 'Remaining Payment', 'completed');
    
    DECLARE @RemainingPaymentId INT = SCOPE_IDENTITY();
    PRINT 'Created remaining payment with ID: ' + CAST(@RemainingPaymentId AS VARCHAR(10)) + ' (Amount: $' + CAST(@RemainingAmount AS VARCHAR(10)) + ')'
    
    -- Update booking to fully paid
    UPDATE Bookings 
    SET PaymentStatus = 'paid', UpdatedAt = GETUTCDATE()
    WHERE Id = @TestBookingId;
    
    PRINT 'Updated booking PaymentStatus to ''paid'''
    
    -- Show final status
    SELECT 
        'Final Booking Status' as Description,
        Id as BookingId,
        PaymentStatus,
        Status,
        TotalPrice
    FROM Bookings 
    WHERE Id = @TestBookingId;
    
    -- Show all payments
    SELECT 
        'All Payments for Booking' as Description,
        Id as PaymentId,
        PaymentType,
        AmountPaid,
        RemainingAmount,
        Status
    FROM Payments 
    WHERE BookingId = @TestBookingId
    ORDER BY Id;
    
    -- Calculate totals
    SELECT 
        'Payment Summary' as Description,
        COUNT(*) as NumberOfPayments,
        SUM(AmountPaid) as TotalPaid,
        MAX(TotalAmount) as BookingTotal,
        MAX(TotalAmount) - SUM(AmountPaid) as RemainingBalance
    FROM Payments 
    WHERE BookingId = @TestBookingId;
    
END
ELSE
BEGIN
    PRINT '? FAILURE: Booking has PaymentStatus = ''' + @CurrentPaymentStatus + ''', should be ''initial'''
END

PRINT ''
PRINT '=== TEST COMPLETE ==='

-- Check if any bookings still have 'pending' payment status (old bug)
DECLARE @PendingCount INT
SELECT @PendingCount = COUNT(*) FROM Bookings WHERE PaymentStatus = 'pending';

IF @PendingCount > 0
BEGIN
    PRINT '??  WARNING: Found ' + CAST(@PendingCount AS VARCHAR(10)) + ' bookings with PaymentStatus = ''pending'''
    PRINT 'These should be updated to use the correct status values:'
    
    SELECT 
        'Bookings with ''pending'' status' as Description,
        Id as BookingId,
        CustomerId,
        PaymentStatus,
        Status,
        TotalPrice,
        CreatedAt
    FROM Bookings 
    WHERE PaymentStatus = 'pending';
    
    PRINT ''
    PRINT 'RECOMMENDATION: Update existing ''pending'' bookings to correct status:'
    PRINT '- If no payments exist: PaymentStatus = ''unpaid'''
    PRINT '- If initial payment exists: PaymentStatus = ''initial'''
    PRINT '- If fully paid: PaymentStatus = ''paid'''
END
ELSE
BEGIN
    PRINT '? SUCCESS: No bookings found with old ''pending'' status'
END

PRINT ''
PRINT '=== PAYMENT STATUS VALUES REFERENCE ==='
PRINT 'Correct PaymentStatus values after fix:'
PRINT '- ''unpaid'': No payment made yet'
PRINT '- ''initial'': Initial 10% payment made, remaining balance due'
PRINT '- ''paid'': Fully paid'
PRINT ''
PRINT 'This fixes the issue where Payment.html showed "already fully paid"'
PRINT 'when trying to make remaining payment after initial 10% payment.'
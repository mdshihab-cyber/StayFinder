-- Test Booking Functionality SQL Script
-- This script demonstrates the booking functionality

-- 1. View existing bookings
SELECT * FROM Bookings ORDER BY CreatedAt DESC;

-- 2. Sample booking data that would be created by the API
-- (This shows what the API endpoint will insert)

-- Example 1: Create a booking for Property ID 1, Customer ID 1
-- INSERT INTO Bookings (PropertyId, CustomerId, BookingFrom, BookingTo, NumberOfGuests, TotalPrice, Status, PaymentStatus, CreatedAt)
-- VALUES (1, 1, '2024-01-15', '2024-01-20', 2, 500.00, 'confirmed', 'pending', GETUTCDATE());

-- 3. Check for booking conflicts (this is what the API does internally)
-- Example query to check if dates conflict with existing bookings
DECLARE @PropertyId INT = 1;
DECLARE @BookingFrom DATETIME = '2024-01-15';
DECLARE @BookingTo DATETIME = '2024-01-20';

SELECT 
    'Existing Bookings for Property ' + CAST(@PropertyId AS NVARCHAR) + ':' AS Info,
    Id,
    BookingFrom,
    BookingTo,
    Status,
    'CONFLICT!' AS ConflictStatus
FROM Bookings 
WHERE PropertyId = @PropertyId 
AND Status IN ('confirmed', 'pending')
AND (
    (BookingFrom <= @BookingFrom AND BookingTo > @BookingFrom) OR
    (BookingFrom < @BookingTo AND BookingTo >= @BookingTo) OR
    (BookingFrom >= @BookingFrom AND BookingTo <= @BookingTo)
);

-- 4. View booking details with property information
SELECT 
    b.Id AS BookingId,
    b.Status,
    b.PaymentStatus,
    b.BookingFrom,
    b.BookingTo,
    DATEDIFF(day, b.BookingFrom, b.BookingTo) AS NumberOfDays,
    b.NumberOfGuests,
    b.TotalPrice,
    p.Name AS PropertyName,
    p.Location,
    p.PricePerDay,
    c.Id AS CustomerId
FROM Bookings b
INNER JOIN Properties p ON b.PropertyId = p.Id  
INNER JOIN Customers c ON b.CustomerId = c.Id
ORDER BY b.CreatedAt DESC;

-- 5. Calculate potential booking price (what the frontend calculates)
DECLARE @PricePerDay DECIMAL(10,2) = 100.00;
DECLARE @Days INT = DATEDIFF(day, '2024-01-15', '2024-01-20');
DECLARE @Guests INT = 2;
SELECT 
    @PricePerDay AS PricePerDay,
    @Days AS NumberOfDays,
    @Guests AS NumberOfGuests,
    (@PricePerDay * @Days * @Guests) AS TotalCalculatedPrice;

-- 6. Get customer booking history
DECLARE @CustomerId INT = 1;
SELECT 
    b.*,
    p.Name AS PropertyName,
    p.Location
FROM Bookings b
INNER JOIN Properties p ON b.PropertyId = p.Id
WHERE b.CustomerId = @CustomerId
ORDER BY b.CreatedAt DESC;
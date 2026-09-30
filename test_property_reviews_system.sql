-- Test script for PropertyReviews system
-- This script creates test data and verifies the review functionality

PRINT '=== PROPERTY REVIEWS SYSTEM TEST ==='
PRINT 'Testing the PropertyReviews table and backend functionality'
PRINT ''

-- Clean up existing test data
DELETE FROM PropertyReviews WHERE CustomerId IN (
    SELECT Id FROM Users WHERE Email LIKE 'review.test%'
);

DELETE FROM Bookings WHERE CustomerId IN (
    SELECT Id FROM Users WHERE Email LIKE 'review.test%'
);

DELETE FROM Users WHERE Email LIKE 'review.test%';

-- Create test customer
INSERT INTO Users (FullName, Email, Phone, Password, Role, CreatedAt)
VALUES ('Review Test Customer', 'review.test@example.com', '+1234567890', 'hashedpassword', 'Customer', GETUTCDATE());

DECLARE @TestCustomerId INT = SCOPE_IDENTITY();
PRINT 'Created test customer with ID: ' + CAST(@TestCustomerId AS VARCHAR(10))

-- Insert into Customers table (since it uses Id as both PK and FK)
INSERT INTO Customers (Id, Rating)
VALUES (@TestCustomerId, 4.0);

-- Get a property ID for testing (use existing property or create one)
DECLARE @TestPropertyId INT = 1; -- Assuming property with ID 1 exists

-- Verify property exists
IF NOT EXISTS (SELECT 1 FROM Properties WHERE Id = @TestPropertyId)
BEGIN
    PRINT 'Creating test property...'
    INSERT INTO Properties (Name, Type, Location, PricePerDay, HostName, ImageUrl, Status, CreatedAt)
    VALUES ('Review Test Property', 'Apartment', 'Test City', 100.00, 'Test Host', 'test.jpg', 'active', GETUTCDATE());
    SET @TestPropertyId = SCOPE_IDENTITY();
END

PRINT 'Using property ID: ' + CAST(@TestPropertyId AS VARCHAR(10))

-- Create a completed booking (paid status)
INSERT INTO Bookings (PropertyId, CustomerId, BookingFrom, BookingTo, NumberOfGuests, TotalPrice, Status, PaymentStatus, CreatedAt)
VALUES (@TestPropertyId, @TestCustomerId, '2024-07-01', '2024-07-05', 2, 400.00, 'confirmed', 'paid', GETUTCDATE());

DECLARE @TestBookingId INT = SCOPE_IDENTITY();
PRINT 'Created test booking with ID: ' + CAST(@TestBookingId AS VARCHAR(10)) + ' (Status: confirmed, PaymentStatus: paid)'
PRINT ''

-- Test 1: Direct Property Review
PRINT '=== TEST 1: DIRECT PROPERTY REVIEW ==='
INSERT INTO PropertyReviews (PropertyId, CustomerId, Rating, Comment, CreatedAt)
VALUES (@TestPropertyId, @TestCustomerId, 5, 'Excellent property! Great location and very clean.', GETUTCDATE());

DECLARE @ReviewId1 INT = SCOPE_IDENTITY();
PRINT 'Created direct property review with ID: ' + CAST(@ReviewId1 AS VARCHAR(10))

-- Show the review
SELECT 
    'Direct Property Review' as ReviewType,
    Id, PropertyId, CustomerId, Rating, Comment, CreatedAt
FROM PropertyReviews 
WHERE Id = @ReviewId1;

PRINT ''

-- Test 2: Simulate Review from Payment Modal (this would normally come from the API)
PRINT '=== TEST 2: REVIEW FROM BOOKING (PAYMENT MODAL) ==='

-- Create another customer for booking-based review
INSERT INTO Users (FullName, Email, Phone, Password, Role, CreatedAt)
VALUES ('Payment Modal Customer', 'review.payment@example.com', '+1234567891', 'hashedpassword', 'Customer', GETUTCDATE());

DECLARE @PaymentCustomerId INT = SCOPE_IDENTITY();
INSERT INTO Customers (Id, Rating) VALUES (@PaymentCustomerId, 4.5);

-- Create another completed booking
INSERT INTO Bookings (PropertyId, CustomerId, BookingFrom, BookingTo, NumberOfGuests, TotalPrice, Status, PaymentStatus, CreatedAt)
VALUES (@TestPropertyId, @PaymentCustomerId, '2024-07-10', '2024-07-15', 4, 600.00, 'confirmed', 'paid', GETUTCDATE());

DECLARE @PaymentBookingId INT = SCOPE_IDENTITY();

-- Simulate the review that would be created by the API endpoint
INSERT INTO PropertyReviews (PropertyId, CustomerId, Rating, Comment, CreatedAt)
VALUES (@TestPropertyId, @PaymentCustomerId, 4, 'Good property overall. The payment process was smooth and the stay was comfortable.', GETUTCDATE());

DECLARE @ReviewId2 INT = SCOPE_IDENTITY();
PRINT 'Created booking-based review with ID: ' + CAST(@ReviewId2 AS VARCHAR(10))
PRINT 'Associated with booking ID: ' + CAST(@PaymentBookingId AS VARCHAR(10))

-- Show the review
SELECT 
    'Booking-Based Review' as ReviewType,
    Id, PropertyId, CustomerId, Rating, Comment, CreatedAt
FROM PropertyReviews 
WHERE Id = @ReviewId2;

PRINT ''

-- Test 3: Review Statistics
PRINT '=== TEST 3: REVIEW STATISTICS ==='

SELECT 
    'Property Review Statistics' as Description,
    COUNT(*) as TotalReviews,
    AVG(CAST(Rating as FLOAT)) as AverageRating,
    MIN(Rating) as MinRating,
    MAX(Rating) as MaxRating,
    SUM(CASE WHEN Rating = 5 THEN 1 ELSE 0 END) as FiveStarCount,
    SUM(CASE WHEN Rating = 4 THEN 1 ELSE 0 END) as FourStarCount,
    SUM(CASE WHEN Rating = 3 THEN 1 ELSE 0 END) as ThreeStarCount,
    SUM(CASE WHEN Rating = 2 THEN 1 ELSE 0 END) as TwoStarCount,
    SUM(CASE WHEN Rating = 1 THEN 1 ELSE 0 END) as OneStarCount
FROM PropertyReviews
WHERE PropertyId = @TestPropertyId;

PRINT ''

-- Test 4: Reviews with Customer Information (API endpoint simulation)
PRINT '=== TEST 4: REVIEWS WITH CUSTOMER INFORMATION ==='

SELECT 
    'Property Reviews with Customer Names' as Description,
    pr.Id as ReviewId,
    pr.PropertyId,
    pr.CustomerId,
    u.FullName as CustomerName,
    pr.Rating,
    pr.Comment,
    pr.CreatedAt
FROM PropertyReviews pr
JOIN Users u ON pr.CustomerId = u.Id
WHERE pr.PropertyId = @TestPropertyId
ORDER BY pr.CreatedAt DESC;

PRINT ''

-- Test 5: Customer's Review History
PRINT '=== TEST 5: CUSTOMER REVIEW HISTORY ==='

SELECT 
    'Customer Review History' as Description,
    pr.Id as ReviewId,
    pr.PropertyId,
    p.Name as PropertyName,
    p.Location,
    pr.Rating,
    pr.Comment,
    pr.CreatedAt
FROM PropertyReviews pr
JOIN Properties p ON pr.PropertyId = p.Id
WHERE pr.CustomerId = @TestCustomerId
ORDER BY pr.CreatedAt DESC;

PRINT ''

-- Test 6: Validate Review Constraints
PRINT '=== TEST 6: CONSTRAINT VALIDATION ==='

-- Test rating constraint (should fail for ratings outside 1-5 range)
BEGIN TRY
    INSERT INTO PropertyReviews (PropertyId, CustomerId, Rating, Comment, CreatedAt)
    VALUES (@TestPropertyId, @TestCustomerId, 6, 'Invalid rating test', GETUTCDATE());
    PRINT '? FAILURE: Rating constraint not enforced (rating = 6 should fail)'
END TRY
BEGIN CATCH
    PRINT '? SUCCESS: Rating constraint properly enforced (rating must be 1-5)'
END CATCH

-- Test duplicate review prevention (this would be handled by API, not database constraint)
DECLARE @DuplicateCount INT
SELECT @DuplicateCount = COUNT(*) 
FROM PropertyReviews 
WHERE PropertyId = @TestPropertyId AND CustomerId = @TestCustomerId;

IF @DuplicateCount > 1
BEGIN
    PRINT '??  WARNING: Customer has multiple reviews for same property (should be prevented by API)'
END
ELSE
BEGIN
    PRINT '? SUCCESS: No duplicate reviews found'
END

PRINT ''

-- Test 7: Foreign Key Constraints
PRINT '=== TEST 7: FOREIGN KEY VALIDATION ==='

-- Test invalid property ID (should fail)
BEGIN TRY
    INSERT INTO PropertyReviews (PropertyId, CustomerId, Rating, Comment, CreatedAt)
    VALUES (99999, @TestCustomerId, 5, 'Invalid property test', GETUTCDATE());
    PRINT '? FAILURE: Property foreign key constraint not enforced'
END TRY
BEGIN CATCH
    PRINT '? SUCCESS: Property foreign key constraint properly enforced'
END CATCH

-- Test invalid customer ID (should fail)
BEGIN TRY
    INSERT INTO PropertyReviews (PropertyId, CustomerId, Rating, Comment, CreatedAt)
    VALUES (@TestPropertyId, 99999, 5, 'Invalid customer test', GETUTCDATE());
    PRINT '? FAILURE: Customer foreign key constraint not enforced'
END TRY
BEGIN CATCH
    PRINT '? SUCCESS: Customer foreign key constraint properly enforced'
END CATCH

PRINT ''

-- Summary
PRINT '=== TEST SUMMARY ==='
PRINT '? PropertyReviews table structure: TESTED'
PRINT '? Basic review insertion: TESTED'
PRINT '? Review statistics calculation: TESTED'
PRINT '? Customer information joining: TESTED'
PRINT '? Property information joining: TESTED'
PRINT '? Rating constraints (1-5): TESTED'
PRINT '? Foreign key constraints: TESTED'
PRINT ''
PRINT 'Review system is ready for API integration!'

-- API endpoints to test:
PRINT '=== API ENDPOINTS TO TEST ==='
PRINT 'POST   /api/PropertyReviews - Create direct property review'
PRINT 'POST   /api/PropertyReviews/from-booking - Create review from booking (Payment modal)'
PRINT 'GET    /api/PropertyReviews/property/{propertyId} - Get all reviews for a property'
PRINT 'GET    /api/PropertyReviews/customer/{customerId} - Get all reviews by a customer'
PRINT 'GET    /api/PropertyReviews/property/{propertyId}/stats - Get review statistics'
PRINT 'DELETE /api/PropertyReviews/{reviewId}?customerId={customerId} - Delete customer review'

-- Clean up test data (comment out to keep test data)
-- DELETE FROM PropertyReviews WHERE PropertyId = @TestPropertyId;
-- DELETE FROM Bookings WHERE Id IN (@TestBookingId, @PaymentBookingId);
-- DELETE FROM Customers WHERE Id IN (@TestCustomerId, @PaymentCustomerId);
-- DELETE FROM Users WHERE Id IN (@TestCustomerId, @PaymentCustomerId);
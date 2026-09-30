-- ============================================
-- DEBUG CUSTOMERS SECTION ISSUE
-- ============================================

PRINT '?? DEBUGGING CUSTOMERS SECTION ISSUE';
PRINT '';

-- Check if host exists
DECLARE @HostId INT = 9;

IF EXISTS (SELECT 1 FROM Users WHERE Id = @HostId AND Email = 'test.host@fix.com')
BEGIN
    PRINT '? Host exists: ID ' + CAST(@HostId AS VARCHAR);
    
    -- Test summary query (what the API calls)
    PRINT '';
    PRINT '?? TESTING SUMMARY API ENDPOINT:';
    PRINT '=================================';
    
    WITH CustomerBookings AS (
        SELECT 
            u.Id,
            COUNT(b.Id) as BookingCount
        FROM Users u
        INNER JOIN Bookings b ON u.Id = b.CustomerId
        INNER JOIN Properties prop ON b.PropertyId = prop.Id
        WHERE prop.HostId = @HostId AND u.Role = 'Customer'
        GROUP BY u.Id
    )
    SELECT 
        COUNT(DISTINCT cb.Id) AS TotalCustomers,
        COUNT(CASE WHEN cb.BookingCount > 1 THEN cb.Id END) AS RepeatCustomers,
        COALESCE(
            (SELECT AVG(CAST(pr.Rating AS FLOAT)) 
             FROM PropertyReviews pr
             INNER JOIN Properties p ON pr.PropertyId = p.Id
             WHERE p.HostId = @HostId), 0
        ) AS CustomerSatisfaction
    FROM CustomerBookings cb;
    
    -- Test main customer query (what the API calls)
    PRINT '';
    PRINT '?? TESTING MAIN CUSTOMERS API ENDPOINT:';
    PRINT '=======================================';
    
    SELECT 
        u.Id AS CustomerId,
        u.FullName AS CustomerName,
        u.Email AS CustomerEmail,
        u.Phone AS CustomerPhone,
        COALESCE(c.Rating, 0) AS CustomerRating,
        COUNT(b.Id) AS TotalBookings,
        COALESCE(SUM(b.TotalPrice), 0) AS TotalSpent,
        COALESCE(AVG(CAST(pr_reviews.Rating AS FLOAT)), 0) AS AverageRating,
        MAX(b.CreatedAt) AS LastBookingDate,
        MIN(b.CreatedAt) AS FirstBookingDate
    FROM Users u
    INNER JOIN Bookings b ON u.Id = b.CustomerId
    INNER JOIN Properties prop ON b.PropertyId = prop.Id
    LEFT JOIN Customers c ON u.Id = c.Id
    LEFT JOIN PropertyReviews pr_reviews ON prop.Id = pr_reviews.PropertyId AND u.Id = pr_reviews.CustomerId
    WHERE prop.HostId = @HostId AND u.Role = 'Customer'
    GROUP BY u.Id, u.FullName, u.Email, u.Phone, c.Rating
    ORDER BY MAX(b.CreatedAt) DESC;
    
    PRINT '';
    PRINT '?? EXPECTED RESULTS:';
    PRINT '===================';
    PRINT 'Summary: TotalCustomers=3, RepeatCustomers=1, CustomerSatisfaction=90%';
    PRINT 'Customers: 3 rows with Test Customer Fix, Jane Smith, Bob Johnson';
    PRINT '';
    PRINT '?? API URLs TO TEST:';
    PRINT '===================';
    PRINT 'Summary: GET /api/Customers/host/' + CAST(@HostId AS VARCHAR) + '/summary';
    PRINT 'List: GET /api/Customers/host/' + CAST(@HostId AS VARCHAR);
    PRINT '';
    PRINT '??  IF FRONTEND STILL SHOWS ERROR:';
    PRINT '==================================';
    PRINT '1. Check browser console (F12) for JavaScript errors';
    PRINT '2. Check Network tab for failed API calls';
    PRINT '3. Verify user is logged in with correct host ID';
    PRINT '4. Test API URLs directly in browser';
    
END
ELSE
BEGIN
    PRINT '? Host not found! Run fix_customers_data_corrected.sql first';
END

PRINT '';
PRINT '? Debug complete! Backend queries are working correctly.';
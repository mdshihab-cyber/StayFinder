-- Test script to verify Property functionality

-- 1. Check current state of all tables
SELECT 'Current Users:' as Info;
SELECT Id, Role, FullName, Email, CreatedAt FROM Users ORDER BY Id;

SELECT 'Current Hosts:' as Info;
SELECT h.HostId, h.UserId, u.FullName, h.Bio, h.Rating, h.NumberOfProperties 
FROM Hosts h
JOIN Users u ON h.UserId = u.Id
ORDER BY h.HostId;

SELECT 'Current Properties:' as Info;
SELECT p.Id, p.HostId, u.FullName as HostName, p.Name, p.Type, p.PricePerDay, 
       p.Location, p.Status, p.BookingStatus, p.CreatedAt
FROM Properties p
JOIN Users u ON p.HostId = u.Id
ORDER BY p.Id;

-- 2. Test query to get properties for a specific host
-- Replace '1' with actual host ID
SELECT 'Properties for Host ID 1:' as Info;
SELECT * FROM Properties WHERE HostId = 1;

-- 3. Check for any data integrity issues
SELECT 'Properties without valid hosts:' as Info;
SELECT p.Id, p.Name, p.HostId
FROM Properties p
LEFT JOIN Users u ON p.HostId = u.Id
WHERE u.Id IS NULL OR u.Role != 'Host';

-- 4. Summary statistics
SELECT 'Summary Statistics:' as Info;
SELECT 
    (SELECT COUNT(*) FROM Users WHERE Role = 'Host') as TotalHosts,
    (SELECT COUNT(*) FROM Properties) as TotalProperties,
    (SELECT COUNT(*) FROM Properties WHERE Status = 'active') as ActiveProperties,
    (SELECT COUNT(*) FROM Properties WHERE BookingStatus = 'booked') as BookedProperties;
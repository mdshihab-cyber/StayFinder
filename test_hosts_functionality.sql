-- Test script to verify the Host registration and update functionality

-- 1. Check current state of Users and Hosts tables
SELECT 'Current Users:' as Info;
SELECT Id, Role, FullName, Email, CreatedAt FROM Users ORDER BY Id;

SELECT 'Current Hosts:' as Info;
SELECT h.HostId, h.UserId, u.FullName, h.Bio, h.Rating, h.NumberOfProperties 
FROM Hosts h
JOIN Users u ON h.UserId = u.Id
ORDER BY h.HostId;

-- 2. Test query to see which Host users are missing from Hosts table
SELECT 'Host users without Hosts records:' as Info;
SELECT u.Id, u.FullName, u.Email, u.Role
FROM Users u
LEFT JOIN Hosts h ON u.Id = h.UserId
WHERE u.Role = 'Host' AND h.UserId IS NULL;
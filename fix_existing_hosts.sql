-- Fix script for existing Host users who don't have records in Hosts table
-- Run this if you have existing Host users who registered before the Hosts table integration

-- Insert missing Host records for existing Host users
INSERT INTO Hosts (UserId, Bio, Rating, NumberOfProperties)
SELECT u.Id, '', 0.00, 0
FROM Users u
LEFT JOIN Hosts h ON u.Id = h.UserId
WHERE u.Role = 'Host' AND h.UserId IS NULL;

-- Verify the fix
SELECT 
    u.Id as UserId,
    u.FullName,
    u.Role,
    h.HostId,
    h.Bio,
    h.Rating,
    h.NumberOfProperties
FROM Users u
LEFT JOIN Hosts h ON u.Id = h.UserId
WHERE u.Role = 'Host'
ORDER BY u.Id;
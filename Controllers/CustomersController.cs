using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using System.Data;
using System.Threading.Tasks;
using System;
using System.Collections.Generic;

namespace StayFinder_Web_API.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class CustomersController : ControllerBase
    {
        private readonly string _connectionString = "Server=DESKTOP-7VNIMVI\\SQLEXPRESS;Database=StayFinderWebApiDB;Trusted_Connection=True;Encrypt=False;";

        [HttpGet("host/{hostId}")]
        public async Task<IActionResult> GetHostCustomers(int hostId)
        {
            var customers = new List<object>();
            
            try
            {
                using (var connection = new SqlConnection(_connectionString))
                {
                    await connection.OpenAsync();
                    
                    // Fixed query without BookingId reference
                    var query = @"
                        SELECT DISTINCT
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
                        ORDER BY MAX(b.CreatedAt) DESC";

                    using (var command = new SqlCommand(query, connection))
                    {
                        command.Parameters.AddWithValue("@HostId", hostId);
                        using (var reader = await command.ExecuteReaderAsync())
                        {
                            while (await reader.ReadAsync())
                            {
                                customers.Add(new
                                {
                                    CustomerId = reader.GetInt32("CustomerId"),
                                    CustomerName = reader.IsDBNull("CustomerName") ? "Unknown" : reader.GetString("CustomerName"),
                                    CustomerEmail = reader.IsDBNull("CustomerEmail") ? "" : reader.GetString("CustomerEmail"),
                                    CustomerPhone = reader.IsDBNull("CustomerPhone") ? "" : reader.GetString("CustomerPhone"),
                                    CustomerRating = reader.IsDBNull("CustomerRating") ? 0 : reader.GetDecimal("CustomerRating"),
                                    TotalBookings = reader.GetInt32("TotalBookings"),
                                    TotalSpent = reader.GetDecimal("TotalSpent"),
                                    AverageRating = Math.Round(reader.GetDouble("AverageRating"), 1),
                                    LastBookingDate = reader.GetDateTime("LastBookingDate"),
                                    FirstBookingDate = reader.GetDateTime("FirstBookingDate")
                                });
                            }
                        }
                    }
                }
                
                return Ok(customers);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error in GetHostCustomers: {ex.Message}");
                Console.WriteLine($"Stack trace: {ex.StackTrace}");
                
                return StatusCode(500, new 
                { 
                    error = "Failed to load customers", 
                    message = ex.Message,
                    details = "Check server logs for more information"
                });
            }
        }

        [HttpGet("host/{hostId}/summary")]
        public async Task<IActionResult> GetHostCustomersSummary(int hostId)
        {
            try
            {
                using (var connection = new SqlConnection(_connectionString))
                {
                    await connection.OpenAsync();
                    
                    // Simplified and fixed summary query
                    var query = @"
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
                        FROM CustomerBookings cb";

                    using (var command = new SqlCommand(query, connection))
                    {
                        command.Parameters.AddWithValue("@HostId", hostId);
                        using (var reader = await command.ExecuteReaderAsync())
                        {
                            if (await reader.ReadAsync())
                            {
                                return Ok(new
                                {
                                    TotalCustomers = reader.GetInt32("TotalCustomers"),
                                    RepeatCustomers = reader.GetInt32("RepeatCustomers"),
                                    CustomerSatisfaction = Math.Round(reader.IsDBNull("CustomerSatisfaction") ? 0 : reader.GetDouble("CustomerSatisfaction") * 20, 1) // Convert to percentage (1-5 scale to 20-100%)
                                });
                            }
                        }
                    }
                }

                // Return empty summary if no data found
                return Ok(new
                {
                    TotalCustomers = 0,
                    RepeatCustomers = 0,
                    CustomerSatisfaction = 0.0
                });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error in GetHostCustomersSummary: {ex.Message}");
                
                return StatusCode(500, new 
                { 
                    error = "Failed to load customer summary", 
                    message = ex.Message 
                });
            }
        }

        [HttpGet("host/{hostId}/search")]
        public async Task<IActionResult> SearchHostCustomers(int hostId, [FromQuery] string searchTerm)
        {
            var customers = new List<object>();
            
            try
            {
                if (string.IsNullOrEmpty(searchTerm))
                {
                    return await GetHostCustomers(hostId);
                }

                using (var connection = new SqlConnection(_connectionString))
                {
                    await connection.OpenAsync();
                    
                    var query = @"
                        SELECT DISTINCT
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
                        WHERE prop.HostId = @HostId 
                        AND u.Role = 'Customer'
                        AND (u.FullName LIKE @SearchTerm OR u.Email LIKE @SearchTerm OR u.Phone LIKE @SearchTerm)
                        GROUP BY u.Id, u.FullName, u.Email, u.Phone, c.Rating
                        ORDER BY MAX(b.CreatedAt) DESC";

                    using (var command = new SqlCommand(query, connection))
                    {
                        command.Parameters.AddWithValue("@HostId", hostId);
                        command.Parameters.AddWithValue("@SearchTerm", $"%{searchTerm}%");
                        using (var reader = await command.ExecuteReaderAsync())
                        {
                            while (await reader.ReadAsync())
                            {
                                customers.Add(new
                                {
                                    CustomerId = reader.GetInt32("CustomerId"),
                                    CustomerName = reader.IsDBNull("CustomerName") ? "Unknown" : reader.GetString("CustomerName"),
                                    CustomerEmail = reader.IsDBNull("CustomerEmail") ? "" : reader.GetString("CustomerEmail"),
                                    CustomerPhone = reader.IsDBNull("CustomerPhone") ? "" : reader.GetString("CustomerPhone"),
                                    CustomerRating = reader.IsDBNull("CustomerRating") ? 0 : reader.GetDecimal("CustomerRating"),
                                    TotalBookings = reader.GetInt32("TotalBookings"),
                                    TotalSpent = reader.GetDecimal("TotalSpent"),
                                    AverageRating = Math.Round(reader.GetDouble("AverageRating"), 1),
                                    LastBookingDate = reader.GetDateTime("LastBookingDate"),
                                    FirstBookingDate = reader.GetDateTime("FirstBookingDate")
                                });
                            }
                        }
                    }
                }
                
                return Ok(customers);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error in SearchHostCustomers: {ex.Message}");
                
                return StatusCode(500, new 
                { 
                    error = "Failed to search customers", 
                    message = ex.Message 
                });
            }
        }
        
        // Test endpoint to verify the controller is working
        [HttpGet("test")]
        public IActionResult Test()
        {
            return Ok(new { message = "CustomersController is working", timestamp = DateTime.UtcNow });
        }
    }
}
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using System.Data;

namespace StayFinder_Web_API.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class AdminController : ControllerBase
    {
        private readonly string connectionString = "Server=DESKTOP-7VNIMVI\\SQLEXPRESS;Database=StayFinderWebApiDB;Trusted_Connection=True;Encrypt=False;";

        // GET all users
        [HttpGet("users")]
        public IActionResult GetAllUsers()
        {
            try
            {
                var users = new List<object>();
                using (var conn = new SqlConnection(connectionString))
                {
                    conn.Open();
                    var cmd = new SqlCommand(@"
                        SELECT Id, Role, FullName, Email, Phone, CreatedAt
                        FROM Users
                        ORDER BY CreatedAt DESC", conn);

                    using (var reader = cmd.ExecuteReader())
                    {
                        while (reader.Read())
                        {
                            users.Add(new
                            {
                                id = reader["Id"],
                                role = reader["Role"].ToString(),
                                fullName = reader["FullName"].ToString(),
                                email = reader["Email"].ToString(),
                                phone = reader["Phone"].ToString(),
                                createdAt = Convert.ToDateTime(reader["CreatedAt"]).ToString("yyyy-MM-dd HH:mm:ss")
                            });
                        }
                    }
                }
                return Ok(users);
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { message = "Error retrieving users", error = ex.Message });
            }
        }

        // GET users count
        [HttpGet("users/count")]
        public IActionResult GetUsersCount()
        {
            try
            {
                using (var conn = new SqlConnection(connectionString))
                {
                    conn.Open();
                    var cmd = new SqlCommand("SELECT COUNT(*) FROM Users", conn);
                    var count = (int)cmd.ExecuteScalar();
                    return Ok(new { count = count });
                }
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { message = "Error getting users count", error = ex.Message });
            }
        }

        // GET properties count
        [HttpGet("properties/count")]
        public IActionResult GetPropertiesCount()
        {
            try
            {
                using (var conn = new SqlConnection(connectionString))
                {
                    conn.Open();
                    var cmd = new SqlCommand("SELECT COUNT(*) FROM Properties WHERE Status = 'active'", conn);
                    var count = (int)cmd.ExecuteScalar();
                    return Ok(new { count = count });
                }
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { message = "Error getting properties count", error = ex.Message });
            }
        }

        // GET bookings count
        [HttpGet("bookings/count")]
        public IActionResult GetBookingsCount()
        {
            try
            {
                using (var conn = new SqlConnection(connectionString))
                {
                    conn.Open();
                    var cmd = new SqlCommand("SELECT COUNT(*) FROM Bookings", conn);
                    var count = (int)cmd.ExecuteScalar();
                    return Ok(new { count = count });
                }
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { message = "Error getting bookings count", error = ex.Message });
            }
        }

        // GET total revenue
        [HttpGet("revenue/total")]
        public IActionResult GetTotalRevenue()
        {
            try
            {
                using (var conn = new SqlConnection(connectionString))
                {
                    conn.Open();
                    
                    // Get total revenue from completed payments
                    var totalCmd = new SqlCommand(@"
                        SELECT COALESCE(SUM(AmountPaid), 0) as TotalRevenue
                        FROM Payments 
                        WHERE Status = 'completed'", conn);
                    var totalRevenue = (decimal)totalCmd.ExecuteScalar();

                    // Get monthly revenue (last 30 days)
                    var monthlyCmd = new SqlCommand(@"
                        SELECT COALESCE(SUM(AmountPaid), 0) as MonthlyRevenue
                        FROM Payments 
                        WHERE Status = 'completed' 
                        AND PaymentDate >= DATEADD(day, -30, GETDATE())", conn);
                    var monthlyRevenue = (decimal)monthlyCmd.ExecuteScalar();

                    return Ok(new { 
                        totalRevenue = totalRevenue,
                        monthlyRevenue = monthlyRevenue,
                        platformCommission = totalRevenue * 0.10m,
                        hostPayouts = totalRevenue * 0.90m
                    });
                }
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { message = "Error getting revenue", error = ex.Message });
            }
        }

        // GET all payments for admin
        [HttpGet("payments")]
        public IActionResult GetAllPayments()
        {
            try
            {
                var payments = new List<object>();
                using (var conn = new SqlConnection(connectionString))
                {
                    conn.Open();
                    var cmd = new SqlCommand(@"
                        SELECT p.Id, p.BookingId, p.TotalAmount, p.AmountPaid, p.PaymentMethod, 
                               p.PaymentType, p.PaymentDate, p.Status,
                               u.FullName as CustomerName,
                               pr.Name as PropertyName,
                               (p.AmountPaid * 0.10) as PlatformCommission,
                               (p.AmountPaid * 0.90) as HostEarning
                        FROM Payments p
                        JOIN Bookings b ON p.BookingId = b.Id
                        JOIN Users u ON p.CustomerId = u.Id
                        JOIN Properties pr ON b.PropertyId = pr.Id
                        WHERE p.Status = 'completed'
                        ORDER BY p.PaymentDate DESC", conn);

                    using (var reader = cmd.ExecuteReader())
                    {
                        while (reader.Read())
                        {
                            payments.Add(new
                            {
                                id = reader["Id"],
                                bookingId = reader["BookingId"],
                                customerName = reader["CustomerName"].ToString(),
                                propertyName = reader["PropertyName"].ToString(),
                                totalAmount = reader["TotalAmount"],
                                amountPaid = reader["AmountPaid"],
                                platformCommission = reader["PlatformCommission"],
                                hostEarning = reader["HostEarning"],
                                paymentMethod = reader["PaymentMethod"].ToString(),
                                paymentType = reader["PaymentType"].ToString(),
                                paymentDate = Convert.ToDateTime(reader["PaymentDate"]).ToString("yyyy-MM-dd HH:mm:ss"),
                                status = reader["Status"].ToString()
                            });
                        }
                    }
                }
                return Ok(payments);
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { message = "Error retrieving payments", error = ex.Message });
            }
        }

        // GET platform statistics
        [HttpGet("stats")]
        public IActionResult GetPlatformStats()
        {
            try
            {
                using (var conn = new SqlConnection(connectionString))
                {
                    conn.Open();
                    
                    var stats = new Dictionary<string, object>();
                    
                    // Total users
                    var usersCmd = new SqlCommand("SELECT COUNT(*) FROM Users", conn);
                    stats["totalUsers"] = (int)usersCmd.ExecuteScalar();
                    
                    // Total hosts
                    var hostsCmd = new SqlCommand("SELECT COUNT(*) FROM Users WHERE Role = 'Host'", conn);
                    stats["totalHosts"] = (int)hostsCmd.ExecuteScalar();
                    
                    // Total customers
                    var customersCmd = new SqlCommand("SELECT COUNT(*) FROM Users WHERE Role = 'Customer'", conn);
                    stats["totalCustomers"] = (int)customersCmd.ExecuteScalar();
                    
                    // Total properties
                    var propertiesCmd = new SqlCommand("SELECT COUNT(*) FROM Properties WHERE Status = 'active'", conn);
                    stats["totalProperties"] = (int)propertiesCmd.ExecuteScalar();
                    
                    // Total bookings
                    var bookingsCmd = new SqlCommand("SELECT COUNT(*) FROM Bookings", conn);
                    stats["totalBookings"] = (int)bookingsCmd.ExecuteScalar();
                    
                    // Total revenue
                    var revenueCmd = new SqlCommand("SELECT COALESCE(SUM(AmountPaid), 0) FROM Payments WHERE Status = 'completed'", conn);
                    stats["totalRevenue"] = (decimal)revenueCmd.ExecuteScalar();

                    return Ok(stats);
                }
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { message = "Error getting platform stats", error = ex.Message });
            }
        }
    }
}
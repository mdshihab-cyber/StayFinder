using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using StayFinder_Web_API.Models;
using System.Data;

namespace StayFinder_Web_API.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class PropertyReviewsController : ControllerBase
    {
        private readonly string _connectionString = "Server=DESKTOP-7VNIMVI\\SQLEXPRESS;Database=StayFinderWebApiDB;Trusted_Connection=True;Encrypt=False;";

        [HttpPost]
        public async Task<IActionResult> CreateReview([FromBody] CreateReviewRequest request)
        {
            try
            {
                if (!ModelState.IsValid)
                {
                    return BadRequest(new { message = "Invalid review data", errors = ModelState });
                }

                using var connection = new SqlConnection(_connectionString);
                await connection.OpenAsync();
                using var transaction = connection.BeginTransaction();

                try
                {
                    // Verify property exists
                    var propertyQuery = "SELECT COUNT(*) FROM Properties WHERE Id = @PropertyId";
                    using var propertyCmd = new SqlCommand(propertyQuery, connection, transaction);
                    propertyCmd.Parameters.AddWithValue("@PropertyId", request.PropertyId);
                    var propertyExists = (int)await propertyCmd.ExecuteScalarAsync() > 0;

                    if (!propertyExists)
                    {
                        return BadRequest(new { message = "Property not found" });
                    }

                    // Verify customer exists
                    var customerQuery = "SELECT COUNT(*) FROM Users WHERE Id = @CustomerId AND Role = 'Customer'";
                    using var customerCmd = new SqlCommand(customerQuery, connection, transaction);
                    customerCmd.Parameters.AddWithValue("@CustomerId", request.CustomerId);
                    var customerExists = (int)await customerCmd.ExecuteScalarAsync() > 0;

                    if (!customerExists)
                    {
                        return BadRequest(new { message = "Customer not found" });
                    }

                    // Check if customer has already reviewed this property
                    var existingReviewQuery = "SELECT COUNT(*) FROM PropertyReviews WHERE PropertyId = @PropertyId AND CustomerId = @CustomerId";
                    using var existingCmd = new SqlCommand(existingReviewQuery, connection, transaction);
                    existingCmd.Parameters.AddWithValue("@PropertyId", request.PropertyId);
                    existingCmd.Parameters.AddWithValue("@CustomerId", request.CustomerId);
                    var hasExistingReview = (int)await existingCmd.ExecuteScalarAsync() > 0;

                    if (hasExistingReview)
                    {
                        return BadRequest(new { message = "You have already reviewed this property" });
                    }

                    // Insert the review
                    var insertQuery = @"
                        INSERT INTO PropertyReviews (PropertyId, CustomerId, Rating, Comment, CreatedAt)
                        OUTPUT INSERTED.Id
                        VALUES (@PropertyId, @CustomerId, @Rating, @Comment, @CreatedAt)";

                    using var insertCmd = new SqlCommand(insertQuery, connection, transaction);
                    insertCmd.Parameters.AddWithValue("@PropertyId", request.PropertyId);
                    insertCmd.Parameters.AddWithValue("@CustomerId", request.CustomerId);
                    insertCmd.Parameters.AddWithValue("@Rating", request.Rating);
                    insertCmd.Parameters.AddWithValue("@Comment", request.Comment ?? (object)DBNull.Value);
                    insertCmd.Parameters.AddWithValue("@CreatedAt", DateTime.UtcNow);

                    var reviewId = (int)await insertCmd.ExecuteScalarAsync();

                    transaction.Commit();

                    return Ok(new
                    {
                        message = "Review submitted successfully",
                        reviewId = reviewId,
                        propertyId = request.PropertyId,
                        rating = request.Rating,
                        comment = request.Comment
                    });
                }
                catch
                {
                    transaction.Rollback();
                    throw;
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error creating review: {ex.Message}");
                return StatusCode(500, new { message = "An error occurred while submitting the review", error = ex.Message });
            }
        }

        [HttpPost("from-booking")]
        public async Task<IActionResult> CreateReviewFromBooking([FromBody] CreateBookingReviewRequest request)
        {
            try
            {
                if (!ModelState.IsValid)
                {
                    return BadRequest(new { message = "Invalid review data", errors = ModelState });
                }

                using var connection = new SqlConnection(_connectionString);
                await connection.OpenAsync();
                using var transaction = connection.BeginTransaction();

                try
                {
                    // Get property ID from booking and verify booking ownership
                    var bookingQuery = @"
                        SELECT b.PropertyId, b.Status, b.PaymentStatus
                        FROM Bookings b
                        WHERE b.Id = @BookingId AND b.CustomerId = @CustomerId";

                    using var bookingCmd = new SqlCommand(bookingQuery, connection, transaction);
                    bookingCmd.Parameters.AddWithValue("@BookingId", request.BookingId);
                    bookingCmd.Parameters.AddWithValue("@CustomerId", request.CustomerId);

                    using var reader = await bookingCmd.ExecuteReaderAsync();
                    if (!reader.Read())
                    {
                        return BadRequest(new { message = "Booking not found or you don't have permission to review this booking" });
                    }

                    var propertyId = reader.GetInt32("PropertyId");
                    var bookingStatus = reader.GetString("Status");
                    var paymentStatus = reader.GetString("PaymentStatus");
                    reader.Close();

                    // Only allow reviews for confirmed bookings that are paid
                    if (bookingStatus != "confirmed" || paymentStatus != "paid")
                    {
                        return BadRequest(new { message = "Reviews can only be submitted for confirmed and fully paid bookings" });
                    }

                    // Check if customer has already reviewed this property
                    var existingReviewQuery = "SELECT COUNT(*) FROM PropertyReviews WHERE PropertyId = @PropertyId AND CustomerId = @CustomerId";
                    using var existingCmd = new SqlCommand(existingReviewQuery, connection, transaction);
                    existingCmd.Parameters.AddWithValue("@PropertyId", propertyId);
                    existingCmd.Parameters.AddWithValue("@CustomerId", request.CustomerId);
                    var hasExistingReview = (int)await existingCmd.ExecuteScalarAsync() > 0;

                    if (hasExistingReview)
                    {
                        return BadRequest(new { message = "You have already reviewed this property" });
                    }

                    // Insert the review
                    var insertQuery = @"
                        INSERT INTO PropertyReviews (PropertyId, CustomerId, Rating, Comment, CreatedAt)
                        OUTPUT INSERTED.Id
                        VALUES (@PropertyId, @CustomerId, @Rating, @Comment, @CreatedAt)";

                    using var insertCmd = new SqlCommand(insertQuery, connection, transaction);
                    insertCmd.Parameters.AddWithValue("@PropertyId", propertyId);
                    insertCmd.Parameters.AddWithValue("@CustomerId", request.CustomerId);
                    insertCmd.Parameters.AddWithValue("@Rating", request.Rating);
                    insertCmd.Parameters.AddWithValue("@Comment", request.Comment ?? (object)DBNull.Value);
                    insertCmd.Parameters.AddWithValue("@CreatedAt", DateTime.UtcNow);

                    var reviewId = (int)await insertCmd.ExecuteScalarAsync();

                    transaction.Commit();

                    return Ok(new
                    {
                        message = "Review submitted successfully",
                        reviewId = reviewId,
                        bookingId = request.BookingId,
                        propertyId = propertyId,
                        rating = request.Rating,
                        comment = request.Comment
                    });
                }
                catch
                {
                    transaction.Rollback();
                    throw;
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error creating booking review: {ex.Message}");
                return StatusCode(500, new { message = "An error occurred while submitting the review", error = ex.Message });
            }
        }

        [HttpGet("property/{propertyId}")]
        public async Task<IActionResult> GetPropertyReviews(int propertyId)
        {
            try
            {
                var reviews = new List<object>();

                using var connection = new SqlConnection(_connectionString);
                await connection.OpenAsync();

                var query = @"
                    SELECT 
                        pr.Id,
                        pr.PropertyId,
                        pr.CustomerId,
                        pr.Rating,
                        pr.Comment,
                        pr.CreatedAt,
                        u.FullName as CustomerName
                    FROM PropertyReviews pr
                    JOIN Users u ON pr.CustomerId = u.Id
                    WHERE pr.PropertyId = @PropertyId
                    ORDER BY pr.CreatedAt DESC";

                using var cmd = new SqlCommand(query, connection);
                cmd.Parameters.AddWithValue("@PropertyId", propertyId);

                using var reader = await cmd.ExecuteReaderAsync();
                while (reader.Read())
                {
                    reviews.Add(new
                    {
                        id = reader.GetInt32("Id"),
                        propertyId = reader.GetInt32("PropertyId"),
                        customerId = reader.GetInt32("CustomerId"),
                        customerName = reader.GetString("CustomerName"),
                        rating = reader.GetInt32("Rating"),
                        comment = reader.IsDBNull("Comment") ? null : reader.GetString("Comment"),
                        createdAt = reader.GetDateTime("CreatedAt").ToString("yyyy-MM-dd HH:mm:ss")
                    });
                }

                return Ok(reviews);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error fetching property reviews: {ex.Message}");
                return StatusCode(500, new { message = "An error occurred while fetching reviews", error = ex.Message });
            }
        }

        [HttpGet("customer/{customerId}")]
        public async Task<IActionResult> GetCustomerReviews(int customerId)
        {
            try
            {
                var reviews = new List<object>();

                using var connection = new SqlConnection(_connectionString);
                await connection.OpenAsync();

                var query = @"
                    SELECT 
                        pr.Id,
                        pr.PropertyId,
                        pr.CustomerId,
                        pr.Rating,
                        pr.Comment,
                        pr.CreatedAt,
                        p.Name as PropertyName,
                        p.Location
                    FROM PropertyReviews pr
                    JOIN Properties p ON pr.PropertyId = p.Id
                    WHERE pr.CustomerId = @CustomerId
                    ORDER BY pr.CreatedAt DESC";

                using var cmd = new SqlCommand(query, connection);
                cmd.Parameters.AddWithValue("@CustomerId", customerId);

                using var reader = await cmd.ExecuteReaderAsync();
                while (reader.Read())
                {
                    reviews.Add(new
                    {
                        id = reader.GetInt32("Id"),
                        propertyId = reader.GetInt32("PropertyId"),
                        propertyName = reader.GetString("PropertyName"),
                        location = reader.GetString("Location"),
                        rating = reader.GetInt32("Rating"),
                        comment = reader.IsDBNull("Comment") ? null : reader.GetString("Comment"),
                        createdAt = reader.GetDateTime("CreatedAt").ToString("yyyy-MM-dd HH:mm:ss")
                    });
                }

                return Ok(reviews);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error fetching customer reviews: {ex.Message}");
                return StatusCode(500, new { message = "An error occurred while fetching customer reviews", error = ex.Message });
            }
        }

        [HttpGet("property/{propertyId}/stats")]
        public async Task<IActionResult> GetPropertyReviewStats(int propertyId)
        {
            try
            {
                using var connection = new SqlConnection(_connectionString);
                await connection.OpenAsync();

                var query = @"
                    SELECT 
                        COUNT(*) as TotalReviews,
                        AVG(CAST(Rating as FLOAT)) as AverageRating,
                        SUM(CASE WHEN Rating = 5 THEN 1 ELSE 0 END) as FiveStarCount,
                        SUM(CASE WHEN Rating = 4 THEN 1 ELSE 0 END) as FourStarCount,
                        SUM(CASE WHEN Rating = 3 THEN 1 ELSE 0 END) as ThreeStarCount,
                        SUM(CASE WHEN Rating = 2 THEN 1 ELSE 0 END) as TwoStarCount,
                        SUM(CASE WHEN Rating = 1 THEN 1 ELSE 0 END) as OneStarCount
                    FROM PropertyReviews
                    WHERE PropertyId = @PropertyId";

                using var cmd = new SqlCommand(query, connection);
                cmd.Parameters.AddWithValue("@PropertyId", propertyId);

                using var reader = await cmd.ExecuteReaderAsync();
                if (reader.Read())
                {
                    var totalReviews = reader.GetInt32("TotalReviews");
                    var averageRating = totalReviews > 0 ? Math.Round(reader.GetDouble("AverageRating"), 2) : 0;

                    var stats = new
                    {
                        totalReviews = totalReviews,
                        averageRating = averageRating,
                        ratingDistribution = new
                        {
                            fiveStar = reader.GetInt32("FiveStarCount"),
                            fourStar = reader.GetInt32("FourStarCount"),
                            threeStar = reader.GetInt32("ThreeStarCount"),
                            twoStar = reader.GetInt32("TwoStarCount"),
                            oneStar = reader.GetInt32("OneStarCount")
                        }
                    };

                    return Ok(stats);
                }

                return Ok(new
                {
                    totalReviews = 0,
                    averageRating = 0.0,
                    ratingDistribution = new
                    {
                        fiveStar = 0,
                        fourStar = 0,
                        threeStar = 0,
                        twoStar = 0,
                        oneStar = 0
                    }
                });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error fetching property review stats: {ex.Message}");
                return StatusCode(500, new { message = "An error occurred while fetching review statistics", error = ex.Message });
            }
        }

        [HttpDelete("{reviewId}")]
        public async Task<IActionResult> DeleteReview(int reviewId, [FromQuery] int customerId)
        {
            try
            {
                using var connection = new SqlConnection(_connectionString);
                await connection.OpenAsync();

                // Verify the review belongs to the customer
                var deleteQuery = "DELETE FROM PropertyReviews WHERE Id = @ReviewId AND CustomerId = @CustomerId";
                using var cmd = new SqlCommand(deleteQuery, connection);
                cmd.Parameters.AddWithValue("@ReviewId", reviewId);
                cmd.Parameters.AddWithValue("@CustomerId", customerId);

                var rowsAffected = await cmd.ExecuteNonQueryAsync();
                if (rowsAffected == 0)
                {
                    return NotFound(new { message = "Review not found or you don't have permission to delete it" });
                }

                return Ok(new { message = "Review deleted successfully" });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error deleting review: {ex.Message}");
                return StatusCode(500, new { message = "An error occurred while deleting the review", error = ex.Message });
            }
        }

        [HttpGet("host/{hostId}")]
        public async Task<IActionResult> GetHostReviews(int hostId)
        {
            try
            {
                var reviews = new List<object>();

                using var connection = new SqlConnection(_connectionString);
                await connection.OpenAsync();

                var query = @"
                    SELECT 
                        pr.Id,
                        pr.PropertyId,
                        pr.CustomerId,
                        pr.Rating,
                        pr.Comment,
                        pr.CreatedAt,
                        u.FullName as CustomerName,
                        u.Email as CustomerEmail,
                        p.Name as PropertyName,
                        p.Location as PropertyLocation
                    FROM PropertyReviews pr
                    INNER JOIN Properties p ON pr.PropertyId = p.Id
                    INNER JOIN Users u ON pr.CustomerId = u.Id
                    WHERE p.HostId = @HostId
                    ORDER BY pr.CreatedAt DESC";

                using var cmd = new SqlCommand(query, connection);
                cmd.Parameters.AddWithValue("@HostId", hostId);

                using var reader = await cmd.ExecuteReaderAsync();
                while (reader.Read())
                {
                    reviews.Add(new
                    {
                        id = reader.GetInt32("Id"),
                        propertyId = reader.GetInt32("PropertyId"),
                        propertyName = reader.GetString("PropertyName"),
                        propertyLocation = reader.GetString("PropertyLocation"),
                        customerId = reader.GetInt32("CustomerId"),
                        customerName = reader.GetString("CustomerName"),
                        customerEmail = reader.GetString("CustomerEmail"),
                        rating = reader.GetInt32("Rating"),
                        comment = reader.IsDBNull("Comment") ? null : reader.GetString("Comment"),
                        createdAt = reader.GetDateTime("CreatedAt")
                    });
                }

                return Ok(reviews);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error fetching host reviews: {ex.Message}");
                return StatusCode(500, new { message = "An error occurred while fetching reviews", error = ex.Message });
            }
        }

        [HttpGet("host/{hostId}/summary")]
        public async Task<IActionResult> GetHostReviewsSummary(int hostId)
        {
            try
            {
                using var connection = new SqlConnection(_connectionString);
                await connection.OpenAsync();

                var query = @"
                    SELECT 
                        COUNT(pr.Id) as TotalReviews,
                        COALESCE(AVG(CAST(pr.Rating as FLOAT)), 0) as AverageRating,
                        SUM(CASE WHEN pr.Rating = 5 THEN 1 ELSE 0 END) as FiveStarCount,
                        SUM(CASE WHEN pr.Rating = 4 THEN 1 ELSE 0 END) as FourStarCount,
                        SUM(CASE WHEN pr.Rating = 3 THEN 1 ELSE 0 END) as ThreeStarCount,
                        SUM(CASE WHEN pr.Rating = 2 THEN 1 ELSE 0 END) as TwoStarCount,
                        SUM(CASE WHEN pr.Rating = 1 THEN 1 ELSE 0 END) as OneStarCount,
                        COUNT(DISTINCT p.Id) as TotalPropertiesWithReviews
                    FROM PropertyReviews pr
                    INNER JOIN Properties p ON pr.PropertyId = p.Id
                    WHERE p.HostId = @HostId";

                using var cmd = new SqlCommand(query, connection);
                cmd.Parameters.AddWithValue("@HostId", hostId);

                using var reader = await cmd.ExecuteReaderAsync();
                if (reader.Read())
                {
                    var totalReviews = reader.GetInt32("TotalReviews");
                    var averageRating = totalReviews > 0 ? Math.Round(reader.GetDouble("AverageRating"), 2) : 0;

                    var summary = new
                    {
                        totalReviews = totalReviews,
                        averageRating = averageRating,
                        totalPropertiesWithReviews = reader.GetInt32("TotalPropertiesWithReviews"),
                        ratingDistribution = new
                        {
                            fiveStar = reader.GetInt32("FiveStarCount"),
                            fourStar = reader.GetInt32("FourStarCount"),
                            threeStar = reader.GetInt32("ThreeStarCount"),
                            twoStar = reader.GetInt32("TwoStarCount"),
                            oneStar = reader.GetInt32("OneStarCount")
                        }
                    };

                    return Ok(summary);
                }

                return Ok(new
                {
                    totalReviews = 0,
                    averageRating = 0.0,
                    totalPropertiesWithReviews = 0,
                    ratingDistribution = new
                    {
                        fiveStar = 0,
                        fourStar = 0,
                        threeStar = 0,
                        twoStar = 0,
                        oneStar = 0
                    }
                });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error fetching host review summary: {ex.Message}");
                return StatusCode(500, new { message = "An error occurred while fetching review summary", error = ex.Message });
            }
        }
    }
}
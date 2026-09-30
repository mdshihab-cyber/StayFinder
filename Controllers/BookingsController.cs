using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using StayFinder_Web_API.Models;
using System.Data;

namespace StayFinder_Web_API.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class BookingsController : ControllerBase
    {
        private readonly string _connectionString = "Server=DESKTOP-7VNIMVI\\SQLEXPRESS;Database=StayFinderWebApiDB;Trusted_Connection=True;Encrypt=False;";

        [HttpPost("create")]
        public async Task<IActionResult> CreateBooking([FromBody] BookingRequest request)
        {
            try
            {
                // Validate the request
                if (!ModelState.IsValid)
                {
                    return BadRequest(new { message = "Invalid booking data", errors = ModelState });
                }

                // Validate dates
                if (request.BookingFrom >= request.BookingTo)
                {
                    return BadRequest(new { message = "Check-out date must be after check-in date" });
                }

                if (request.BookingFrom < DateTime.Now.Date)
                {
                    return BadRequest(new { message = "Check-in date cannot be in the past" });
                }

                // Get property details and calculate total price
                decimal propertyPrice = 0;
                string propertyName = "";
                bool propertyExists = false;

                using (var connection = new SqlConnection(_connectionString))
                {
                    await connection.OpenAsync();

                    // Check if property exists and get price
                    var propertyQuery = "SELECT PricePerDay, Name, Status FROM Properties WHERE Id = @PropertyId";
                    using (var cmd = new SqlCommand(propertyQuery, connection))
                    {
                        cmd.Parameters.AddWithValue("@PropertyId", request.PropertyId);
                        
                        using (var reader = await cmd.ExecuteReaderAsync())
                        {
                            if (reader.Read())
                            {
                                propertyExists = true;
                                propertyPrice = reader.GetDecimal("PricePerDay");
                                propertyName = reader.GetString("Name");
                                string status = reader.GetString("Status");

                                if (status.ToLower() != "active")
                                {
                                    return BadRequest(new { message = "Property is not available for booking" });
                                }
                            }
                        }
                    }

                    if (!propertyExists)
                    {
                        return NotFound(new { message = "Property not found" });
                    }

                    // Check if customer exists
                    var customerQuery = "SELECT Id FROM Customers WHERE Id = @CustomerId";
                    using (var cmd = new SqlCommand(customerQuery, connection))
                    {
                        cmd.Parameters.AddWithValue("@CustomerId", request.CustomerId);
                        var customerExists = await cmd.ExecuteScalarAsync();
                        
                        if (customerExists == null)
                        {
                            return BadRequest(new { message = "Customer not found" });
                        }
                    }

                    // Check for conflicting bookings
                    var conflictQuery = @"
                        SELECT COUNT(*) FROM Bookings 
                        WHERE PropertyId = @PropertyId 
                        AND Status IN ('confirmed', 'pending')
                        AND (
                            (BookingFrom <= @BookingFrom AND BookingTo > @BookingFrom) OR
                            (BookingFrom < @BookingTo AND BookingTo >= @BookingTo) OR
                            (BookingFrom >= @BookingFrom AND BookingTo <= @BookingTo)
                        )";
                    
                    using (var cmd = new SqlCommand(conflictQuery, connection))
                    {
                        cmd.Parameters.AddWithValue("@PropertyId", request.PropertyId);
                        cmd.Parameters.AddWithValue("@BookingFrom", request.BookingFrom);
                        cmd.Parameters.AddWithValue("@BookingTo", request.BookingTo);
                        
                        var conflictCount = (int)await cmd.ExecuteScalarAsync();
                        if (conflictCount > 0)
                        {
                            return BadRequest(new { message = "Property is not available for the selected dates" });
                        }
                    }
                }

                // Calculate total price
                int numberOfDays = (int)(request.BookingTo - request.BookingFrom).TotalDays;
                decimal totalPrice = propertyPrice * numberOfDays * request.NumberOfGuests;

                // Create the booking
                int bookingId = 0;
                using (var connection = new SqlConnection(_connectionString))
                {
                    await connection.OpenAsync();

                    var insertQuery = @"
                        INSERT INTO Bookings (PropertyId, CustomerId, BookingFrom, BookingTo, NumberOfGuests, TotalPrice, Status, PaymentStatus, CreatedAt)
                        OUTPUT INSERTED.Id
                        VALUES (@PropertyId, @CustomerId, @BookingFrom, @BookingTo, @NumberOfGuests, @TotalPrice, @Status, @PaymentStatus, @CreatedAt)";

                    using (var cmd = new SqlCommand(insertQuery, connection))
                    {
                        cmd.Parameters.AddWithValue("@PropertyId", request.PropertyId);
                        cmd.Parameters.AddWithValue("@CustomerId", request.CustomerId);
                        cmd.Parameters.AddWithValue("@BookingFrom", request.BookingFrom);
                        cmd.Parameters.AddWithValue("@BookingTo", request.BookingTo);
                        cmd.Parameters.AddWithValue("@NumberOfGuests", request.NumberOfGuests);
                        cmd.Parameters.AddWithValue("@TotalPrice", totalPrice);
                        cmd.Parameters.AddWithValue("@Status", "confirmed");
                        cmd.Parameters.AddWithValue("@PaymentStatus", "unpaid");
                        cmd.Parameters.AddWithValue("@CreatedAt", DateTime.UtcNow);

                        bookingId = (int)await cmd.ExecuteScalarAsync();
                    }
                }

                // Return success response
                var response = new
                {
                    message = "Booking created successfully!",
                    bookingId = bookingId,
                    propertyName = propertyName,
                    totalPrice = totalPrice,
                    numberOfDays = numberOfDays,
                    checkIn = request.BookingFrom.ToString("yyyy-MM-dd"),
                    checkOut = request.BookingTo.ToString("yyyy-MM-dd"),
                    guests = request.NumberOfGuests,
                    status = "confirmed",
                    paymentStatus = "unpaid"
                };

                return Ok(response);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error creating booking: {ex.Message}");
                return StatusCode(500, new { message = "An error occurred while creating the booking", error = ex.Message });
            }
        }

        [HttpGet("customer/{customerId}")]
        public async Task<IActionResult> GetCustomerBookings(int customerId)
        {
            try
            {
                var bookings = new List<object>();

                using (var connection = new SqlConnection(_connectionString))
                {
                    await connection.OpenAsync();

                    var query = @"
                        SELECT b.*, p.Name as PropertyName, p.Location, p.ImageUrl
                        FROM Bookings b
                        INNER JOIN Properties p ON b.PropertyId = p.Id
                        WHERE b.CustomerId = @CustomerId
                        ORDER BY b.CreatedAt DESC";

                    using (var cmd = new SqlCommand(query, connection))
                    {
                        cmd.Parameters.AddWithValue("@CustomerId", customerId);

                        using (var reader = await cmd.ExecuteReaderAsync())
                        {
                            while (reader.Read())
                            {
                                bookings.Add(new
                                {
                                    id = reader.GetInt32("Id"),
                                    propertyId = reader.GetInt32("PropertyId"),
                                    propertyName = reader.GetString("PropertyName"),
                                    location = reader.GetString("Location"),
                                    imageUrl = reader.IsDBNull("ImageUrl") ? null : reader.GetString("ImageUrl"),
                                    bookingFrom = reader.GetDateTime("BookingFrom").ToString("yyyy-MM-dd"),
                                    bookingTo = reader.GetDateTime("BookingTo").ToString("yyyy-MM-dd"),
                                    numberOfGuests = reader.GetInt32("NumberOfGuests"),
                                    totalPrice = reader.GetDecimal("TotalPrice"),
                                    status = reader.GetString("Status"),
                                    paymentStatus = reader.GetString("PaymentStatus"),
                                    createdAt = reader.GetDateTime("CreatedAt").ToString("yyyy-MM-dd HH:mm:ss")
                                });
                            }
                        }
                    }
                }

                return Ok(bookings);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error fetching customer bookings: {ex.Message}");
                return StatusCode(500, new { message = "An error occurred while fetching bookings", error = ex.Message });
            }
        }

        [HttpDelete("{bookingId}")]
        public async Task<IActionResult> CancelBooking(int bookingId, [FromQuery] int customerId)
        {
            try
            {
                using (var connection = new SqlConnection(_connectionString))
                {
                    await connection.OpenAsync();

                    // Check if booking exists and belongs to customer
                    var checkQuery = "SELECT Id FROM Bookings WHERE Id = @BookingId AND CustomerId = @CustomerId";
                    using (var cmd = new SqlCommand(checkQuery, connection))
                    {
                        cmd.Parameters.AddWithValue("@BookingId", bookingId);
                        cmd.Parameters.AddWithValue("@CustomerId", customerId);

                        var exists = await cmd.ExecuteScalarAsync();
                        if (exists == null)
                        {
                            return NotFound(new { message = "Booking not found" });
                        }
                    }

                    // Delete the booking (no date/status restriction)
                    var deleteQuery = "DELETE FROM Bookings WHERE Id = @BookingId AND CustomerId = @CustomerId";
                    using (var cmd = new SqlCommand(deleteQuery, connection))
                    {
                        cmd.Parameters.AddWithValue("@BookingId", bookingId);
                        cmd.Parameters.AddWithValue("@CustomerId", customerId);

                        int rowsAffected = await cmd.ExecuteNonQueryAsync();
                        if (rowsAffected == 0)
                        {
                            return NotFound(new { message = "Booking not found" });
                        }
                    }
                }

                return Ok(new { message = "Booking deleted successfully" });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error deleting booking: {ex.Message}");
                return StatusCode(500, new { message = "An error occurred while deleting the booking", error = ex.Message });
            }
        }

        [HttpPut("{bookingId}/dates")]
        public async Task<IActionResult> UpdateBookingDates(int bookingId, [FromBody] UpdateBookingDatesRequest request)
        {
            try
            {
                // Validate the request
                if (!ModelState.IsValid)
                {
                    return BadRequest(new { message = "Invalid booking data", errors = ModelState });
                }

                // Validate dates
                if (request.BookingFrom >= request.BookingTo)
                {
                    return BadRequest(new { message = "Check-out date must be after check-in date" });
                }

                if (request.BookingFrom < DateTime.Now.Date)
                {
                    return BadRequest(new { message = "Check-in date cannot be in the past" });
                }

                decimal propertyPrice = 0;
                int numberOfGuests = 0;

                using (var connection = new SqlConnection(_connectionString))
                {
                    await connection.OpenAsync();
                    using (var transaction = connection.BeginTransaction())
                    {
                        try
                        {
                            // Get current booking details
                            int propertyId = 0;
                            int customerId = 0;
                            string currentStatus = "";

                            var getBookingQuery = @"
                                SELECT b.PropertyId, b.CustomerId, b.NumberOfGuests, b.Status, p.PricePerDay, p.Status as PropertyStatus
                                FROM Bookings b
                                INNER JOIN Properties p ON b.PropertyId = p.Id
                                WHERE b.Id = @BookingId";

                            using (var cmd = new SqlCommand(getBookingQuery, connection, transaction))
                            {
                                cmd.Parameters.AddWithValue("@BookingId", bookingId);

                                using (var reader = await cmd.ExecuteReaderAsync())
                                {
                                    if (!reader.Read())
                                    {
                                        return NotFound(new { message = "Booking not found" });
                                    }

                                    propertyId = reader.GetInt32("PropertyId");
                                    customerId = reader.GetInt32("CustomerId");
                                    numberOfGuests = reader.GetInt32("NumberOfGuests");
                                    currentStatus = reader.GetString("Status");
                                    propertyPrice = reader.GetDecimal("PricePerDay");
                                    string propertyStatus = reader.GetString("PropertyStatus");

                                    if (currentStatus.ToLower() == "cancelled")
                                    {
                                        return BadRequest(new { message = "Cannot modify cancelled booking" });
                                    }

                                    if (propertyStatus.ToLower() != "active")
                                    {
                                        return BadRequest(new { message = "Property is not available" });
                                    }

                                    // Verify customer ID matches if provided
                                    if (request.CustomerId != customerId)
                                    {
                                        return BadRequest(new { message = "Not authorized to modify this booking" });
                                    }
                                }
                            }

                            // Check for conflicting bookings (excluding current booking)
                            var conflictQuery = @"
                                SELECT COUNT(*) FROM Bookings 
                                WHERE PropertyId = @PropertyId 
                                AND Id != @BookingId
                                AND Status IN ('confirmed', 'pending')
                                AND (
                                    (BookingFrom <= @BookingFrom AND BookingTo > @BookingFrom) OR
                                    (BookingFrom < @BookingTo AND BookingTo >= @BookingTo) OR
                                    (BookingFrom >= @BookingFrom AND BookingTo <= @BookingTo)
                                )";

                            using (var cmd = new SqlCommand(conflictQuery, connection, transaction))
                            {
                                cmd.Parameters.AddWithValue("@PropertyId", propertyId);
                                cmd.Parameters.AddWithValue("@BookingId", bookingId);
                                cmd.Parameters.AddWithValue("@BookingFrom", request.BookingFrom);
                                cmd.Parameters.AddWithValue("@BookingTo", request.BookingTo);

                                var conflictCount = (int)await cmd.ExecuteScalarAsync();
                                if (conflictCount > 0)
                                {
                                    return BadRequest(new { message = "Property is not available for the selected dates" });
                                }
                            }

                            // Calculate new total price
                            int newNumberOfDays = (int)(request.BookingTo - request.BookingFrom).TotalDays;
                            decimal newTotalPrice = propertyPrice * newNumberOfDays * numberOfGuests;

                            // Update the booking
                            var updateQuery = @"
                                UPDATE Bookings 
                                SET BookingFrom = @BookingFrom, BookingTo = @BookingTo, TotalPrice = @TotalPrice, UpdatedAt = @UpdatedAt
                                WHERE Id = @BookingId";

                            using (var cmd = new SqlCommand(updateQuery, connection, transaction))
                            {
                                cmd.Parameters.AddWithValue("@BookingId", bookingId);
                                cmd.Parameters.AddWithValue("@BookingFrom", request.BookingFrom);
                                cmd.Parameters.AddWithValue("@BookingTo", request.BookingTo);
                                cmd.Parameters.AddWithValue("@TotalPrice", newTotalPrice);
                                cmd.Parameters.AddWithValue("@UpdatedAt", DateTime.UtcNow);

                                int rowsAffected = await cmd.ExecuteNonQueryAsync();
                                if (rowsAffected == 0)
                                {
                                    return NotFound(new { message = "Booking not found" });
                                }
                            }

                            // Recalculate payments if they exist for this booking
                            var paymentQuery = @"
                                SELECT COUNT(*) FROM Payments WHERE BookingId = @BookingId";
                            
                            using (var paymentCmd = new SqlCommand(paymentQuery, connection, transaction))
                            {
                                paymentCmd.Parameters.AddWithValue("@BookingId", bookingId);
                                var paymentCount = (int)await paymentCmd.ExecuteScalarAsync();
                                
                                if (paymentCount > 0)
                                {
                                    // Get current payment information
                                    var totalPaidQuery = @"
                                        SELECT COALESCE(SUM(AmountPaid), 0) as TotalPaid
                                        FROM Payments 
                                        WHERE BookingId = @BookingId AND Status = 'completed'";
                                    
                                    using (var totalPaidCmd = new SqlCommand(totalPaidQuery, connection, transaction))
                                    {
                                        totalPaidCmd.Parameters.AddWithValue("@BookingId", bookingId);
                                        var totalPaid = (decimal)await totalPaidCmd.ExecuteScalarAsync();

                                        // Update all payment records with new TotalAmount
                                        var updatePaymentsCmd = new SqlCommand(@"
                                            UPDATE Payments 
                                            SET TotalAmount = @NewTotalAmount
                                            WHERE BookingId = @BookingId", connection, transaction);
                                        
                                        updatePaymentsCmd.Parameters.AddWithValue("@BookingId", bookingId);
                                        updatePaymentsCmd.Parameters.AddWithValue("@NewTotalAmount", newTotalPrice);
                                        await updatePaymentsCmd.ExecuteNonQueryAsync();

                                        // Update booking payment status if needed
                                        var isFullyPaid = Math.Abs(totalPaid - newTotalPrice) < 0.01m;
                                        var newPaymentStatus = totalPaid == 0 ? "unpaid" : 
                                                              isFullyPaid ? "paid" : "initial";

                                        var updateBookingPaymentCmd = new SqlCommand(@"
                                            UPDATE Bookings 
                                            SET PaymentStatus = @PaymentStatus
                                            WHERE Id = @BookingId", connection, transaction);
                                        updateBookingPaymentCmd.Parameters.AddWithValue("@PaymentStatus", newPaymentStatus);
                                        updateBookingPaymentCmd.Parameters.AddWithValue("@BookingId", bookingId);
                                        await updateBookingPaymentCmd.ExecuteNonQueryAsync();
                                    }
                                }
                            }

                            transaction.Commit();

                            // Return success response
                            var response = new
                            {
                                message = "Booking dates updated successfully!",
                                bookingId = bookingId,
                                newCheckIn = request.BookingFrom.ToString("yyyy-MM-dd"),
                                newCheckOut = request.BookingTo.ToString("yyyy-MM-dd"),
                                numberOfDays = newNumberOfDays,
                                newTotalPrice = newTotalPrice
                            };

                            return Ok(response);
                        }
                        catch
                        {
                            transaction.Rollback();
                            throw;
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error updating booking dates: {ex.Message}");
                return StatusCode(500, new { message = "An error occurred while updating the booking", error = ex.Message });
            }
        }

        [HttpGet("{bookingId}")]
        public async Task<IActionResult> GetBooking(int bookingId)
        {
            try
            {
                using (var connection = new SqlConnection(_connectionString))
                {
                    await connection.OpenAsync();

                    var query = @"
                        SELECT b.*, p.Name as PropertyName, p.Location, p.ImageUrl, p.PricePerDay
                        FROM Bookings b
                        INNER JOIN Properties p ON b.PropertyId = p.Id
                        WHERE b.Id = @BookingId";

                    using (var cmd = new SqlCommand(query, connection))
                    {
                        cmd.Parameters.AddWithValue("@BookingId", bookingId);

                        using (var reader = await cmd.ExecuteReaderAsync())
                        {
                            if (reader.Read())
                            {
                                var booking = new
                                {
                                    id = reader.GetInt32("Id"),
                                    propertyId = reader.GetInt32("PropertyId"),
                                    customerId = reader.GetInt32("CustomerId"),
                                    propertyName = reader.GetString("PropertyName"),
                                    location = reader.GetString("Location"),
                                    imageUrl = reader.IsDBNull("ImageUrl") ? null : reader.GetString("ImageUrl"),
                                    bookingFrom = reader.GetDateTime("BookingFrom"),
                                    bookingTo = reader.GetDateTime("BookingTo"),
                                    numberOfGuests = reader.GetInt32("NumberOfGuests"),
                                    totalPrice = reader.GetDecimal("TotalPrice"),
                                    pricePerNight = reader.GetDecimal("PricePerDay"),
                                    status = reader.GetString("Status"),
                                    paymentStatus = reader.GetString("PaymentStatus"),
                                    createdAt = reader.GetDateTime("CreatedAt")
                                };
                                return Ok(booking);
                            }
                            else
                            {
                                return NotFound(new { message = "Booking not found" });
                            }
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error fetching booking: {ex.Message}");
                return StatusCode(500, new { message = "An error occurred while fetching the booking", error = ex.Message });
            }
        }
    }
}
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using StayFinder_Web_API.Models;
using System.Data;
using System.Threading.Tasks;
using System;

namespace StayFinder_Web_API.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class PaymentsController : ControllerBase
    {
        private readonly string _connectionString = "Server=DESKTOP-7VNIMVI\\SQLEXPRESS;Database=StayFinderWebApiDB;Trusted_Connection=True;Encrypt=False;";

        [HttpPost("confirm")]
        public async Task<IActionResult> ConfirmPayment([FromBody] CreatePaymentRequest request)
        {
            using var connection = new SqlConnection(_connectionString);
            await connection.OpenAsync();
            using var transaction = connection.BeginTransaction();
            
            try
            {
                // Get booking details to validate and calculate amounts
                var bookingQuery = @"
                    SELECT PropertyId, BookingFrom, BookingTo, TotalPrice, Status, PaymentStatus 
                    FROM Bookings 
                    WHERE Id = @BookingId AND CustomerId = @CustomerId";
                
                var bookingCmd = new SqlCommand(bookingQuery, connection, transaction);
                bookingCmd.Parameters.AddWithValue("@BookingId", request.BookingId);
                bookingCmd.Parameters.AddWithValue("@CustomerId", request.CustomerId);
                
                using var reader = await bookingCmd.ExecuteReaderAsync();
                if (!reader.Read())
                {
                    return BadRequest(new { error = "Payment failed", reason = "Booking not found or unauthorized" });
                }
                
                var propertyId = reader.GetInt32("PropertyId");
                var bookingFrom = reader.GetDateTime("BookingFrom");
                var bookingTo = reader.GetDateTime("BookingTo");
                var totalPrice = reader.GetDecimal("TotalPrice");
                var currentBookingStatus = reader.GetString("Status");
                var currentPaymentStatus = reader.GetString("PaymentStatus");
                reader.Close();

                // Check if this is initial payment (10% advance) - fix status values
                var isInitialPayment = currentPaymentStatus == "unpaid";
                
                if (!isInitialPayment && currentPaymentStatus != "initial")
                {
                    return BadRequest(new { error = "Payment failed", reason = "Invalid payment status for this booking" });
                }

                // Calculate payment amounts
                decimal initialAmount = totalPrice * 0.10m; // 10% advance
                decimal amountToPay = isInitialPayment ? initialAmount : request.Amount;
                string paymentType = isInitialPayment ? "Initial Booking" : "Remaining Payment";

                // For initial payment, check if payment already exists
                if (isInitialPayment)
                {
                    var existingPaymentQuery = "SELECT COUNT(*) FROM Payments WHERE BookingId = @BookingId";
                    var existingCmd = new SqlCommand(existingPaymentQuery, connection, transaction);
                    existingCmd.Parameters.AddWithValue("@BookingId", request.BookingId);
                    var existingCount = (int)await existingCmd.ExecuteScalarAsync();
                    
                    if (existingCount > 0)
                    {
                        return BadRequest(new { error = "Payment failed", reason = "Payment already processed for this booking" });
                    }
                }

                // Insert payment record with new schema
                var insertPaymentCmd = new SqlCommand(@"
                    INSERT INTO Payments (BookingId, CustomerId, TotalAmount, AmountPaid, PaymentMethod, PaymentType, Status) 
                    VALUES (@BookingId, @CustomerId, @TotalAmount, @AmountPaid, @PaymentMethod, @PaymentType, 'completed');
                    SELECT SCOPE_IDENTITY();", connection, transaction);
                
                insertPaymentCmd.Parameters.AddWithValue("@BookingId", request.BookingId);
                insertPaymentCmd.Parameters.AddWithValue("@CustomerId", request.CustomerId);
                insertPaymentCmd.Parameters.AddWithValue("@TotalAmount", totalPrice);
                insertPaymentCmd.Parameters.AddWithValue("@AmountPaid", amountToPay);
                insertPaymentCmd.Parameters.AddWithValue("@PaymentMethod", request.PaymentMethod);
                insertPaymentCmd.Parameters.AddWithValue("@PaymentType", paymentType);
                
                var paymentId = Convert.ToInt32(await insertPaymentCmd.ExecuteScalarAsync());

                // Update booking status based on payment type - fix status values
                string newPaymentStatus = isInitialPayment ? "initial" : "paid";
                string newBookingStatus = isInitialPayment ? "confirmed" : "confirmed";
                
                var updateBookingCmd = new SqlCommand(@"
                    UPDATE Bookings 
                    SET PaymentStatus = @PaymentStatus, Status = @Status, UpdatedAt = GETUTCDATE()
                    WHERE Id = @BookingId", connection, transaction);
                updateBookingCmd.Parameters.AddWithValue("@PaymentStatus", newPaymentStatus);
                updateBookingCmd.Parameters.AddWithValue("@Status", newBookingStatus);
                updateBookingCmd.Parameters.AddWithValue("@BookingId", request.BookingId);
                await updateBookingCmd.ExecuteNonQueryAsync();

                // Update property booking status and dates (only for initial payment)
                if (isInitialPayment)
                {
                    var updatePropertyCmd = new SqlCommand(@"
                        UPDATE Properties 
                        SET BookingStatus = 'booked', BookingFrom = @BookingFrom, BookingTo = @BookingTo, UpdatedAt = GETUTCDATE()
                        WHERE Id = @PropertyId", connection, transaction);
                    updatePropertyCmd.Parameters.AddWithValue("@PropertyId", propertyId);
                    updatePropertyCmd.Parameters.AddWithValue("@BookingFrom", bookingFrom);
                    updatePropertyCmd.Parameters.AddWithValue("@BookingTo", bookingTo);
                    await updatePropertyCmd.ExecuteNonQueryAsync();
                }

                // Commit transaction
                transaction.Commit();

                return Ok(new { 
                    message = "Payment confirmed", 
                    paymentId = paymentId, 
                    bookingId = request.BookingId, 
                    status = "completed",
                    paymentType = paymentType,
                    amountPaid = amountToPay
                });
            }
            catch (Exception ex)
            {
                transaction.Rollback();
                return StatusCode(500, new { 
                    error = "Payment failed", 
                    reason = ex.Message 
                });
            }
        }

        [HttpPost("remaining")]
        public async Task<IActionResult> PayRemaining([FromBody] RemainingPaymentRequest request)
        {
            using var connection = new SqlConnection(_connectionString);
            await connection.OpenAsync();
            using var transaction = connection.BeginTransaction();
            
            try
            {
                // Get booking and payment details
                var bookingQuery = @"
                    SELECT b.TotalPrice, b.PaymentStatus, b.Status,
                           COALESCE(SUM(p.AmountPaid), 0) as TotalPaid
                    FROM Bookings b
                    LEFT JOIN Payments p ON b.Id = p.BookingId AND p.Status = 'completed'
                    WHERE b.Id = @BookingId AND b.CustomerId = @CustomerId
                    GROUP BY b.TotalPrice, b.PaymentStatus, b.Status";
                
                var bookingCmd = new SqlCommand(bookingQuery, connection, transaction);
                bookingCmd.Parameters.AddWithValue("@BookingId", request.BookingId);
                bookingCmd.Parameters.AddWithValue("@CustomerId", request.CustomerId);
                
                using var reader = await bookingCmd.ExecuteReaderAsync();
                if (!reader.Read())
                {
                    return BadRequest(new { error = "Payment failed", reason = "Booking not found or unauthorized" });
                }
                
                var totalPrice = reader.GetDecimal("TotalPrice");
                var totalPaid = reader.GetDecimal("TotalPaid");
                var paymentStatus = reader.GetString("PaymentStatus");
                var bookingStatus = reader.GetString("Status");
                reader.Close();

                var remainingAmount = totalPrice - totalPaid;

                // Validate payment status and amount - fix status values
                if (paymentStatus == "paid")
                {
                    return BadRequest(new { error = "Payment failed", reason = "Booking is already fully paid" });
                }

                if (paymentStatus != "initial")
                {
                    return BadRequest(new { error = "Payment failed", reason = "Initial payment must be completed first" });
                }

                if (request.Amount > remainingAmount)
                {
                    return BadRequest(new { error = "Payment failed", reason = $"Amount exceeds remaining balance of ${remainingAmount:F2}" });
                }

                // Insert remaining payment record
                var insertPaymentCmd = new SqlCommand(@"
                    INSERT INTO Payments (BookingId, CustomerId, TotalAmount, AmountPaid, PaymentMethod, PaymentType, Status) 
                    VALUES (@BookingId, @CustomerId, @TotalAmount, @AmountPaid, @PaymentMethod, 'Remaining Payment', 'completed');
                    SELECT SCOPE_IDENTITY();", connection, transaction);
                
                insertPaymentCmd.Parameters.AddWithValue("@BookingId", request.BookingId);
                insertPaymentCmd.Parameters.AddWithValue("@CustomerId", request.CustomerId);
                insertPaymentCmd.Parameters.AddWithValue("@TotalAmount", totalPrice);
                insertPaymentCmd.Parameters.AddWithValue("@AmountPaid", request.Amount);
                insertPaymentCmd.Parameters.AddWithValue("@PaymentMethod", request.PaymentMethod);
                
                var paymentId = Convert.ToInt32(await insertPaymentCmd.ExecuteScalarAsync());

                // Check if booking is now fully paid
                var newTotalPaid = totalPaid + request.Amount;
                var isFullyPaid = Math.Abs(newTotalPaid - totalPrice) < 0.01m; // Account for decimal precision

                if (isFullyPaid)
                {
                    // Update booking to fully paid status
                    var updateBookingCmd = new SqlCommand(@"
                        UPDATE Bookings 
                        SET PaymentStatus = 'paid', UpdatedAt = GETUTCDATE()
                        WHERE Id = @BookingId", connection, transaction);
                    updateBookingCmd.Parameters.AddWithValue("@BookingId", request.BookingId);
                    await updateBookingCmd.ExecuteNonQueryAsync();
                }

                transaction.Commit();

                return Ok(new { 
                    message = "Remaining payment processed successfully", 
                    paymentId = paymentId, 
                    bookingId = request.BookingId, 
                    status = "completed",
                    paymentType = "Remaining Payment",
                    amountPaid = request.Amount,
                    fullyPaid = isFullyPaid,
                    newRemainingAmount = totalPrice - newTotalPaid
                });
            }
            catch (Exception ex)
            {
                transaction.Rollback();
                return StatusCode(500, new { 
                    error = "Payment failed", 
                    reason = ex.Message 
                });
            }
        }

        [HttpGet("booking/{bookingId}")]
        public async Task<IActionResult> GetPaymentsByBooking(int bookingId)
        {
            var payments = new List<object>();
            using (var connection = new SqlConnection(_connectionString))
            {
                await connection.OpenAsync();
                var query = @"
                    SELECT 
                        Id, BookingId, CustomerId, TotalAmount, AmountPaid, RemainingAmount,
                        PaymentMethod, PaymentType, PaymentDate, Status
                    FROM Payments 
                    WHERE BookingId = @BookingId
                    ORDER BY PaymentDate ASC";

                using (var command = new SqlCommand(query, connection))
                {
                    command.Parameters.AddWithValue("@BookingId", bookingId);
                    using (var reader = await command.ExecuteReaderAsync())
                    {
                        while (await reader.ReadAsync())
                        {
                            payments.Add(new
                            {
                                Id = reader.GetInt32("Id"),
                                BookingId = reader.GetInt32("BookingId"),
                                CustomerId = reader.GetInt32("CustomerId"),
                                TotalAmount = reader.GetDecimal("TotalAmount"),
                                AmountPaid = reader.GetDecimal("AmountPaid"),
                                RemainingAmount = reader.GetDecimal("RemainingAmount"),
                                PaymentMethod = reader.GetString("PaymentMethod"),
                                PaymentType = reader.GetString("PaymentType"),
                                PaymentDate = reader.GetDateTime("PaymentDate"),
                                Status = reader.GetString("Status")
                            });
                        }
                    }
                }
            }
            return Ok(payments);
        }

        [HttpGet("history/{customerId}")]
        public async Task<IActionResult> GetPaymentHistory(int customerId)
        {
            var payments = new List<object>();
            using (var connection = new SqlConnection(_connectionString))
            {
                await connection.OpenAsync();
                var query = @"
                    SELECT 
                        p.Id, p.BookingId, p.TotalAmount, p.AmountPaid, p.RemainingAmount,
                        p.PaymentMethod, p.PaymentType, p.PaymentDate, p.Status,
                        pr.Name AS PropertyName, pr.Location
                    FROM Payments p
                    JOIN Bookings b ON p.BookingId = b.Id
                    JOIN Properties pr ON b.PropertyId = pr.Id
                    WHERE p.CustomerId = @CustomerId
                    ORDER BY p.PaymentDate DESC";

                using (var command = new SqlCommand(query, connection))
                {
                    command.Parameters.AddWithValue("@CustomerId", customerId);
                    using (var reader = await command.ExecuteReaderAsync())
                    {
                        while (await reader.ReadAsync())
                        {
                            payments.Add(new
                            {
                                Id = reader.GetInt32("Id"),
                                BookingId = reader.GetInt32("BookingId"),
                                PropertyName = reader.GetString("PropertyName"),
                                Location = reader.GetString("Location"),
                                TotalAmount = reader.GetDecimal("TotalAmount"),
                                AmountPaid = reader.GetDecimal("AmountPaid"),
                                RemainingAmount = reader.GetDecimal("RemainingAmount"),
                                PaymentMethod = reader.GetString("PaymentMethod"),
                                PaymentType = reader.GetString("PaymentType"),
                                PaymentDate = reader.GetDateTime("PaymentDate"),
                                Status = reader.GetString("Status")
                            });
                        }
                    }
                }
            }
            return Ok(payments);
        }

        [HttpGet("customer/{customerId}")]
        public async Task<IActionResult> GetPaymentsByCustomer(int customerId)
        {
            // Redirect to the new history endpoint
            return await GetPaymentHistory(customerId);
        }

        [HttpPut("recalculate/{bookingId}")]
        public async Task<IActionResult> RecalculatePaymentsAfterDateUpdate(int bookingId, [FromBody] decimal newTotalAmount)
        {
            using var connection = new SqlConnection(_connectionString);
            await connection.OpenAsync();
            using var transaction = connection.BeginTransaction();
            
            try
            {
                // Get current payment information
                var paymentQuery = @"
                    SELECT COALESCE(SUM(AmountPaid), 0) as TotalPaid
                    FROM Payments 
                    WHERE BookingId = @BookingId AND Status = 'completed'";
                
                var paymentCmd = new SqlCommand(paymentQuery, connection, transaction);
                paymentCmd.Parameters.AddWithValue("@BookingId", bookingId);
                
                var totalPaid = (decimal)await paymentCmd.ExecuteScalarAsync();

                // Update all payment records with new TotalAmount (RemainingAmount will auto-calculate)
                var updatePaymentsCmd = new SqlCommand(@"
                    UPDATE Payments 
                    SET TotalAmount = @NewTotalAmount
                    WHERE BookingId = @BookingId", connection, transaction);
                
                updatePaymentsCmd.Parameters.AddWithValue("@BookingId", bookingId);
                updatePaymentsCmd.Parameters.AddWithValue("@NewTotalAmount", newTotalAmount);
                await updatePaymentsCmd.ExecuteNonQueryAsync();

                // Check if booking payment status needs updating - fix status values
                var isFullyPaid = Math.Abs(totalPaid - newTotalAmount) < 0.01m;
                var newPaymentStatus = totalPaid == 0 ? "unpaid" : 
                                      isFullyPaid ? "paid" : "initial";

                var updateBookingCmd = new SqlCommand(@"
                    UPDATE Bookings 
                    SET PaymentStatus = @PaymentStatus, UpdatedAt = GETUTCDATE()
                    WHERE Id = @BookingId", connection, transaction);
                updateBookingCmd.Parameters.AddWithValue("@PaymentStatus", newPaymentStatus);
                updateBookingCmd.Parameters.AddWithValue("@BookingId", bookingId);
                await updateBookingCmd.ExecuteNonQueryAsync();

                transaction.Commit();

                return Ok(new { 
                    message = "Payments recalculated successfully", 
                    bookingId = bookingId,
                    newTotalAmount = newTotalAmount,
                    totalPaid = totalPaid,
                    newRemainingAmount = newTotalAmount - totalPaid,
                    paymentStatus = newPaymentStatus
                });
            }
            catch (Exception ex)
            {
                transaction.Rollback();
                return StatusCode(500, new { 
                    error = "Recalculation failed", 
                    reason = ex.Message 
                });
            }
        }

        [HttpGet("host/{hostId}")]
        public async Task<IActionResult> GetHostEarnings(int hostId)
        {
            var earnings = new List<object>();
            using (var connection = new SqlConnection(_connectionString))
            {
                await connection.OpenAsync();
                var query = @"
                    SELECT 
                        p.Id, p.BookingId, p.TotalAmount, p.AmountPaid, p.PaymentMethod, 
                        p.PaymentType, p.PaymentDate, p.Status,
                        pr.Name AS PropertyName, pr.Location,
                        u.FullName AS CustomerName, u.Email AS CustomerEmail,
                        b.BookingFrom, b.BookingTo
                    FROM Payments p
                    JOIN Bookings b ON p.BookingId = b.Id
                    JOIN Properties pr ON b.PropertyId = pr.Id
                    JOIN Users u ON p.CustomerId = u.Id
                    WHERE pr.HostId = @HostId AND p.Status = 'completed'
                    ORDER BY p.PaymentDate DESC";

                using (var command = new SqlCommand(query, connection))
                {
                    command.Parameters.AddWithValue("@HostId", hostId);
                    using (var reader = await command.ExecuteReaderAsync())
                    {
                        while (await reader.ReadAsync())
                        {
                            // Calculate host earnings (assuming 10% platform commission)
                            var amountPaid = reader.GetDecimal("AmountPaid");
                            var platformCommission = amountPaid * 0.10m;
                            var hostEarning = amountPaid * 0.90m;

                            earnings.Add(new
                            {
                                Id = reader.GetInt32("Id"),
                                BookingId = reader.GetInt32("BookingId"),
                                PropertyName = reader.GetString("PropertyName"),
                                Location = reader.GetString("Location"),
                                CustomerName = reader.GetString("CustomerName"),
                                CustomerEmail = reader.GetString("CustomerEmail"),
                                BookingFrom = reader.GetDateTime("BookingFrom"),
                                BookingTo = reader.GetDateTime("BookingTo"),
                                TotalAmount = reader.GetDecimal("TotalAmount"),
                                AmountPaid = amountPaid,
                                PlatformCommission = platformCommission,
                                HostEarning = hostEarning,
                                PaymentMethod = reader.GetString("PaymentMethod"),
                                PaymentType = reader.GetString("PaymentType"),
                                PaymentDate = reader.GetDateTime("PaymentDate"),
                                Status = reader.GetString("Status")
                            });
                        }
                    }
                }
            }
            return Ok(earnings);
        }

        [HttpGet("host/{hostId}/summary")]
        public async Task<IActionResult> GetHostEarningsSummary(int hostId)
        {
            using (var connection = new SqlConnection(_connectionString))
            {
                await connection.OpenAsync();
                var query = @"
                    SELECT 
                        COUNT(*) AS TotalTransactions,
                        COALESCE(SUM(p.AmountPaid), 0) AS TotalPaymentsReceived,
                        COALESCE(SUM(p.AmountPaid * 0.10), 0) AS TotalCommission,
                        COALESCE(SUM(p.AmountPaid * 0.90), 0) AS TotalEarnings,
                        COALESCE(SUM(CASE WHEN p.PaymentDate >= DATEADD(month, -1, GETDATE()) THEN p.AmountPaid * 0.90 ELSE 0 END), 0) AS MonthlyEarnings,
                        COALESCE(AVG(p.AmountPaid * 0.90), 0) AS AverageEarningPerBooking
                    FROM Payments p
                    JOIN Bookings b ON p.BookingId = b.Id
                    JOIN Properties pr ON b.PropertyId = pr.Id
                    WHERE pr.HostId = @HostId AND p.Status = 'completed'";

                using (var command = new SqlCommand(query, connection))
                {
                    command.Parameters.AddWithValue("@HostId", hostId);
                    using (var reader = await command.ExecuteReaderAsync())
                    {
                        if (await reader.ReadAsync())
                        {
                            return Ok(new
                            {
                                TotalTransactions = reader.GetInt32("TotalTransactions"),
                                TotalPaymentsReceived = reader.GetDecimal("TotalPaymentsReceived"),
                                TotalCommission = reader.GetDecimal("TotalCommission"),
                                TotalEarnings = reader.GetDecimal("TotalEarnings"),
                                MonthlyEarnings = reader.GetDecimal("MonthlyEarnings"),
                                AverageEarningPerBooking = reader.GetDecimal("AverageEarningPerBooking")
                            });
                        }
                    }
                }
            }

            // Return empty summary if no data found
            return Ok(new
            {
                TotalTransactions = 0,
                TotalPaymentsReceived = 0.00m,
                TotalCommission = 0.00m,
                TotalEarnings = 0.00m,
                MonthlyEarnings = 0.00m,
                AverageEarningPerBooking = 0.00m
            });
        }
    }
}
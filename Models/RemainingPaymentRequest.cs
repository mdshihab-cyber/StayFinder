namespace StayFinder_Web_API.Models
{
    public class RemainingPaymentRequest
    {
        public int BookingId { get; set; }
        public int CustomerId { get; set; }
        public decimal Amount { get; set; }
        public string PaymentMethod { get; set; }
    }
}
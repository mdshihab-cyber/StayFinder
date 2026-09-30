namespace StayFinder_Web_API.Models
{
    public class Booking
    {
        public int Id { get; set; }
        public int PropertyId { get; set; }
        public int CustomerId { get; set; }
        public DateTime BookingFrom { get; set; }
        public DateTime BookingTo { get; set; }
        public int NumberOfGuests { get; set; } = 1;
        public decimal TotalPrice { get; set; }
        public string Status { get; set; } = "pending";
        public string PaymentStatus { get; set; } = "unpaid";
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
        public DateTime? UpdatedAt { get; set; }
    }
}
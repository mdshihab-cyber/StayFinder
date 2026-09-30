using System;

namespace StayFinder_Web_API.Models
{
    public class Payment
    {
        public int Id { get; set; }
        public int BookingId { get; set; }
        public int CustomerId { get; set; }
        
        public decimal TotalAmount { get; set; }
        public decimal AmountPaid { get; set; }
        public decimal RemainingAmount { get; set; }
        
        public string PaymentMethod { get; set; }
        public string PaymentType { get; set; }
        public DateTime PaymentDate { get; set; }
        public string Status { get; set; }
    }
}
using System.ComponentModel.DataAnnotations;

namespace StayFinder_Web_API.Models
{
    public class BookingRequest
    {
        [Required]
        public int PropertyId { get; set; }
        
        [Required]
        public int CustomerId { get; set; }
        
        [Required]
        public DateTime BookingFrom { get; set; }
        
        [Required]
        public DateTime BookingTo { get; set; }
        
        [Required]
        [Range(1, 20, ErrorMessage = "Number of guests must be between 1 and 20")]
        public int NumberOfGuests { get; set; } = 1;
    }
}
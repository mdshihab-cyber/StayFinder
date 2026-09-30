using System.ComponentModel.DataAnnotations;

namespace StayFinder_Web_API.Models
{
    public class CreateBookingReviewRequest
    {
        [Required]
        public int BookingId { get; set; }
        
        [Required]
        public int CustomerId { get; set; }
        
        [Required]
        [Range(1, 5, ErrorMessage = "Rating must be between 1 and 5")]
        public int Rating { get; set; }
        
        [StringLength(1000, ErrorMessage = "Comment cannot exceed 1000 characters")]
        public string? Comment { get; set; }
    }
}
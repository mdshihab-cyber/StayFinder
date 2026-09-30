using System.ComponentModel.DataAnnotations;

namespace StayFinder_Web_API.Models
{
    public class PropertyRequest
    {
        public int HostId { get; set; }
        
        [Required]
        [StringLength(100)]
        public string Name { get; set; }
        
        [Required]
        [StringLength(50)]
        public string Type { get; set; }        // Premium, Standard, Luxury
        
        [Required]
        [Range(0.01, 999999.99)]
        public decimal PricePerDay { get; set; }
        
        [StringLength(500)]
        public string? ImageUrl { get; set; }
        
        [Required]
        [StringLength(200)]
        public string Location { get; set; }
        
        [StringLength(50)]
        public string? Status { get; set; }      // Active, Archived
        
        [StringLength(50)]
        public string? BookingStatus { get; set; } // Booked, NotBooked
        
        public DateTime? BookingFrom { get; set; }    
        public DateTime? BookingTo { get; set; }      
        
        [StringLength(4000)]
        public string? Description { get; set; }    // New description field
    }
}

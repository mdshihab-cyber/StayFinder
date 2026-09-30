using System.ComponentModel.DataAnnotations;

namespace StayFinder_Web_API.Models
{
    public class UpdateBookingDatesRequest
    {
        [Required(ErrorMessage = "Customer ID is required")]
        public int CustomerId { get; set; }

        [Required(ErrorMessage = "Check-in date is required")]
        public DateTime BookingFrom { get; set; }

        [Required(ErrorMessage = "Check-out date is required")]
        public DateTime BookingTo { get; set; }
    }
}
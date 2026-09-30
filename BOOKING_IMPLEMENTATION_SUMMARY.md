# Booking API Implementation Summary

## Overview
This implementation adds complete booking functionality to the StayFinder Web API, allowing customers to reserve properties through a user-friendly interface.

## API Endpoints

### 1. Create Booking
**Endpoint:** `POST /api/Bookings/create`

**Example JSON Payload (sent from frontend):**
```json
{
  "propertyId": 1,
  "customerId": 3,
  "bookingFrom": "2024-01-15T00:00:00.000Z",
  "bookingTo": "2024-01-20T00:00:00.000Z",
  "numberOfGuests": 2
}
```

**Success Response (200 OK):**
```json
{
  "message": "Booking created successfully!",
  "bookingId": 15,
  "propertyName": "Luxury Ocean View Villa",
  "totalPrice": 1000.00,
  "numberOfDays": 5,
  "checkIn": "2024-01-15",
  "checkOut": "2024-01-20",
  "guests": 2,
  "status": "confirmed",
  "paymentStatus": "pending"
}
```

**Error Response (400 Bad Request):**
```json
{
  "message": "Property is not available for the selected dates"
}
```

### 2. Get Customer Bookings
**Endpoint:** `GET /api/Bookings/customer/{customerId}`

**Response:**
```json
[
  {
    "id": 15,
    "propertyId": 1,
    "propertyName": "Luxury Ocean View Villa",
    "location": "Miami Beach, FL",
    "imageUrl": "https://example.com/image.jpg",
    "bookingFrom": "2024-01-15",
    "bookingTo": "2024-01-20",
    "numberOfGuests": 2,
    "totalPrice": 1000.00,
    "status": "confirmed",
    "paymentStatus": "pending",
    "createdAt": "2024-01-10 14:30:22"
  }
]
```

### 3. Cancel Booking
**Endpoint:** `DELETE /api/Bookings/{bookingId}?customerId={customerId}`

**Success Response:**
```json
{
  "message": "Booking cancelled successfully"
}
```

## Frontend Integration

### JavaScript Functions Added:

1. **`bookProperty()`** - Main booking function triggered by "Reserve Now" button
2. **`validateDates()`** - Validates check-in and check-out dates
3. **`calculateTotalPrice()`** - Calculates total booking cost
4. **`resetBookingForm()`** - Resets form after successful booking

### Key Features:

- **Date Validation:** Prevents past dates and invalid date ranges
- **Price Calculation:** Automatic calculation of total price (PricePerDay × Days × Guests)
- **Conflict Detection:** Server-side validation prevents double bookings
- **User Authentication:** Only logged-in customers can make bookings
- **Real-time Feedback:** Loading states and success/error messages
- **Booking Confirmation:** Detailed confirmation dialog before submission

## Database Operations

### Insert Booking:
```sql
INSERT INTO Bookings (PropertyId, CustomerId, BookingFrom, BookingTo, NumberOfGuests, TotalPrice, Status, PaymentStatus, CreatedAt)
VALUES (@PropertyId, @CustomerId, @BookingFrom, @BookingTo, @NumberOfGuests, @TotalPrice, 'confirmed', 'pending', GETUTCDATE())
```

### Conflict Check:
```sql
SELECT COUNT(*) FROM Bookings 
WHERE PropertyId = @PropertyId 
AND Status IN ('confirmed', 'pending')
AND (
    (BookingFrom <= @BookingFrom AND BookingTo > @BookingFrom) OR
    (BookingFrom < @BookingTo AND BookingTo >= @BookingTo) OR
    (BookingFrom >= @BookingFrom AND BookingTo <= @BookingTo)
)
```

## Flow Diagram

```
1. User clicks "Reserve Now" ? 
2. Frontend validates dates and user authentication ? 
3. Frontend calculates total price and shows confirmation ? 
4. User confirms booking ? 
5. Frontend sends POST request to /api/Bookings/create ? 
6. Backend validates data and checks conflicts ? 
7. Backend inserts booking into database ? 
8. Backend returns success response ? 
9. Frontend shows success message ? 
10. Optional redirect to customer dashboard
```

## Validation Rules

### Frontend Validations:
- User must be logged in as Customer
- Check-in date cannot be in the past
- Check-out date must be after check-in date
- Both dates must be selected

### Backend Validations:
- Property must exist and be active
- Customer must exist
- No conflicting bookings for the same property and dates
- Date range validation (check-out after check-in)
- Number of guests must be between 1 and 20

## Error Handling

### Common Error Messages:
- "Please sign in to book properties"
- "Only customers can book properties" 
- "Please select both check-in and check-out dates"
- "Check-in date cannot be in the past"
- "Check-out date must be after check-in date"
- "Property is not available for the selected dates"
- "Property not found"
- "Customer not found"

## Security Features

- **Parameterized SQL Queries:** Prevents SQL injection
- **Input Validation:** Server-side validation of all inputs
- **User Authentication:** Booking restricted to authenticated customers
- **Data Sanitization:** All user inputs are validated and sanitized

## Testing

Use the provided `test_booking_api_functionality.sql` script to:
1. View existing bookings
2. Check for conflicts
3. Test price calculations
4. Verify booking creation
5. Test customer booking history

## Usage Example

1. **User Experience:**
   - User browses properties on index.html
   - User selects dates in the Airbnb-style date picker
   - User adjusts guest count
   - User clicks "View Details" on a property
   - User clicks "Reserve Now" in the modal
   - User sees confirmation with total price
   - User confirms the booking
   - User receives success message with booking details

2. **API Call:**
   ```javascript
   const response = await fetch('/api/Bookings/create', {
     method: 'POST',
     headers: { 'Content-Type': 'application/json' },
     body: JSON.stringify({
       propertyId: 1,
       customerId: 3,
       bookingFrom: "2024-01-15T00:00:00.000Z",
       bookingTo: "2024-01-20T00:00:00.000Z",
       numberOfGuests: 2
     })
   });
   ```

3. **Database Record:**
   ```
   Id: 15
   PropertyId: 1
   CustomerId: 3
   BookingFrom: 2024-01-15 00:00:00.000
   BookingTo: 2024-01-20 00:00:00.000
   NumberOfGuests: 2
   TotalPrice: 1000.00
   Status: confirmed
   PaymentStatus: pending
   CreatedAt: 2024-01-10 14:30:22.147
   ```

## Next Steps (Optional Enhancements)

1. **Email Notifications:** Send confirmation emails
2. **Payment Integration:** Add Stripe/PayPal integration
3. **Calendar Integration:** Add calendar view for availability
4. **Booking Modifications:** Allow users to modify bookings
5. **Reviews:** Add post-stay review system
6. **Cancellation Policies:** Implement flexible cancellation rules
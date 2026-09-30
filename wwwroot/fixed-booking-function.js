// Fixed booking function without alerts for index.html
async function bookProperty() {
    // Check basic requirements
    if (!currentPropertyId || !currentProperty) {
        if (!currentUser) {
            document.getElementById('signin-modal').showModal();
            return;
        }
        return;
    }

    if (!currentUser) {
        document.getElementById('signin-modal').showModal();
        return;
    }

    // Validate user role - silently return for non-customers
    if (currentUser.role !== 'Customer') {
        return;
    }

    // Validate dates
    const dateValidation = validateDates();
    if (!dateValidation.valid) {
        console.warn(dateValidation.message);
        return;
    }

    const checkInDate = document.getElementById('check-in-date').value;
    const checkOutDate = document.getElementById('check-out-date').value;

    // Calculate pricing
    const pricing = calculateTotalPrice();
    if (pricing.totalPrice === 0) {
        console.warn('Unable to calculate total price. Please check your dates.');
        return;
    }

    try {
        // Show loading state
        const reserveBtn = event.target;
        const originalText = reserveBtn.textContent;
        reserveBtn.disabled = true;
        reserveBtn.textContent = 'Processing...';

        // Prepare booking data
        const bookingData = {
            propertyId: currentPropertyId,
            customerId: currentUser.id,
            bookingFrom: checkInDate + 'T00:00:00.000Z',
            bookingTo: checkOutDate + 'T00:00:00.000Z',
            numberOfGuests: guestCount
        };

        console.log('Sending booking request:', bookingData);

        // Send booking request
        const response = await fetch(`${BOOKINGS_API_URL}/create`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(bookingData)
        });

        const result = await response.json();
        console.log('Booking response:', response.status, result);

        if (response.ok) {
            // Success - close modal and redirect to payment page
            document.getElementById('property-modal').close();
            resetBookingForm();

            // Redirect directly to payment page
            const paymentUrl = `Payment.html?bookingId=${result.bookingId}&propertyName=${encodeURIComponent(result.propertyName)}&location=${encodeURIComponent(currentProperty.location)}&checkin=${result.checkIn}&checkout=${result.checkOut}&guests=${result.guests}&pricePerNight=${currentProperty.pricePerDay}&nights=${pricing.numberOfDays}&totalPrice=${result.totalPrice}`;
            window.location.href = paymentUrl;

        } else {
            // Error from server - log to console instead of showing alert
            console.error(`Booking Failed: ${result.message || 'Unknown error occurred'}`);
            
            // Reset button state
            reserveBtn.disabled = false;
            reserveBtn.textContent = originalText;
        }

    } catch (error) {
        console.error('Error creating booking:', error);
        
        // Reset button state
        const reserveBtn = document.querySelector('#property-modal button[onclick="bookProperty()"]');
        if (reserveBtn) {
            reserveBtn.disabled = false;
            reserveBtn.textContent = 'Reserve Now';
        }
    }
}
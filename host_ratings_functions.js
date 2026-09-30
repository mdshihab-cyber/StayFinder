        // Ratings Functions - Enhanced Implementation
        async function loadRatings() {
            if (!currentUser) return;

            console.log('Loading ratings for host:', currentUser.id);
            
            try {
                // Load ratings summary
                const summaryResponse = await fetch(`/api/PropertyReviews/host/${currentUser.id}/summary`);
                if (summaryResponse.ok) {
                    const summary = await summaryResponse.json();
                    displayRatingsSummary(summary);
                }

                // Load reviews list
                const reviewsResponse = await fetch(`/api/PropertyReviews/host/${currentUser.id}`);
                if (reviewsResponse.ok) {
                    const reviews = await reviewsResponse.json();
                    displayReviewsList(reviews);
                } else {
                    console.error('Failed to load reviews:', reviewsResponse.status);
                    displayRatingsError();
                }

            } catch (error) {
                console.error('Error loading ratings:', error);
                displayRatingsError();
            }
        }

        function displayRatingsSummary(summary) {
            // Update overall rating
            document.getElementById('overall-rating').textContent = summary.averageRating.toFixed(1);
            document.getElementById('total-reviews').textContent = summary.totalReviews;
            
            // Generate star display
            const starsContainer = document.getElementById('overall-stars');
            starsContainer.innerHTML = generateStarsHTML(summary.averageRating);

            // Update rating distribution bars
            const totalReviews = summary.totalReviews;
            const distribution = summary.ratingDistribution;

            // Calculate percentages and update bars
            updateRatingBar('rating-5', distribution.fiveStar, totalReviews);
            updateRatingBar('rating-4', distribution.fourStar, totalReviews);
            updateRatingBar('rating-3', distribution.threeStar, totalReviews);
            updateRatingBar('rating-2', distribution.twoStar, totalReviews);
            updateRatingBar('rating-1', distribution.oneStar, totalReviews);
        }

        function updateRatingBar(ratingPrefix, count, total) {
            const percentage = total > 0 ? (count / total) * 100 : 0;
            const barElement = document.getElementById(`${ratingPrefix}-bar`);
            const countElement = document.getElementById(`${ratingPrefix}-count`);
            
            if (barElement) {
                barElement.style.width = `${percentage}%`;
            }
            if (countElement) {
                countElement.textContent = count;
            }
        }

        function generateStarsHTML(rating) {
            let starsHTML = '';
            for (let i = 1; i <= 5; i++) {
                const filled = i <= Math.round(rating);
                const starClass = filled ? 'text-yellow-400' : 'text-gray-300';
                starsHTML += `
                    <svg class="w-6 h-6 ${starClass}" fill="currentColor" viewBox="0 0 20 20">
                        <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.519 4.674a1 1 0 00.95.69h4.915c.969 0 1.371 1.24.588 1.81l-3.976 2.888a1 1 0 00-.363 1.118l1.518 4.674c.3.922-.755 1.688-1.538 1.118l-3.976-2.888a1 1 0 00-1.176 0l-3.976 2.888c-.783.57-1.838-.197-1.538-1.118l1.518-4.674a1 1 0 00-.363-1.118l-3.976-2.888c-.784-.57-.38-1.81.588-1.81h4.914a1 1 0 00.951-.69l1.519-4.674z"></path>
                    </svg>
                `;
            }
            return starsHTML;
        }

        function displayReviewsList(reviews) {
            const reviewsList = document.getElementById('reviews-list');
            
            if (reviews.length === 0) {
                reviewsList.innerHTML = `
                    <div class="px-6 py-8 text-center text-gray-500">
                        <div class="flex flex-col items-center">
                            <svg class="w-12 h-12 text-gray-300 mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <polygon points="12,2 15.09,8.26 22,9.27 17,14.14 18.18,21.02 12,17.77 5.82,21.02 7,14.14 2,9.27 8.91,8.26"></polygon>
                            </svg>
                            <p class="font-medium">No reviews yet</p>
                            <p class="text-sm">Your property reviews will appear here once customers leave feedback</p>
                        </div>
                    </div>
                `;
                return;
            }

            reviewsList.innerHTML = reviews.map(review => {
                const reviewDate = new Date(review.createdAt).toLocaleDateString('en-US', {
                    year: 'numeric',
                    month: 'long',
                    day: 'numeric'
                });

                const starRating = generateStarsHTML(review.rating);
                const ratingColor = getRatingColor(review.rating);

                return `
                    <div class="px-6 py-6 hover:bg-gray-50 transition-colors">
                        <div class="flex items-start justify-between mb-4">
                            <div class="flex-1">
                                <!-- Customer Info -->
                                <div class="flex items-center gap-3 mb-3">
                                    <div class="w-10 h-10 bg-[#04aa6d] rounded-full flex items-center justify-center">
                                        <span class="text-white font-bold text-sm">${review.customerName.charAt(0).toUpperCase()}</span>
                                    </div>
                                    <div>
                                        <h4 class="font-semibold text-gray-800">${review.customerName}</h4>
                                        <p class="text-sm text-gray-500">${review.customerEmail}</p>
                                    </div>
                                </div>

                                <!-- Property Info -->
                                <div class="mb-3 pl-13">
                                    <p class="font-medium text-gray-700">${review.propertyName}</p>
                                    <p class="text-sm text-gray-500 flex items-center gap-1">
                                        <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z"></path>
                                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z"></path>
                                        </svg>
                                        ${review.propertyLocation}
                                    </p>
                                </div>
                            </div>

                            <!-- Rating Badge -->
                            <div class="flex flex-col items-end">
                                <div class="flex items-center gap-2 mb-2">
                                    <span class="text-sm font-medium text-gray-700">${review.rating}.0</span>
                                    <div class="flex">
                                        ${Array.from({length: review.rating}, () => 
                                            '<svg class="w-4 h-4 text-yellow-400" fill="currentColor" viewBox="0 0 20 20"><path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.519 4.674a1 1 0 00.95.69h4.915c.969 0 1.371 1.24.588 1.81l-3.976 2.888a1 1 0 00-.363 1.118l1.518 4.674c.3.922-.755 1.688-1.538 1.118l-3.976-2.888a1 1 0 00-1.176 0l-3.976 2.888c-.783.57-1.838-.197-1.538-1.118l1.518-4.674a1 1 0 00-.363-1.118l-3.976-2.888c-.784-.57-.38-1.81.588-1.81h4.914a1 1 0 00.951-.69l1.519-4.674z"></path></svg>'
                                        ).join('')}
                                    </div>
                                </div>
                                <span class="text-xs text-gray-400">Review #${review.id}</span>
                            </div>
                        </div>

                        <!-- Review Comment -->
                        ${review.comment ? `
                            <div class="mb-4 pl-13">
                                <div class="bg-gray-50 rounded-lg p-4">
                                    <p class="text-gray-700 leading-relaxed">"${review.comment}"</p>
                                </div>
                            </div>
                        ` : `
                            <div class="mb-4 pl-13">
                                <p class="text-gray-500 italic">Customer left a rating without a written review</p>
                            </div>
                        `}

                        <!-- Review Footer -->
                        <div class="flex items-center justify-between pl-13">
                            <div class="flex items-center gap-2 text-sm text-gray-500">
                                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"></path>
                                </svg>
                                ${reviewDate}
                            </div>
                            <div class="flex gap-2">
                                <button onclick="respondToReview(${review.id}, '${review.customerName.replace(/'/g, "\\'")}', '${review.propertyName.replace(/'/g, "\\'")}', ${review.rating})" 
                                        class="btn btn-xs bg-blue-500 text-white hover:bg-blue-600" 
                                        title="Respond to Review">
                                    <svg class="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 10h10a8 8 0 018 8v2M3 10l6 6m-6-6l6-6"></path>
                                    </svg>
                                    Respond
                                </button>
                                <button onclick="contactCustomer('${review.customerEmail}')" 
                                        class="btn btn-xs bg-green-500 text-white hover:bg-green-600" 
                                        title="Contact Customer">
                                    <svg class="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 4.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 012-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"></path>
                                    </svg>
                                    Contact
                                </button>
                            </div>
                        </div>
                    </div>
                `;
            }).join('');
        }

        function displayRatingsError() {
            const reviewsList = document.getElementById('reviews-list');
            reviewsList.innerHTML = `
                <div class="px-6 py-8 text-center text-red-500">
                    <div class="flex flex-col items-center">
                        <svg class="w-12 h-12 text-red-300 mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.732-.833-2.464 0L4.35 16.5c-.77.833.192 2.5 1.732 2.5z"></path>
                        </svg>
                        <p class="font-medium">Failed to load reviews</p>
                        <p class="text-sm">Please try refreshing the page</p>
                    </div>
                </div>
            `;

            // Reset summary to default values
            document.getElementById('overall-rating').textContent = '0.0';
            document.getElementById('total-reviews').textContent = '0';
            document.getElementById('overall-stars').innerHTML = generateStarsHTML(0);
            
            // Reset rating bars
            updateRatingBar('rating-5', 0, 0);
            updateRatingBar('rating-4', 0, 0);
            updateRatingBar('rating-3', 0, 0);
            updateRatingBar('rating-2', 0, 0);
            updateRatingBar('rating-1', 0, 0);
        }

        // Filter reviews by rating
        async function filterReviewsByRating() {
            const filterValue = document.getElementById('rating-filter').value;
            
            if (!currentUser) return;
            
            try {
                let apiUrl = `/api/PropertyReviews/host/${currentUser.id}`;
                const response = await fetch(apiUrl);
                
                if (response.ok) {
                    let reviews = await response.json();
                    
                    // Apply client-side filtering if a rating is selected
                    if (filterValue) {
                        const targetRating = parseInt(filterValue);
                        reviews = reviews.filter(review => review.rating === targetRating);
                    }
                    
                    displayReviewsList(reviews);
                } else {
                    displayRatingsError();
                }
            } catch (error) {
                console.error('Error filtering reviews:', error);
                displayRatingsError();
            }
        }

        // Action functions for reviews
        function respondToReview(reviewId, customerName, propertyName, rating) {
            // For now, show a placeholder modal or redirect to response form
            //alert(`Responding to review #${reviewId}\n\nCustomer: ${customerName}\nProperty: ${propertyName}\nRating: ${rating} stars\n\nResponse functionality can be implemented in future updates.`);
        }

        function contactCustomer(email) {
            // Open email client to contact customer
            window.location.href = `mailto:${email}?subject=Thank you for your review - StayFinder`;
        }
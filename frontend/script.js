const form = document.getElementById('contactForm');
const successAlert = document.getElementById('successAlert');
const errorAlert = document.getElementById('errorAlert');

// Get API URL from config (set by Terraform) or use fallback
const API_URL = window.APP_CONFIG?.API_URL || 'YOUR_API_GATEWAY_URL_PLACEHOLDER';

// Validation patterns
const patterns = {
    email: /^[^\s@]+@[^\s@]+\.[^\s@]+$/,
    phone: /^[\d\s\-\+\(\)]+$/
};

// Validate individual field
function validateField(field) {
    const group = field.closest('.form-group');
    let isValid = true;

    // Only validate required fields or fields with content
    if (field.hasAttribute('required')) {
        if (field.type === 'email') {
            isValid = patterns.email.test(field.value);
        } else {
            isValid = field.value.trim().length >= 2;
        }
    } else if (field.value.trim() !== '') {
        // Validate optional fields only if they have content
        if (field.type === 'tel') {
            isValid = patterns.phone.test(field.value) && field.value.trim().length >= 10;
        } else if (field.type === 'text' && field.id !== 'subject') {
            isValid = field.value.trim().length >= 2;
        }
    } else {
        // Empty optional field is valid
        group.classList.remove('error');
        return true;
    }

    if (!isValid) {
        group.classList.add('error');
    } else {
        group.classList.remove('error');
    }

    return isValid;
}

// Add real-time validation
form.querySelectorAll('input, select, textarea').forEach(field => {
    field.addEventListener('blur', () => validateField(field));
    field.addEventListener('input', () => {
        if (field.closest('.form-group').classList.contains('error')) {
            validateField(field);
        }
    });
});

// Form submission
form.addEventListener('submit', async function(e) {
    e.preventDefault();

    // Hide previous alerts
    successAlert.classList.remove('show');
    errorAlert.classList.remove('show');

    // Validate all fields
    let isValid = true;
    const fields = form.querySelectorAll('input, select, textarea');
    
    fields.forEach(field => {
        if (!validateField(field)) {
            isValid = false;
        }
    });

    if (!isValid) {
        // Show validation error message
        errorAlert.textContent = 'Please fix the errors above and try again.';
        errorAlert.classList.add('show');
        
        // Scroll to first error
        const firstError = form.querySelector('.form-group.error');
        if (firstError) {
            firstError.scrollIntoView({ behavior: 'smooth', block: 'center' });
        }

        // Hide error message after 5 seconds
        setTimeout(() => {
            errorAlert.classList.remove('show');
        }, 5000);
        return;
    }

    // Show loading state
    const submitBtn = document.querySelector('button[type="submit"]');
    const originalText = submitBtn.textContent;
    submitBtn.disabled = true;
    submitBtn.textContent = 'Sending...';

    try {
        // Prepare form data for API
        const formData = {
            name: document.getElementById('fullName').value,
            email: document.getElementById('email').value,
            message: document.getElementById('message').value,
            company: document.getElementById('company').value || null,
            phone: document.getElementById('phone').value || null,
            subject: document.getElementById('subject').value || null,
            travelease_dates: document.getElementById('travelease_dates').value || null,
            budget: document.getElementById('budget').value || null
        };

        // Send to API Gateway
        const response = await fetch(API_URL, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify(formData)
        });

        const result = await response.json();

        if (response.ok) {
            // Show success message
            successAlert.textContent = '✅ Thank you! Your message has been sent successfully. We\'ll get back to you soon.';
            successAlert.classList.add('show');
            
            // Reset form
            form.reset();
            
            // Clear any error states
            document.querySelectorAll('.form-group.error').forEach(group => {
                group.classList.remove('error');
            });

            // Scroll to success message
            successAlert.scrollIntoView({ behavior: 'smooth', block: 'nearest' });

            // Hide success message after 5 seconds
            setTimeout(() => {
                successAlert.classList.remove('show');
            }, 5000);

        } else {
            // Show API error message
            errorAlert.textContent = `❌ Error: ${result.error || 'Failed to send message. Please try again.'}`;
            errorAlert.classList.add('show');
            
            // Scroll to error message
            errorAlert.scrollIntoView({ behavior: 'smooth', block: 'nearest' });

            // Hide error message after 5 seconds
            setTimeout(() => {
                errorAlert.classList.remove('show');
            }, 5000);
        }
        
    } catch (error) {
        // Show network error message
        errorAlert.textContent = '❌ Network error. Please check your connection and try again.';
        errorAlert.classList.add('show');
        console.error('Error:', error);
        
        // Scroll to error message
        errorAlert.scrollIntoView({ behavior: 'smooth', block: 'nearest' });

        // Hide error message after 5 seconds
        setTimeout(() => {
            errorAlert.classList.remove('show');
        }, 5000);
    } finally {
        // Reset button state
        submitBtn.disabled = false;
        submitBtn.textContent = originalText;
    }
});

// Check if API URL is configured
if (API_URL === 'YOUR_API_GATEWAY_URL_PLACEHOLDER') {
    console.warn('⚠️ API URL not configured. Form submissions will fail.');
}
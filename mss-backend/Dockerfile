FROM php:8.3-cli-alpine

# Set working directory
WORKDIR /var/www/html

# Install system dependencies and build tools
RUN apk add --no-cache \
    bash \
    curl \
    git \
    docker-cli \
    mariadb-client \
    libpng-dev \
    libxml2-dev \
    zip \
    unzip \
    procps \
    linux-headers

# Install PHP extensions required by Laravel & hardware monitoring
ADD --chmod=0755 https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions /usr/local/bin/
RUN install-php-extensions \
    pdo_mysql \
    bcmath \
    mbstring \
    zip \
    pcntl \
    posix \
    opcache

# Get Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Copy application code
COPY . /var/www/html

# Ensure storage and bootstrap cache permissions
RUN chmod -R 775 /var/www/html/storage /var/www/html/bootstrap/cache 2>/dev/null || true

# Expose backend port
EXPOSE 8000

# Start Laravel development server
CMD ["php", "artisan", "serve", "--host=0.0.0.0", "--port=8000"]

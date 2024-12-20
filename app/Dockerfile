# app/Dockerfile

# Stage 1: Build
FROM python:3.10-slim

WORKDIR /app

# Copy requirements first to leverage Docker layer caching
COPY requirements.txt /app

# Upgrade pip, setuptools, and wheel
# RUN pip install --upgrade pip setuptools wheel

# Install dependencies globally without using --user and without cache
RUN pip3 install --no-cache-dir -r requirements.txt

COPY . /app/

# Expose the application port
EXPOSE 5000

# Define the default command to run the application
CMD ["gunicorn", "-w", "4", "-b", "0.0.0.0:5000", "app:app"]
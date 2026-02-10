# Options Chain Analyzer - Flask Application

A web application for analyzing stock options chains with real-time data and annualized return calculations.

## Quick Start

### Run with uv (Recommended)

```bash
uv run python app.py
```

Visit http://localhost:5001

### Run with Docker

```bash
docker build -t options-app:latest .
docker run -p 5001:5000 options-app:latest
```

## Dependencies

Dependencies are managed via `pyproject.toml` and `uv.lock`:

- Flask 3.x - Web framework
- yfinance - Stock and options data
- pandas 3.x - Data manipulation
- numpy - Numerical calculations
- gunicorn - Production WSGI server
- curl_cffi - HTTP requests with browser impersonation

## Application Structure

```
app/
├── app.py                  # Flask routes and main application
├── option_calculator.py    # Options pricing and return calculations
├── templates/
│   └── index.html         # Main UI template
├── static/
│   └── styles.css         # Custom responsive styles
├── pyproject.toml         # Python dependencies
├── uv.lock                # Locked dependency versions
└── Dockerfile             # Container configuration
```

## Features

### 1. Real-Time Stock Data
- Fetches current price with 1-minute interval data
- Uses curl_cffi session to bypass bot detection

### 2. Options Chain Analysis
- **Cash-Secured Puts**: Calculate returns based on capital reserved
- **Covered Calls**: Calculate returns based on stock price

### 3. Dynamic Filtering
- **Annualized Return Threshold**: User-configurable (default 15%)
- **Out-of-the-Money Only**: Filter to show only OTM options

### 4. Responsive UI
- Pivot tables with horizontal scrolling
- Adapts to desktop and mobile screens
- Bootstrap 4 styling with custom CSS

## Calculations

### Cash-Secured Puts
```
Capital Reserved = strike × 100
Annualized Return = (premium / strike) × (365 / days_to_expiration) × 100
Breakeven % = (current_price - (strike - premium)) / current_price × 100
```

### Covered Calls
```
Annualized Return = (premium / stock_price) × (365 / days_to_expiration) × 100
Breakeven % = (strike + premium - current_price) / current_price × 100
```

## Docker Configuration

The Dockerfile uses:
- Base image: `ghcr.io/astral-sh/uv:python3.14-bookworm-slim`
- uv for fast dependency installation
- Gunicorn with 4 workers
- Container port: 5000

## Development

### Adding Dependencies

```bash
# Add a new dependency
uv add <package-name>

# Sync dependencies
uv sync

# Update lock file
uv lock
```

### Environment Variables

For production, set `FLASK_SECRET_KEY` environment variable instead of using the hardcoded value in app.py:22.

## Health Check

The `/health` endpoint returns:
- `{"status": "UP"}` with HTTP 200 when healthy
- `{"status": "DOWN"}` with HTTP 500 on error

Used by AWS ALB target group health checks.

# app.py

from flask import Flask, render_template, request, redirect, url_for, flash, jsonify
import pandas as pd
from option_calculator import fetch_and_calculate_option_returns, build_pivot_table, get_current_price
import yfinance as yf
from datetime import datetime
import logging
import sys
from curl_cffi import requests

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s %(levelname)s: %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)

app = Flask(__name__)
app.secret_key = 'your_secret_key'  # Replace with a secure key in production

@app.route('/', methods=['GET', 'POST'])
def index():
    # Support both POST form data and GET query parameters
    params = request.form if request.method == 'POST' else request.args
    ticker = params.get('ticker', '').upper().strip()

    if ticker:
        logger.info(f"Received ticker: {ticker}")
        return_filter = params.get('return_filter') == 'on'
        out_of_the_money = params.get('out_of_the_money') == 'on'

        # Get the return threshold, default to 15.0 if not provided or invalid
        try:
            return_threshold = float(params.get('return_threshold', 15.0))
        except (ValueError, TypeError):
            return_threshold = 15.0

        try:
            # Fetch current stock price
            session = requests.Session(impersonate="chrome")
            stock = yf.Ticker(ticker, session=session)

            current_price, price_time = get_current_price(stock)

            # Fetch and calculate option returns with dynamic threshold
            puts, calls = fetch_and_calculate_option_returns(ticker, return_filter, not out_of_the_money, return_threshold, session=session)

            # Build pivot tables for puts and calls and replace NaN with empty strings
            puts_pivot = build_pivot_table(puts).fillna('')
            calls_pivot = build_pivot_table(calls).fillna('')

            # Format 'Annualized Return' with '%' and 'bid' with two decimal places
            for pivot in [puts_pivot, calls_pivot]:
                for col in pivot.columns:
                    if col[1] == 'Annualized Return':
                        # Format as integer percentage (e.g., 1318%)
                        pivot[col] = pivot[col].apply(lambda x: f"{int(round(x))}%" if isinstance(x, (float, int)) else '')
                    elif col[1] == 'Breakeven %':
                        pivot[col] = pivot[col].apply(lambda x: f"{x:.1f}%" if isinstance(x, (float, int)) else '')
                    elif col[1] == 'bid':
                        # Format bid with two decimal places
                        pivot[col] = pivot[col].apply(lambda x: f"{x:.2f}" if isinstance(x, (float, int)) else '')

            # Convert pivot tables to HTML without borders and with Bootstrap styling
            puts_pivot_html = puts_pivot.to_html(classes='table table-striped', escape=False, border=0) if not puts_pivot.empty else ''
            calls_pivot_html = calls_pivot.to_html(classes='table table-striped', escape=False, border=0) if not calls_pivot.empty else ''

            # Determine what to display based on available data
            if puts_pivot.empty and calls_pivot.empty:
                flash('No options meet the specified criteria.', 'warning')
                return redirect(url_for('index'))

            return render_template(
                'index.html',
                puts_pivot=puts_pivot_html,
                calls_pivot=calls_pivot_html,
                ticker=ticker,
                return_filter=return_filter,
                return_threshold=return_threshold,
                out_of_the_money=out_of_the_money,
                current_price=current_price,
                price_time=price_time
            )
        except ValueError as ve:
            flash(str(ve), 'warning')
            return redirect(url_for('index'))
        except Exception as e:
            flash('An unexpected error occurred. Please try again later.', 'danger')
            # Optionally log the error here for debugging
            logger.error(f"Error: {e}")
            return redirect(url_for('index'))

    return render_template('index.html')

@app.route('/health', methods=['GET'])
def health():
    """
    Health check endpoint for AWS ALB.
    Returns HTTP 200 OK if the application is running.
    """
    try:
        # Perform any necessary health checks here
        # For example, check database connectivity, external service availability, etc.
        # Since this is a simple app, we'll just return a 200 status.
        return jsonify(status='UP'), 200
    except Exception as e:
        print(f"Health check failed: {e}")
        return jsonify(status='DOWN'), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5001)
# app.py

from flask import Flask, render_template, request, redirect, url_for, flash
import pandas as pd
from option_calculator import fetch_and_calculate_option_returns, build_pivot_table
import yfinance as yf
from datetime import datetime

app = Flask(__name__)
app.secret_key = 'your_secret_key'  # Replace with a secure key in production

@app.route('/', methods=['GET', 'POST'])
def index():
    if request.method == 'POST':
        ticker = request.form.get('ticker').upper().strip()
        return_filter = request.form.get('return_filter') == 'on'
        out_of_the_money = request.form.get('out_of_the_money') == 'on'  # Renamed for clarity

        if not ticker:
            flash('Please enter a stock ticker symbol.', 'danger')
            return redirect(url_for('index'))

        try:
            # Fetch current stock price
            stock = yf.Ticker(ticker)
            hist = stock.history(period="1d")
            if hist.empty:
                raise ValueError("Invalid ticker symbol or no data available.")
            current_price = hist['Close'][0]
            price_time = hist.index[0].strftime('%Y-%m-%d %H:%M:%S')

            # Fetch and calculate option returns
            puts, calls = fetch_and_calculate_option_returns(ticker, return_filter, not out_of_the_money)

            # Build pivot tables for puts and calls and replace NaN with empty strings
            puts_pivot = build_pivot_table(puts).fillna('')
            calls_pivot = build_pivot_table(calls).fillna('')

            # Format 'Annualized Return' with '%' and 'bid' with two decimal places
            for pivot in [puts_pivot, calls_pivot]:
                for col in pivot.columns:
                    if col[1] == 'Annualized Return':
                        # Format as integer percentage (e.g., 1318%)
                        pivot[col] = pivot[col].apply(lambda x: f"{int(round(x))}%" if isinstance(x, (float, int)) else '')
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
            print(f"Error: {e}")
            return redirect(url_for('index'))

    return render_template('index.html')

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
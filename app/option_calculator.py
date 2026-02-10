# option_calculator.py

from typing import List, Tuple
import yfinance as yf
import pandas as pd

def calculate_annualized_return(option_data: pd.DataFrame, stock_price: float, days_to_expiration: int, type: str) -> pd.DataFrame:
    """
    Calculate the annualized return for each option.
    """
    if type == 'puts':
        # For cash secured puts, capital reserved = strike price * 100
        # Return = premium collected / capital reserved
        option_data['Annualized Return'] = option_data['bid'] / option_data['strike'] * 365 / days_to_expiration * 100
        # Breakeven distance: current price vs strike - premium
        option_data['Breakeven %'] = (stock_price - (option_data['strike'] - option_data['bid'])) / stock_price * 100
    elif type == 'calls':
        # For covered calls, return = premium collected / current stock price
        option_data["Annualized Return"] = option_data['bid'] / stock_price * 365 / days_to_expiration * 100
        # Breakeven distance: strike + premium vs current price
        option_data['Breakeven %'] = (option_data['strike'] + option_data['bid'] - stock_price) / stock_price * 100
    # Replace infinite or NaN values
    option_data['Annualized Return'] = option_data['Annualized Return'].replace([float('inf'), -float('inf')], 0)
    option_data['Annualized Return'] = option_data['Annualized Return'].fillna(0)

    return option_data

def fetch_and_calculate_option_returns(ticker_symbol: str, return_filter: bool = False, in_the_money: bool = False, return_threshold: float = 15.0) -> Tuple[pd.DataFrame, pd.DataFrame]:
    """
    Fetch option chain data and calculate annualized returns for each put/call option.

    Args:
        ticker_symbol: Stock ticker symbol
        return_filter: Whether to apply the return threshold filter
        in_the_money: Whether to include in-the-money options
        return_threshold: Minimum annualized return percentage for filtering (default 15.0)
    """
    calls_threshold: float = return_threshold
    puts_threshold: float = return_threshold

    # Fetch the stock data
    stock = yf.Ticker(ticker_symbol)
    stock_price = stock.info.get('currentPrice', None)
    if stock_price is None:
        try:
            stock_price = stock.info.get('regularMarketPrice')
        except KeyError: 
            raise ValueError("Unable to find the current stock price.")

    expiration_dates = stock.options

    if not expiration_dates:
        raise ValueError(f"No options data available for {ticker_symbol}.")

    all_calls: List[pd.DataFrame] = []
    all_puts: List[pd.DataFrame] = []

    # Fetch data for all expiration dates
    for date in expiration_dates:
        option_chain = stock.option_chain(date)
        days_to_expiration: int = (pd.to_datetime(date) - pd.Timestamp.now()).days

        if days_to_expiration <= 0:
            continue  # Skip expired options

        # Process call options
        calls = calculate_annualized_return(option_chain.calls.copy(), stock_price, days_to_expiration, "calls")
        if return_filter:
            calls = calls[calls["Annualized Return"] > calls_threshold]
        if not in_the_money:
            calls = calls[calls["inTheMoney"] == False]

        if not calls.empty:
            # Use .loc to set new columns safely
            calls.loc[:, "Expiration Date"] = date
            calls.loc[:, "Stock Price"] = stock_price
            all_calls.append(calls)

        # Process put options
        puts = calculate_annualized_return(option_chain.puts.copy(), stock_price, days_to_expiration, "puts")
        if return_filter:
            puts = puts[puts["Annualized Return"] > puts_threshold]
        if not in_the_money:
            puts = puts[puts["inTheMoney"] == False]

        if not puts.empty:
            # Use .loc to set new columns safely
            puts.loc[:, "Expiration Date"] = date
            puts.loc[:, "Stock Price"] = stock_price
            all_puts.append(puts)

    if not all_calls and not all_puts:
        raise ValueError("No options meet the specified criteria.")

    # Combine all expiration dates into single tables
    combined_calls: pd.DataFrame = pd.concat(all_calls, ignore_index=True) if all_calls else pd.DataFrame()
    combined_puts: pd.DataFrame = pd.concat(all_puts, ignore_index=True) if all_puts else pd.DataFrame()

    return combined_puts, combined_calls

def build_pivot_table(data: pd.DataFrame) -> pd.DataFrame:
    """
    Build a pivot table to display both bid price and annualized return together.
    """
    if data.empty:
        return pd.DataFrame()

    pivot = pd.pivot_table(
        data,
        index='strike',  # Rows: Strike Prices
        columns='Expiration Date',  # Columns: Expiration Dates
        values=['bid', 'Annualized Return'],  # Values: Bid and Annualized Return
        aggfunc='mean'  # Aggregation function (e.g., mean if duplicates exist)
    )

    pivot = pivot.swaplevel(axis=1).sort_index(axis=1)
    return pivot

def get_current_price(stock):
    hist = stock.history(period="1d", interval="1m")  # Fetching 1 day's data with 1-minute intervals
    
    if hist.empty:
        raise ValueError("No data found for the ticker symbol.")
    
    # Get the last available data point
    last_quote = hist.iloc[-1]
    current_price = last_quote['Close']
    price_time = last_quote.name  # This is a Timestamp
    
    # Convert Timestamp to desired format and timezone
    price_time_formatted = price_time.strftime('%Y-%m-%d %H:%M:%S %Z')
    
    return current_price, price_time_formatted

if __name__ == "__main__":
    fetch_and_calculate_option_returns("QQQ", return_filter=False, in_the_money=False)

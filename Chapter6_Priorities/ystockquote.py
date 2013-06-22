#
#  ystockquote : Python module - retrieve stock quote data from Yahoo Finance
#
#  Copyright (c) 2007,2008,2013 Corey Goldberg (cgoldberg@gmail.com)
#
#  license: GNU LGPL
#
#  This library is free software; you can redistribute it and/or
#  modify it under the terms of the GNU Lesser General Public
#  License as published by the Free Software Foundation; either
#  version 2.1 of the License, or (at your option) any later version.
#
#  Requires: Python 2.7/3.2+


__version__ = '0.2.2'


try:
    # py3
    from urllib.request import Request, urlopen
    from urllib.parse import urlencode
except ImportError:
    # py2
    from urllib2 import Request, urlopen
    from urllib import urlencode


def _request(symbol, stat):
    url = 'http://finance.yahoo.com/d/quotes.csv?s=%s&f=%s' % (symbol, stat)
    req = Request(url)
    resp = urlopen(req)
    return str(resp.read().decode('utf-8').strip())


def get_all(symbol):
    """
    Get all available quote data for the given ticker symbol.

    Returns a dictionary.
    """
    values = _request(symbol, 'l1c1va2xj1b4j4dyekjm3m4rr5p5p6s7').split(',')
    return dict(
        price=values[0],
        change=values[1],
        volume=values[2],
        avg_daily_volume=values[3],
        stock_exchange=values[4],
        market_cap=values[5],
        book_value=values[6],
        ebitda=values[7],
        dividend_per_share=values[8],
        dividend_yield=values[9],
        earnings_per_share=values[10],
        fifty_two_week_high=values[11],
        fifty_two_week_low=values[12],
        fifty_day_moving_avg=values[13],
        two_hundred_day_moving_avg=values[14],
        price_earnings_ratio=values[15],
        price_earnings_growth_ratio=values[16],
        price_sales_ratio=values[17],
        price_book_ratio=values[18],
        short_ratio=values[19],
    )


def get_price(symbol):
    return _request(symbol, 'l1')


def get_change(symbol):
    return _request(symbol, 'c1')


def get_volume(symbol):
    return _request(symbol, 'v')


def get_avg_daily_volume(symbol):
    return _request(symbol, 'a2')


def get_stock_exchange(symbol):
    return _request(symbol, 'x')


def get_market_cap(symbol):
    return _request(symbol, 'j1')


def get_book_value(symbol):
    return _request(symbol, 'b4')


def get_ebitda(symbol):
    return _request(symbol, 'j4')


def get_dividend_per_share(symbol):
    return _request(symbol, 'd')


def get_dividend_yield(symbol):
    return _request(symbol, 'y')


def get_earnings_per_share(symbol):
    return _request(symbol, 'e')


def get_52_week_high(symbol):
    return _request(symbol, 'k')


def get_52_week_low(symbol):
    return _request(symbol, 'j')


def get_50day_moving_avg(symbol):
    return _request(symbol, 'm3')


def get_200day_moving_avg(symbol):
    return _request(symbol, 'm4')


def get_price_earnings_ratio(symbol):
    return _request(symbol, 'r')


def get_price_earnings_growth_ratio(symbol):
    return _request(symbol, 'r5')


def get_price_sales_ratio(symbol):
    return _request(symbol, 'p5')


def get_price_book_ratio(symbol):
    return _request(symbol, 'p6')


def get_short_ratio(symbol):
    return _request(symbol, 's7')


def get_historical_prices(symbol, start_date, end_date):
    """
    Get historical prices for the given ticker symbol.
    Date format is 'YYYY-MM-DD'

    Returns a nested list (first item is list of column headers).
    """
    params = urlencode({
        's': symbol,
        'a': int(start_date[5:7]) - 1,
        'b': int(start_date[8:10]),
        'c': int(start_date[0:4]),
        'd': int(end_date[5:7]) - 1,
        'e': int(end_date[8:10]),
        'f': int(end_date[0:4]),
        'g': 'd',
        'ignore': '.csv',
    })
    url = 'http://ichart.yahoo.com/table.csv?%s' % params
    req = Request(url)
    resp = urlopen(req)
    content = str(resp.read().decode('utf-8').strip())
    days = content.splitlines()
    return [day.split(',') for day in days]
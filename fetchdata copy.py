#!/usr/bin/env python
# coding: utf-8

# In[15]:


from IPython.display import display, HTML
display (HTML("<style>.container { width:100% limportant; }‹/styles")) 
import pandas as pd
import numpy as np
import ccxt as c
from ccxt import binance as bi
from datetime import datetime
import json
from ordered_set import OrderedSet
import tushare as ts 
import yfinance as yf
import csv


# In[31]:


binance=c.binance()


# In[112]:


def fetch_data(ex, sym, dt, start, end):
    data = []
    temp = datetime.fromtimestamp(start/1000)
    while temp <datetime.fromtimestamp(end/1000):
        temp = int(datetime.timestamp(temp)*1000)
        data_temp = ex.fetch_ohlcv(sym, dt, temp, end)
        for k in data_temp:
            data.append(k)
        temp = datetime.fromtimestamp(int(data[len(data)-1][0]/1000))

    data_temp = OrderedSet([json.dumps(ele) for ele in data])
    data = [json.loads(ele) for ele in data_temp]

    for i in range(len(data)):
        data[i][0] = datetime.fromtimestamp(int(data [i][0]/1000))
        
    header=['time','open','high','low','close','volume']
    df=pd.DataFrame(data,columns=header)
    
    # Split Time column into Date and Time columns
    df['date'] = df['time'].dt.date
    df['time'] = df['time'].dt.time
    df['date'] = pd.to_datetime(df['date'])
    
    df['sym'] = sym
    
    # Reorder columns as per requirement
    df = df[['date', 'time', 'sym', 'open', 'high', 'low', 'close', 'volume']]

    df = df[df['date'] < '2023-03-17']
    
    return df


# In[113]:


start=int(datetime.timestamp(datetime(2021,1,1,8,0))*1000)
end=int(datetime.timestamp(datetime(2023,3,16,8,0))*1000)
BTC_1h=fetch_data(binance, 'BTC/USDT', '1h', start, end)
ETH_1h=fetch_data(binance, 'ETH/USDT', '1h', start, end)
hourly_data = pd.concat([BTC_1h, ETH_1h])
hourly_data.to_csv('hourly.csv', index=False)
hourly_data


# In[114]:


start=binance.rateLimit / 1000
end=int(datetime.timestamp(datetime(2023,3,16,8,0))*1000)
BTC_1d=fetch_data(binance, 'BTC/USDT', '1d', start, end)
ETH_1d=fetch_data(binance, 'ETH/USDT', '1d', start, end)
daily_data = pd.concat([BTC_1d, ETH_1d])
daily_data.to_csv('daily.csv', index=False)
daily_data


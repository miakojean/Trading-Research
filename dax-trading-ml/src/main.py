import pandas as pd 
import os

data = pd.read_excel("dax-trading-ml\data\GER40CashBacktest.xlsx")

print(data.tail(5))
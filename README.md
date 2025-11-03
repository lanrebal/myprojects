# Bitcoin Backtesting Engine (dbt + PostgreSQL)

A reproducible backtesting pipeline that answers two questions for a Bitcoin trading strategy:

1) **Which hour of the day delivers the biggest cumulative returns?**  
2) **Which hour of the day has the lowest maximum loss (drawdown)?**

The strategy is:
- Buy at the **first second** of a chosen hour (e.g., `15:00:00`), sell at the **last second** of the same hour (e.g., `15:59:59`) **every day**.
- Start with 1.0 BTC; **fully reinvest** all P&L into the next day’s trade for that same hour.
- Repeat for each hour (0–23) to compare outcomes.

**Details**
Using the bash script named = all_segments.sh
The code has been grouped into three segments. At the start, the code prompt to ask for the segment the user wants to run. You can choose to run only one of the segments or run all the segments. 

•	Segment 1 (Create Database, Create Staging Table, Load CSV into Staging Table - trading_data_staging)

•	Segment 2 (Run dbt Model to load table - trading_hourly_data)

•	Segment 3 (Run Trading Data Analysis to load table - trading_data_analysis). This segment runs specific analysis for the user and load the result into - trading_data_analysis table. This segment can be used multiple types for different date/hour parameters.

Segment 1:

•	This checks if the database named ‘lanre_db’ exist in PostgreSQL, if it doesn’t exist the database is created (I provided my PostgreSQL connection details) 

•	Create a staging table in the database named ‘trading_data_staging’ (if it doesn’t exist) 

•	Load the csv data file downloaded from Kaggle into the staging table created. The data downloaded from Kaggle is named ‘half2_BTCUSDT_1s’ and saved in my root directory - 'C:/half2_BTCUSDT_1s.csv'

•	Verify the data load by selecting the first 5 rows from the staging table. 

Segment 2: 

•	I created a dbt model (trading_hourly_data.sql) to be executed by the bash script. The model code is attached.

•	The model is saved in my DBT project directory named - c/dbt_projects_Lanre/Lanre_project

•	The model takes data from the trading_data_staging table, transforms it and materialise it as a table named trading_hourly_data.

•	The bash script runs: dbt run --select trading_hourly_data

•	The bash script runs: dbt test --select trading_hourly_data

•	The dbt transformation is to simplify the trading data for each hour. Instead of having data from the first time for the hours (in a day) till the last time for the hours, the dbt model combines the data for the first time and the last time for each hour in a day (e.g. 2021-02-23 10:00:00 and 2021-02-23 10:59:59). 

•	To calculate the gain/loss per hour, the open (price) for the first time in the hour and the close price for the last time in the hour is used. This assumes that the buy is done at 2021-02-23 10:00:00 – open price (for example) and the sell at 2021-02-23 10:59:59 – close price (for example) for the 10:00 AM hour.

•	Verify the data load into (trading_hourly_data.sql) by selecting the first 5 rows from the staging table. 

Segment 3:

•	This segment runs specific analysis for the user and load the result into - trading_data_analysis table. This segment can be executed for analysis and the data from the latest analysis will replace existing data in the table. 

•	If the user wants to know how much the loss/gain will be if they start trading from a particular date (e.g. Jan 1, 2023) and end on a particular date (e.g. Dec 31, 2023). The user can specify these dates and the hour(s) the buy and sell will be done (the hours selected will be applicable for all the days selected).  

•	In this case, the initial purchase on the first date specified by the user will be 1 unit at the opening price for the first hour for the first day and all profits / losses are fully reinvested in subsequent trades.

•	The final sale will be at the close price for the last hour in the specified date(s).

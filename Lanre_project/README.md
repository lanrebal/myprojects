This project contains DBT models that will calculate the following metrics:
● Gross Payment Volume
● Invoice Volume
● Accounts based on their stage:  Trials /  Subscribed / Churned


**Requirements:**
● All amounts are standardized to USD
● All Dates are standardized to Mountain Time (MT)


**The base data files are **

1. Account_Lifecycle_Events = fct_account_lifecycle_events
   
2. Accounts.csv = dim_accounts
   
3. Accounts_Geo = dim_account_geo
   
4. Invoice_Line_Items = fct_invoice_line_items
   
5. Invoices = fact_invoices
    
6. Payment_Transactions  = fct_payment_transactions

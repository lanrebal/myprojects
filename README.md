![image](https://github.com/user-attachments/assets/a4c6b78b-5409-4138-ad5d-0b554bba0bc2)

This repository has branches that contain the code and the GitHub workflows for 
1. hourly_trigger_function_app
2. data_processing_function_app
3. Azure_Data_Factory


**End-to-End Data Flow Overview**
This architecture outlines an automated data pipeline that ingests, processes, and stores hourly candlestick (kline) trading data from the Binance API using Azure cloud services. The pipeline supports both real-time streaming and batch processing, ensuring flexible, scalable analytics for crypto asset monitoring.

The process begins with an Hourly Trigger Function App that fetches data for selected crypto assets from the Binance API. The raw data is then dispatched simultaneously to two parallel processing paths:

1. Real-Time Processing: JSON payloads are sent to an Azure Service Bus topic. A Function App subscribed to this topic processes the payloads in near real time, transforms the data, and loads it into an Azure SQL Database table (dbo.CryptoAssetData) for real-time analytics.

2. Batch Processing: The same data is also stored in Azure Data Lake Storage (ADLS) as raw JSON files. An Azure Data Factory (ADF) pipeline periodically processes these files and loads the results into a separate Azure SQL Database table (dbo.CryptoAssetDataBatch). Processed files are then archived into a batch_processed directory.

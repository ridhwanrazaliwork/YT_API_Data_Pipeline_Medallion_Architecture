Bronze Bucket Name - rid-yt-pipeline-bronze-ap-southeast-1-dev
Silver Bucket Name - rid-yt-pipeline-silver-ap-southeast-1-dev
Gold Bucket Name - rid-yt-pipeline-gold-ap-southeast-1-dev

Script Bucket - rid-yt-pipeline-script-ap-southeast-1-dev

SNS ARN - arn:aws:sns:ap-southeast-1:905418370529:yt-data-pipeline-alerts-dev:c756a5d8-88c1-458b-bb1f-9d1e29071ff8

Glue Bronze - yt_pipeline_bronze_dev 
Glue Silver - yt_pipeline_silver_dev 
Glue Gold - yt_pipeline_gold_dev

--bronze_database yt_pipeline_bronze_dev 
--bronze_table raw_statistics 

--silver_database yt_pipeline_silver_dev 
--silver_table clean_statistics

--gold_database yt_pipeline_gold_dev
import pyspark
from pyspark.sql import SparkSession
from pyspark.sql.functions import *

##Separator Function
def print_separator():
    print("-" * 50) 
    
# Initialization and Create Session
print_separator()
print("Initializing and Creating Spark Session")
print_separator()

postgres_host = "dibimbing-dataeng-postgres"
postgres_db = "dibimbing_dataeng_db"
postgres_user = "dataeng"
postgres_password = "passwordkuatpostgres"

print(f"postgres_host: {postgres_host}")
print(f"postgres_db: {postgres_db}")
print(f"postgres_user: {postgres_user}")
print(f"postgres_password: {postgres_password}")
print_separator()

spark = SparkSession.builder \
    .appName('RFM_Analysis') \
    .master('spark://dibimbing-dataeng-spark-master:7077') \
    .config('spark.jars', '/opt/postgresql-42.2.18.jar') \
    .getOrCreate()

spark.sparkContext.setLogLevel('WARN')

# JDBC and Read Retail Data
print_separator()
print("JDBC and Read Retail Data")
print_separator()

jdbc_url = f'jdbc:postgresql://{postgres_host}:5432/{postgres_db}'
jdbc_properties = {
    'user': postgres_user,
    'password': postgres_password,
    'driver': 'org.postgresql.Driver',
    'stringtype': 'unspecified'
}

retail_df = spark.read.jdbc(
    url=jdbc_url,
    table='public.retail',
    properties=jdbc_properties
)

print("Data loaded, data sample:")
retail_df.show(10)
print(f"Number of rows: {retail_df.count()}")
print(f"Number of columns: {len(retail_df.columns)}")

# Showing and Handling Duplicates
print_separator()
print("Showing and Handling Duplicates")
print_separator()

duplicate_rows = retail_df.groupBy("invoiceno", "stockcode", "description", "quantity", "invoicedate", "unitprice", "customerid", "country").count().filter(col("count") > 1)
duplicate_rows.show(5)
print("We will assume that duplicates are caused by data entry errors and should be removed")
duplicate_count = retail_df.count() - retail_df.dropDuplicates().count()
print(f"Number of duplicate rows: {duplicate_count}")
retail_df = retail_df.dropDuplicates()
print("Duplicates removed")

# Missing Values Handling
print_separator()
print("Missing Values Handling")
print_separator()

missing_counts = retail_df.select([col(c).isNull().cast("int").alias(c) for c in retail_df.columns]) \
                         .agg(*[sum(col(c)).alias(c) for c in retail_df.columns])
print("Missing Values count:")
missing_counts.show()
retail_df = retail_df.filter(col("customerid").isNotNull())
retail_df = retail_df.withColumn("description", when(col("description").isNull(), "Others").otherwise(col("description")))
print(f"Number of rows: {retail_df.count()}")
print(f"Number of columns: {len(retail_df.columns)}")
print("Removed empty values from customerid")
print("Imputed empty descriptions with 'Others'")

# Descriptive Statistics and Range of Values
print_separator()
print("Descriptive Statistics and Range of Values")
print_separator()

summary_df = retail_df.describe()
print("Dataset Summary:")
summary_df.show()
for column in retail_df.columns:
    distinct_count = retail_df.select(column).distinct().count()
    distinct_values = retail_df.select(column).distinct().limit(3).collect()
    values_list = [str(row[column]) for row in distinct_values]
    print(f"Distinct values count for column '{column}': {distinct_count}")
    print(f"Sample values for column '{column}':")
    print(", ".join(values_list))
    print()
print("Important to note that negative quantity and unit price can be valid since it's used to describe returns or refunds")

# RFM Scoring and Analysis
print_separator()
print("RFM Scoring and Analysis")
print_separator()

retail_df = retail_df.withColumn("invoicedate", to_date("invoicedate", "yyyy-MM-dd"))
max_invoice_date = retail_df.agg({"invoicedate": "max"}).collect()[0][0]
rfm = retail_df.groupBy("customerid") \
    .agg(
        datediff(lit(max_invoice_date), max("invoicedate")).alias("recency"),
        countDistinct("invoiceno").alias("frequency"),
        (sum(col("unitprice") * col("quantity"))).alias("monetary_value")
    )

# Set Quartiles
recency_quantiles = rfm.approxQuantile("recency", [0.25, 0.5, 0.75], 0.05)
frequency_quantiles = rfm.approxQuantile("frequency", [0.25, 0.5, 0.75], 0.05)
monetary_quantiles = rfm.approxQuantile("monetary_value", [0.25, 0.5, 0.75], 0.05)

rfm = rfm.withColumn("recency_score",
                     when(col("recency") <= recency_quantiles[0], 5)
                     .when((col("recency") > recency_quantiles[0]) & (col("recency") <= recency_quantiles[1]), 4)
                     .when((col("recency") > recency_quantiles[1]) & (col("recency") <= recency_quantiles[2]), 3)
                     .otherwise(2))

rfm = rfm.withColumn("frequency_score",
                     when(col("frequency") <= frequency_quantiles[0], 2)
                     .when((col("frequency") > frequency_quantiles[0]) & (col("frequency") <= frequency_quantiles[1]), 3)
                     .when((col("frequency") > frequency_quantiles[1]) & (col("frequency") <= frequency_quantiles[2]), 4)
                     .otherwise(5))

rfm = rfm.withColumn("monetary_score",
                     when(col("monetary_value") <= monetary_quantiles[0], 2)
                     .when((col("monetary_value") > monetary_quantiles[0]) & (col("monetary_value") <= monetary_quantiles[1]), 3)
                     .when((col("monetary_value") > monetary_quantiles[1]) & (col("monetary_value") <= monetary_quantiles[2]), 4)
                     .otherwise(5))

# RFM Score
rfm = rfm.withColumn("rfm_score", (col("recency_score") + col("frequency_score") + col("monetary_score")) / 3)
rfm_quantiles = rfm.approxQuantile("rfm_score", [0.25, 0.5, 0.75], 0.05)

rfm = rfm.withColumn("rfm_segment",
                     when(col("rfm_score") >= rfm_quantiles[2], "Champions")
                     .when(col("rfm_score") >= rfm_quantiles[1], "Loyal Customers")
                     .when(col("rfm_score") >= rfm_quantiles[0], "Potential Loyalists")
                     .otherwise("Lost Customers"))

rfm.show(10)

# RFM Score Range
print_separator()
print("RFM Score Range")
print_separator()

print("Recency Range:")
rfm.select(min("recency"), max("recency")).show()
print("Frequency Range:")
rfm.select(min("frequency"), max("frequency")).show()
print("Monetary Value Range:")
rfm.select(min("monetary_value"), max("monetary_value")).show()

# Segmentation and Behavior
print_separator()
print("Segmentation and Behavior")
print_separator()
segment_counts = rfm.groupBy("rfm_segment").count().orderBy("rfm_segment")
segment_counts = segment_counts.select("rfm_segment", "count").distinct()
print("Distribution of Customer RFM Segment")
segment_counts.show()
summary_df = rfm.groupBy("rfm_segment").agg(
    expr("percentile_approx(recency, 0.5)").alias("Recency (Days)"),
    expr("percentile_approx(frequency, 0.5)").alias("Transactions Frequency"),
    round(expr("percentile_approx(monetary_value, 0.5)"), 1).alias("Total Spending (Dollars)")
)

print("Behavior RFM Segment (Median)")
summary_df.show()

print_separator()
print("Write to PostgreSQL")
print_separator()
rfm.write.jdbc(
    url=jdbc_url,
    table='public.rfm_table',
    mode='overwrite',
    properties=jdbc_properties
)
print("RFM table successfully written to the SQL table 'public.rfm_table'.")

#Accessing RFM Table
print_separator()
print("Accessing RFM Table")
print_separator()

rfm_df = spark.read.jdbc(
    jdbc_url,
    'public.rfm_table',
    properties=jdbc_properties
)
rfm_df.show()

print_separator()
spark.stop()
print(f"Spark job stopped.")
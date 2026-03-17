from pyspark.sql import functions as F

# Generate parquet data
spark.range(1000000).withColumn("value", F.rand()).write.mode("overwrite").parquet("/tmp/auron_test_a")
spark.range(1000000).withColumn("score", F.rand()).write.mode("overwrite").parquet("/tmp/auron_test_b")

# Read parquet tables
a = spark.read.parquet("/tmp/auron_test_a")
b = spark.read.parquet("/tmp/auron_test_b")

# Join + aggregation (triggers NativeParquetScan, NativeHashAggregate, NativeShuffledHashJoin)
result = a.join(b, "id").groupBy((F.col("id") % 100).alias("group")).agg(F.sum("value"), F.avg("score"))
result.show()

# Show physical plan (look for Native* operators)
result.explain(True)

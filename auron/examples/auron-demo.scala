import org.apache.spark.sql.functions._

// Generate parquet data
spark.range(1000000).withColumn("value", rand()).write.mode("overwrite").parquet("/tmp/auron_test_a")
spark.range(1000000).withColumn("score", rand()).write.mode("overwrite").parquet("/tmp/auron_test_b")

// Read parquet tables
val a = spark.read.parquet("/tmp/auron_test_a")
val b = spark.read.parquet("/tmp/auron_test_b")

// Join + aggregation (triggers NativeParquetScan, NativeHashAggregate, NativeShuffledHashJoin)
val result = a.join(b, "id").groupBy($"id" % 100 as "group").agg(sum("value"), avg("score"))
result.show()

// Show physical plan (look for Native* operators)
result.explain("extended")

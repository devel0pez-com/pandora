from pyspark.sql import SparkSession

spark = SparkSession.builder.getOrCreate()

users = spark.range(1, 1000000).selectExpr("id", "concat('user_', id) as name", "id % 10 as dept")
orders = spark.range(1, 5000000).selectExpr("id as oid", "(id % 999999) + 1 as uid", "rand() * 1000 as amount")

users.write.mode("overwrite").parquet("/tmp/comet_users")
orders.write.mode("overwrite").parquet("/tmp/comet_orders")

u = spark.read.parquet("/tmp/comet_users")
o = spark.read.parquet("/tmp/comet_orders")

result = (u.join(o, u.id == o.uid)
    .groupBy("dept", "name")
    .agg({"amount": "sum", "*": "count"})
    .withColumnRenamed("sum(amount)", "total")
    .withColumnRenamed("count(1)", "orders")
    .filter("total > 100")
    .orderBy("total", ascending=False))

result.explain(True)
result.show(20)
print(f"Total rows: {result.count()}")

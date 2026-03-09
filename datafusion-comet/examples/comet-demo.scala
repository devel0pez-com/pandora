import spark.implicits._
import org.apache.spark.sql.functions._

val users = spark.range(1, 1000000).selectExpr("id", "concat('user_', id) as name", "id % 10 as dept")
val orders = spark.range(1, 5000000).selectExpr("id as oid", "(id % 999999) + 1 as uid", "rand() * 1000 as amount")

users.write.mode("overwrite").parquet("/tmp/comet_users")
orders.write.mode("overwrite").parquet("/tmp/comet_orders")

val u = spark.read.parquet("/tmp/comet_users")
val o = spark.read.parquet("/tmp/comet_orders")

val result = u.join(o, u("id") === o("uid"))
  .groupBy("dept", "name")
  .agg(sum("amount").alias("total"), count("*").alias("orders"))
  .filter($"total" > 100)
  .orderBy($"total".desc)

result.explain("extended")
result.show(20)
result.count()

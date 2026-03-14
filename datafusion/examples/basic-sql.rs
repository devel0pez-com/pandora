use datafusion::prelude::*;

#[tokio::main]
async fn main() -> datafusion::error::Result<()> {
    let ctx = SessionContext::new();

    ctx.sql(
        "SELECT 1 + 2 AS sum, 'hello datafusion' AS greeting"
    )
    .await?
    .show()
    .await?;

    Ok(())
}

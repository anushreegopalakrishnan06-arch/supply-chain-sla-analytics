@echo off
REM ==============================================================================
REM Automated Git Commit Script for Supply Chain Analytics Project
REM Generates a rich, multi-stage professional commit history
REM ==============================================================================

echo [1/9] Initializing Git repository...
git init

echo [2/9] Committing Star Schema & Project Architecture...
git add README.md sql/01_schema_setup.sql
git commit -m "feat(schema): initialize project structure and star schema DDL"

echo [3/9] Committing Delivery SLA Breach & DPMO Diagnostic...
git add sql/02_delivery_sla_breach_analysis.sql
git commit -m "feat(sql): add network SLA breach rate and DPMO defect queries"

echo [4/9] Committing Seller vs Carrier Bottleneck Analysis...
git add sql/03_bottleneck_decomposition.sql
git commit -m "feat(analytics): implement seller fulfillment vs carrier transit latency decomposition"

echo [5/9] Committing Review Decay & Concession Financial Model...
git add sql/04_customer_review_concessions.sql
git commit -m "feat(finance): model customer review decay curve and concession liability exposure"

echo [6/9] Committing Data Pipeline Script...
git add scripts/data_pipeline.py
git commit -m "feat(pipeline): add automated SQLite data ingestion and BI report exporter"

echo [7/9] Committing Exploratory Data Analysis Jupyter Notebook...
git add notebooks/supply_chain_sla_diagnostic.ipynb
git commit -m "feat(eda): add exploratory data analysis notebook with latency breakdown and charts"

echo [8/9] Committing Power BI DAX & Canvas Visuals Guide...
git add dashboards/power_bi_dax_and_visuals_guide.md
git commit -m "docs(bi): add Power BI dimensional model DAX measures and canvas architecture"

echo [9/9] Committing Executive Operations Memo...
git add docs/Executive_Business_Memo.md
git commit -m "docs(executive): deliver Amazon-style narrative memo for operations leadership"

echo ==============================================================================
echo [SUCCESS] 8 Professional Commits created successfully!
echo To push to GitHub, run:
echo   git branch -M main
echo   git remote add origin https://github.com/YOUR_USERNAME/supply-chain-sla-analytics.git
echo   git push -u origin main
echo ==============================================================================
pause

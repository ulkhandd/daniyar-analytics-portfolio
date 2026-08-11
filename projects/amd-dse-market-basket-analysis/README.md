# AMD-DSE Project 2 - Market-Basket Analysis

Scaffold for Project 2 of the 2025/26 Algorithms for Massive Data module in the
MSc Data Science for Economics program.

This folder is intentionally a setup scaffold only. The project brief requires
the submitted implementation to be the student's own work and explicitly forbids
using code-generating AI tools for the submitted code. Use this structure to
organize your work, then write and validate the analysis yourself.

## Assignment Target

Implement a system for finding frequent itemsets using the IMDB Movies Dataset
from Kaggle:

`harshitshankhdhar/imdb-dataset-of-top-1000-movies-and-tv-shows`

Each movie is treated as one basket. The actors in `Star1`, `Star2`, `Star3`,
and `Star4` are the items in that basket. At least one technique studied in the
course should be applied.

## What You Are Trying To Achieve

The project is not about movies for their own sake. The movie dataset is a small
and understandable proxy for a classic affinity-mining problem:

- Which items tend to appear together?
- Which pairs or groups are frequent enough to be meaningful?
- How does the method behave when support thresholds and data size change?
- Can the implementation scale beyond the immediate sample?

In business and finance, the same logic appears in cross-sell, product bundling,
card-spend affinity analysis, merchant recommendation, and next-best-action
systems.

## Repository Structure

```text
projects/amd-dse-market-basket-analysis/
  README.md
  requirements.txt
  data/
    README.md
  docs/
    project_notes.md
    submission_checklist.md
  notebooks/
    README.md
    market_basket_analysis.ipynb
  outputs/
    .gitkeep
  report/
    main.tex
    references.bib
```

## Expected Final Deliverables

- A public GitHub repository or public project folder.
- A Jupyter notebook executable on Google Colab.
- A report, preferably written in LaTeX.
- A clear statement of dataset choice, preprocessing, algorithm, scalability,
  experiments, and results.
- Kaggle credentials removed or replaced with placeholders before submission.

## Suggested Work Plan

1. Confirm Kaggle API access locally and in Colab.
2. Download the dataset during notebook execution, not by committing raw data.
3. Load the CSV and validate that the required actor columns exist.
4. Convert each movie into a basket of non-empty actors.
5. Choose a course technique, for example Apriori or PCY.
6. Run experiments across several support thresholds.
7. Report frequent itemsets and, if useful, association rules.
8. Measure scalability through runtime and candidate counts as data size or
   threshold changes.
9. Write the report using the required structure and declaration.

## Suggested Experiment Design

- Basic dataset profile: rows, missing actor fields, unique actors, basket sizes.
- Frequent itemsets: top pairs and triples by support.
- Threshold sensitivity: how itemset count changes as minimum support changes.
- Runtime/scalability: runtime versus number of baskets or support threshold.
- Interpretation: what the strongest co-appearance patterns mean and where the
  method would transfer to finance or product analytics.

## Colab Link

Add the final Colab badge or link here once the notebook exists in the public
branch you plan to submit.


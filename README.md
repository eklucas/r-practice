# R practice

Browser-based R exercises for data journalism students, with instant feedback.
Built with [Quarto Live](https://r-wasm.github.io/quarto-live/) (R runs in the student's browser through webR)
and [gradethis](https://pkgs.rstudio.com/gradethis/) (checks answers and gives targeted tips).
Hosted free on GitHub Pages: students just open a link.

## What's here

| File | What it is |
|---|---|
| `r1-columbia-crime.qmd` | Exercise R1, converted from the Quarto assignment: 8 checked exercises on Columbia crime data |
| `_helpers.qmd` | Shared feedback helpers: tidyverse style tips (native pipe, `filter()` over `[ , ]`, `group_by()` over `aggregate()`) added to every check |
| `index.qmd` | Landing page that lists the exercises |
| `tests/check-solutions.R` | Runs every model solution through its own check, so a typo in an answer key fails the build instead of confusing students |
| `.github/workflows/publish.yml` | Downloads the data, runs the checks, renders, and publishes to GitHub Pages on every push |
| `_extensions/r-wasm/live` | The Quarto Live extension (vendored) |

## One-time setup

In the repo's **Settings > Pages**, set **Source** to **GitHub Actions**. After the next push, the site is at
`https://eklucas.github.io/r-practice/`.

## Data

The build downloads the published Google Sheet into `data/crime.csv` and serves it next to the page,
so students' browsers never have to reach Google (which can be blocked by browser CORS rules).
If you'd rather freeze the data for a semester, commit a copy at `data/crime.csv`; the build uses it
whenever the download fails. To preview locally, download the sheet as CSV to `data/crime.csv` first.

## Writing an exercise

Each exercise is a set of linked `{webr}` blocks sharing a label:

````markdown
```{webr}
#| exercise: ex_yearly
```

::: {.hint exercise="ex_yearly"}
`group_by(year)`, then `summarise()` the `crimes` column with `sum()`.
:::

::: {.solution exercise="ex_yearly"}
```{webr}
#| exercise: ex_yearly
#| solution: true
crime |> group_by(year) |> summarise(total = sum(crimes))
```
:::

```{webr}
#| exercise: ex_yearly
#| check: true
gradethis::grade_this({
  if (grepl("\\b(count|n)\\(", .user_code)) {
    fail("`count()` counts rows, not crimes. Use `sum(crimes)`.")
  }
  if (!has_values(.result, .solution$total)) fail("Not quite: one row per year with total crimes.")
  pass_with_tip("Those are the yearly totals.", .user_code)
})
```
````

Checks look at the student's result (`.result`) and code (`.user_code`), so they can give specific advice
about common mistakes and accept any reasonable way of getting the answer. `pass_with_tip()` adds a style tip
from `_helpers.qmd` even when the answer is right. Add new pages to `render:` in `_quarto.yml` and to `index.qmd`.

To test your checks locally (needs R with dplyr, readr, yaml and gradethis): `Rscript tests/check-solutions.R`.

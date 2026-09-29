# Runs every exercise's model solution through its own gradethis check, the same way
# the page does in the browser, and fails if any solution errors or is graded wrong.
# Catches typos in column names, broken checks, and data changes that break an exercise.
#
# Usage (from the repo root): Rscript tests/check-solutions.R [file.qmd ...]

suppressPackageStartupMessages({
  library(gradethis)
})

read_with_includes <- function(path) {
  lines <- readLines(path, warn = FALSE)
  out <- character()
  for (line in lines) {
    m <- regmatches(line, regexec("^\\{\\{< include (.+) >\\}\\}\\s*$", line))[[1]]
    if (length(m) == 2) {
      inc <- file.path(dirname(path), trimws(m[2]))
      # The gradethis include installs packages with webr::install(); CI installs them itself.
      if (!grepl("_gradethis.qmd$", inc) && !grepl("_knitr.qmd$", inc)) {
        out <- c(out, read_with_includes(inc))
      }
    } else {
      out <- c(out, line)
    }
  }
  out
}

parse_blocks <- function(lines) {
  blocks <- list()
  i <- 1
  while (i <= length(lines)) {
    if (grepl("^```\\{\\.?webr\\}\\s*$", lines[i])) {
      j <- i + 1
      while (!grepl("^```\\s*$", lines[j])) j <- j + 1
      body <- lines[seq_len(j - i - 1) + i]
      opt_lines <- sub("^#\\| ?", "", body[grepl("^#\\|", body)])
      code <- body[!grepl("^#\\|", body)]
      opts <- if (length(opt_lines)) yaml::yaml.load(paste(opt_lines, collapse = "\n")) else list()
      blocks[[length(blocks) + 1]] <- list(opts = opts, code = paste(code, collapse = "\n"))
      i <- j
    }
    i <- i + 1
  }
  blocks
}

# Grades `user_code` for one exercise, as the browser would. Returns the gradethis grade.
grade_attempt <- function(ex_blocks, label, user_code = NULL) {
  mine <- Filter(function(b) label %in% b$opts$exercise, ex_blocks)
  pick <- function(flag) {
    hit <- Filter(function(b) isTRUE(b$opts[[flag]]), mine)
    if (length(hit)) paste(vapply(hit, `[[`, "", "code"), collapse = "\n") else NULL
  }
  setup <- pick("setup"); solution <- pick("solution"); check <- pick("check")
  if (is.null(solution) || is.null(check)) return(NULL)
  if (is.null(user_code)) user_code <- solution

  envir_prep <- new.env(parent = globalenv())
  if (!is.null(setup)) eval(parse(text = setup), envir = envir_prep)
  envir_result <- new.env(parent = globalenv())
  for (nm in ls(envir_prep, all.names = TRUE)) assign(nm, get(nm, envir_prep), envir_result)
  last_value <- withVisible(eval(parse(text = user_code), envir = envir_result))$value

  gradethis::gradethis_exercise_checker(
    label = label, solution_code = solution, user_code = user_code,
    check_code = check, envir_result = envir_result, evaluate_result = NULL,
    envir_prep = envir_prep, last_value = last_value, stage = "check", engine = "r"
  )
}

load_exercises <- function(path) {
  blocks <- parse_blocks(read_with_includes(path))
  is_ex <- vapply(blocks, function(b) !is.null(b$opts$exercise), logical(1))
  # Plain blocks (shared helpers, examples) run in the global environment, as in the browser.
  for (b in blocks[!is_ex]) eval(parse(text = b$code), envir = globalenv())
  blocks[is_ex]
}

grade_text <- function(grade) gsub("\\s+", " ", paste(format(grade$message), collapse = " "))

check_file <- function(path) {
  message("== ", path)
  ex_blocks <- load_exercises(path)
  labels <- unique(unlist(lapply(ex_blocks, function(b) if (!isTRUE(b$opts$setup)) b$opts$exercise)))
  failures <- 0
  for (label in labels) {
    grade <- grade_attempt(ex_blocks, label)
    if (is.null(grade)) {
      message("  ", label, ": skipped (no solution or check)")
    } else if (isTRUE(grade$correct)) {
      message("  ", label, ": ok  (", grade_text(grade), ")")
    } else {
      message("  ", label, ": FAILED  (", grade_text(grade), ")")
      failures <- failures + 1
    }
  }
  failures
}

if (sys.nframe() == 0) {
files <- commandArgs(trailingOnly = TRUE)
if (!length(files)) {
  files <- list.files(".", pattern = "\\.qmd$")
  files <- files[!startsWith(files, "_") & files != "index.qmd"]
}
total <- sum(vapply(files, check_file, numeric(1)))
if (total > 0) stop(total, " exercise solution(s) failed their own checks", call. = FALSE)
message("All exercise solutions pass their checks.")
}
